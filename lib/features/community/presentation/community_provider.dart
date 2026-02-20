import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/models/mix.dart';
import '../../../core/providers/database_health_provider.dart';
import '../data/community_repository.dart';
import '../../community/domain/community_filters.dart';

/// Estado del provider de la comunidad
enum LegacyCommunityFilter { popular, recent, topRated, favorites }

/// Provider para gestionar el estado de las mezclas de la comunidad.
class CommunityProvider extends ChangeNotifier {
  CommunityProvider(this._repository) {
    _reconnectedSub = DatabaseHealthProvider.instance.onReconnected.listen((_) {
      unawaited(refresh());
    });
  }

  final CommunityRepository _repository;
  StreamSubscription<void>? _reconnectedSub;

  // Exponer el repositorio para acceso directo desde widgets
  CommunityRepository get repository => _repository;

  List<Mix> _mixes = [];
  LegacyCommunityFilter _legacyFilter = LegacyCommunityFilter.popular;
  CommunityFilterState _filterState = const CommunityFilterState();
  bool _isLoading = false;
  bool _isLoaded = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _error;

  // Cache de favoritas locales para recalcular filtros/sort sin red
  List<Mix>? _localFavoritesCache;

  static const int _pageSize = 20;
  int _currentOffset = 0;

  List<Mix> get mixes => List.unmodifiable(_mixes);
  LegacyCommunityFilter get legacyFilter => _legacyFilter;
  CommunityFilterState get filterState => _filterState;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  String? get error => _error;

  /// Carga las mezclas según el filtro actual.
  Future<void> loadMixes() async {
    _isLoading = true;
    _error = null;
    _currentOffset = 0;
    _hasMoreData = true;
    notifyListeners();

    try {
      // Compatibilidad con filtro legacy de favoritos
      final favoritesOnly =
          _legacyFilter == LegacyCommunityFilter.favorites ||
          _filterState.favoritesOnly;
      final sort = _filterState.sortOption;

      if (favoritesOnly) {
        _mixes = await _repository.fetchFavorites();
        // Aplicar filtro por tabaco si corresponde
        if (_filterState.tobaccoName != null) {
          _mixes = _mixes.where((m) {
            final name = _filterState.tobaccoName!.toLowerCase();
            final brand = _filterState.tobaccoBrand?.toLowerCase();
            final hasName = m.ingredients.any(
              (ing) => ing.toLowerCase() == name,
            );
            // Nota: en el modelo Mix no guardamos brand por ingrediente; se filtra solo por nombre
            return hasName && (brand == null || brand.isEmpty ? true : true);
          }).toList();
        }
        // Orden local
        _sortLocal(_mixes, sort);
        _isLoading = false;
        _isLoaded = true;
        _hasMoreData = false;
        notifyListeners();
        return;
      }

      // Mapear sortOption a orden en repositorio actual (simple)
      String orderBy;
      switch (sort) {
        case CommunitySortOption.newest:
          orderBy = 'recent';
          break;
        case CommunitySortOption.oldest:
          orderBy = 'recent_asc';
          break;
        case CommunitySortOption.nameAsc:
          orderBy = 'name_asc';
          break;
        case CommunitySortOption.nameDesc:
          orderBy = 'name_desc';
          break;
        case CommunitySortOption.mostPopular:
          orderBy = 'popular';
          break;
        case CommunitySortOption.topRated:
          orderBy = 'top_rated';
          break;
      }

      _mixes = await _repository.fetchMixes(
        orderBy: orderBy,
        limit: _pageSize,
        offset: 0,
        tobaccoName: _filterState.tobaccoName,
        tobaccoBrand: _filterState.tobaccoBrand,
      );

      _currentOffset = _mixes.length;
      _hasMoreData = _mixes.length >= _pageSize;
      _isLoaded = true;
    } catch (e) {
      _error = 'Error al cargar las mezclas: $e';
      debugPrint(_error);
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga más mezclas (scroll infinito).
  Future<void> loadMoreMixes() async {
    // No cargar más si ya estamos cargando o no hay más datos
    final favoritesOnly =
        _legacyFilter == LegacyCommunityFilter.favorites ||
        _filterState.favoritesOnly;
    if (_isLoadingMore || !_hasMoreData || favoritesOnly) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      String orderBy;
      switch (_filterState.sortOption) {
        case CommunitySortOption.newest:
          orderBy = 'recent';
          break;
        case CommunitySortOption.oldest:
          orderBy = 'recent_asc';
          break;
        case CommunitySortOption.nameAsc:
          orderBy = 'name_asc';
          break;
        case CommunitySortOption.nameDesc:
          orderBy = 'name_desc';
          break;
        case CommunitySortOption.mostPopular:
          orderBy = 'popular';
          break;
        case CommunitySortOption.topRated:
          orderBy = 'top_rated';
          break;
      }

      final newMixes = await _repository.fetchMixes(
        orderBy: orderBy,
        limit: _pageSize,
        offset: _currentOffset,
        tobaccoName: _filterState.tobaccoName,
        tobaccoBrand: _filterState.tobaccoBrand,
      );

      if (newMixes.isNotEmpty) {
        _mixes.addAll(newMixes);
        _currentOffset += newMixes.length;
        _hasMoreData = newMixes.length >= _pageSize;
      } else {
        _hasMoreData = false;
      }
    } catch (e) {
      debugPrint('Error al cargar más mezclas: $e');
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void _sortLocal(List<Mix> list, CommunitySortOption sort) {
    int cmp<T extends Comparable>(T a, T b) => a.compareTo(b);
    switch (sort) {
      case CommunitySortOption.newest:
        // sin createdAt en Mix; mantener orden original (asumido reciente)
        break;
      case CommunitySortOption.oldest:
        break;
      case CommunitySortOption.nameAsc:
        list.sort((a, b) => cmp(a.name.toLowerCase(), b.name.toLowerCase()));
        break;
      case CommunitySortOption.nameDesc:
        list.sort((a, b) => cmp(b.name.toLowerCase(), a.name.toLowerCase()));
        break;
      case CommunitySortOption.mostPopular:
      case CommunitySortOption.topRated:
        list.sort((a, b) {
          final cr = cmp(b.rating, a.rating);
          if (cr != 0) return cr;
          return cmp(b.reviews, a.reviews);
        });
        break;
    }
  }

  /// Cambia el filtro y recarga las mezclas.
  Future<void> setLegacyFilter(LegacyCommunityFilter filter) async {
    if (_legacyFilter == filter) return;
    _legacyFilter = filter;
    // Sincronizar con estado moderno (favoritos)
    if (filter == LegacyCommunityFilter.favorites &&
        !_filterState.favoritesOnly) {
      _filterState = _filterState.copyWith(favoritesOnly: true);
    } else if (filter != LegacyCommunityFilter.favorites &&
        _filterState.favoritesOnly) {
      _filterState = _filterState.copyWith(favoritesOnly: false);
    }
    notifyListeners();
    await loadMixes();
  }

  void setSortOption(CommunitySortOption sort) {
    if (_filterState.sortOption == sort) return;
    _filterState = _filterState.copyWith(sortOption: sort);
    if (_filterState.favoritesOnly) {
      // Reordenar localmente la lista actual
      final list = List<Mix>.from(_mixes);
      _sortLocal(list, _filterState.sortOption);
      _mixes = list;
      notifyListeners();
    } else {
      loadMixes();
    }
  }

  void toggleFavoritesOnly() {
    _filterState = _filterState.copyWith(
      favoritesOnly: !_filterState.favoritesOnly,
    );
    loadMixes();
  }

  void clearTobaccoFilter() {
    _filterState = _filterState.clearTobacco();
    if (_filterState.favoritesOnly && _localFavoritesCache != null) {
      // Volver a favoritas completas y aplicar orden
      var list = List<Mix>.from(_localFavoritesCache!);
      _sortLocal(list, _filterState.sortOption);
      _mixes = list;
      _hasMoreData = false;
      notifyListeners();
    } else {
      loadMixes();
    }
  }

  void setTobaccoFilter({required String name, required String brand}) {
    _filterState = _filterState.copyWith(
      tobaccoName: name,
      tobaccoBrand: brand,
    );
    if (_filterState.favoritesOnly && _localFavoritesCache != null) {
      // Filtrar sobre la cache local por nombre de tabaco
      var list = List<Mix>.from(_localFavoritesCache!);
      final needle = name.toLowerCase();
      list = list
          .where((m) => m.ingredients.any((i) => i.toLowerCase() == needle))
          .toList();
      _sortLocal(list, _filterState.sortOption);
      _mixes = list;
      _hasMoreData = false;
      notifyListeners();
    } else {
      // TODO: Implementar filtrado por tabaco específico en fetchMixes (requiere modificar repositorio / vista SQL)
      loadMixes();
    }
  }

  /// Inyecta una lista local de favoritas (proveniente de FavoritesProvider) sin ir a red.
  /// Aplica filtros locales (tabaco) y orden seleccionado.
  void setLocalFavorites(List<Mix> localFavorites) {
    // Guardar cache
    _localFavoritesCache = localFavorites;
    // Activar modo favoritas si no lo estaba
    if (!_filterState.favoritesOnly) {
      _filterState = _filterState.copyWith(favoritesOnly: true);
    }
    _isLoading = false;
    _isLoaded = true;
    _hasMoreData = false; // no hay paginación en locales
    // Copia base
    var list = List<Mix>.from(localFavorites);
    // Filtro por tabaco (solo por nombre disponible)
    if (_filterState.tobaccoName != null) {
      final needle = _filterState.tobaccoName!.toLowerCase();
      list = list
          .where((m) => m.ingredients.any((i) => i.toLowerCase() == needle))
          .toList();
    }
    // Orden
    _sortLocal(list, _filterState.sortOption);
    _mixes = list;
    notifyListeners();
  }

  /// Recarga las mezclas con el filtro actual.
  Future<void> refresh() async {
    await loadMixes();
  }

  /// Crea una nueva mezcla.
  ///
  /// [components] debe contener mapas con:
  /// - tobacco_name: String
  /// - brand: String
  /// - percentage: double
  /// - color: String (hex format, ej: "#72C8C1")
  Future<Mix?> createMix({
    required String name,
    String? description,
    required List<Map<String, dynamic>> components,
  }) async {
    try {
      final newMix = await _repository.createMix(
        name: name,
        description: description,
        components: components,
      );

      if (newMix != null) {
        // Añadir la mezcla a la lista actual si estamos en vista "recientes"
        if (_legacyFilter == LegacyCommunityFilter.recent) {
          _mixes.insert(0, newMix);
          notifyListeners();
        } else {
          // Para otros filtros, recargar la lista completa
          await loadMixes();
        }
      }

      return newMix;
    } catch (e) {
      debugPrint('Error al crear mezcla: $e');
      DatabaseHealthProvider.reportFailure(e);
      return null;
    }
  }

  /// Actualiza una mezcla en la lista local.
  /// Útil cuando se modifica una mezcla (ej: cambios en rating/reseñas).
  void updateMix(Mix updatedMix) {
    final index = _mixes.indexWhere((m) => m.id == updatedMix.id);
    if (index != -1) {
      _mixes[index] = updatedMix;
      notifyListeners();
    }
  }

  /// Elimina una mezcla del backend y la lista local si tiene éxito.
  Future<bool> deleteMix(String mixId) async {
    try {
      final ok = await _repository.deleteMix(mixId);
      if (ok) {
        _mixes.removeWhere((m) => m.id == mixId);
        notifyListeners();
      }
      return ok;
    } catch (e) {
      debugPrint('Error en deleteMix: $e');
      DatabaseHealthProvider.reportFailure(e);
      return false;
    }
  }

  /// Elimina una mezcla solo en memoria (por ejemplo, cuando otra vista la borra).
  void removeMixLocally(String mixId) {
    _mixes.removeWhere((m) => m.id == mixId);
    notifyListeners();
  }

  /// Actualiza una mezcla en el backend y sincroniza la lista local.
  Future<Mix?> editMix({
    required String mixId,
    required String name,
    String? description,
    required List<Map<String, dynamic>> components,
  }) async {
    try {
      final updated = await _repository.updateMix(
        mixId: mixId,
        name: name,
        description: description,
        components: components,
      );
      if (updated != null) {
        final idx = _mixes.indexWhere((m) => m.id == updated.id);
        if (idx != -1) {
          _mixes[idx] = updated;
          notifyListeners();
        }
      }
      return updated;
    } catch (e) {
      debugPrint('Error en updateMix: $e');
      DatabaseHealthProvider.reportFailure(e);
      return null;
    }
  }

  @override
  void dispose() {
    _reconnectedSub?.cancel();
    super.dispose();
  }
}
