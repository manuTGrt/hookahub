import 'package:hookahub/core/utils/app_logger.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/models/mix.dart';
import '../../../core/providers/database_health_provider.dart';
import '../data/community_repository.dart';
import '../../community/domain/community_filters.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class CommunityState {
  const CommunityState();
}

/// Estado inicial previo a la primera carga de mezclas.
class CommunityInitial extends CommunityState {
  const CommunityInitial();
}

/// Primera carga o recarga completa en progreso.
class CommunityLoading extends CommunityState {
  const CommunityLoading();
}

/// Mezclas de la comunidad cargadas con éxito.
class CommunityLoaded extends CommunityState {
  const CommunityLoaded({
    required this.mixes,
    this.isLoadingMore = false,
    this.hasMoreData = true,
  });

  final List<Mix> mixes;
  final bool isLoadingMore;
  final bool hasMoreData;

  CommunityLoaded copyWith({
    List<Mix>? mixes,
    bool? isLoadingMore,
    bool? hasMoreData,
  }) {
    return CommunityLoaded(
      mixes: mixes ?? this.mixes,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreData: hasMoreData ?? this.hasMoreData,
    );
  }
}

/// Ocurrió un error al interactuar o cargar mezclas de la comunidad.
class CommunityError extends CommunityState {
  const CommunityError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Filtros legacy
// ---------------------------------------------------------------------------

enum LegacyCommunityFilter { popular, recent, topRated, favorites }

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

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

  // Estado sellado (única fuente de verdad)
  CommunityState _state = const CommunityInitial();

  CommunityState get state => _state;

  LegacyCommunityFilter _legacyFilter = LegacyCommunityFilter.popular;
  CommunityFilterState _filterState = const CommunityFilterState();

  // Cache de favoritas locales para recalcular filtros/sort sin red
  List<Mix>? _localFavoritesCache;

  static const int _pageSize = 20;
  int _currentOffset = 0;

  // Getters derivados para compatibilidad y consumo simplificado
  List<Mix> get mixes =>
      _state is CommunityLoaded ? (_state as CommunityLoaded).mixes : const [];

  LegacyCommunityFilter get legacyFilter => _legacyFilter;
  CommunityFilterState get filterState => _filterState;

  bool get isLoading => _state is CommunityLoading;
  bool get isLoaded => _state is CommunityLoaded;
  bool get isLoadingMore =>
      _state is CommunityLoaded && (_state as CommunityLoaded).isLoadingMore;
  bool get hasMoreData =>
      _state is CommunityLoaded ? (_state as CommunityLoaded).hasMoreData : true;
  String? get error =>
      _state is CommunityError ? (_state as CommunityError).message : null;

  /// Carga las mezclas según el filtro actual.
  Future<void> loadMixes() async {
    _state = const CommunityLoading();
    _currentOffset = 0;
    notifyListeners();

    try {
      // Compatibilidad con filtro legacy de favoritos
      final favoritesOnly =
          _legacyFilter == LegacyCommunityFilter.favorites ||
          _filterState.favoritesOnly;
      final sort = _filterState.sortOption;

      if (favoritesOnly) {
        var result = await _repository.fetchFavorites();
        // Aplicar filtro por tabaco si corresponde
        if (_filterState.tobaccoName != null) {
          final name = _filterState.tobaccoName!.toLowerCase();
          final brand = _filterState.tobaccoBrand?.toLowerCase();
          result = result.where((m) {
            final hasName = m.ingredients.any(
              (ing) => ing.toLowerCase() == name,
            );
            return hasName && (brand == null || brand.isEmpty ? true : true);
          }).toList();
        }
        // Orden local
        _sortLocal(result, sort);
        _state = CommunityLoaded(
          mixes: result,
          hasMoreData: false,
          isLoadingMore: false,
        );
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

      final result = await _repository.fetchMixes(
        orderBy: orderBy,
        limit: _pageSize,
        offset: 0,
        tobaccoName: _filterState.tobaccoName,
        tobaccoBrand: _filterState.tobaccoBrand,
      );

      _currentOffset = result.length;
      _state = CommunityLoaded(
        mixes: result,
        hasMoreData: result.length >= _pageSize,
        isLoadingMore: false,
      );
    } catch (e, stackTrace) {
      final errorMsg = 'Error al cargar las mezclas: $e';
      AppLogger.error('Error al cargar las mezclas', error: e, stackTrace: stackTrace);
      DatabaseHealthProvider.reportFailure(e);
      _state = CommunityError(errorMsg);
    } finally {
      notifyListeners();
    }
  }

  /// Carga más mezclas (scroll infinito).
  Future<void> loadMoreMixes() async {
    final currentState = _state;
    if (currentState is! CommunityLoaded) return;

    final favoritesOnly =
        _legacyFilter == LegacyCommunityFilter.favorites ||
        _filterState.favoritesOnly;
    if (currentState.isLoadingMore || !currentState.hasMoreData || favoritesOnly) {
      return;
    }

    _state = currentState.copyWith(isLoadingMore: true);
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
        final combined = List<Mix>.from(currentState.mixes)..addAll(newMixes);
        _currentOffset += newMixes.length;
        _state = currentState.copyWith(
          mixes: combined,
          hasMoreData: newMixes.length >= _pageSize,
          isLoadingMore: false,
        );
      } else {
        _state = currentState.copyWith(
          hasMoreData: false,
          isLoadingMore: false,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error al cargar más mezclas', error: e, stackTrace: stackTrace);
      DatabaseHealthProvider.reportFailure(e);
      _state = currentState.copyWith(isLoadingMore: false);
    } finally {
      notifyListeners();
    }
  }

  void _sortLocal(List<Mix> list, CommunitySortOption sort) {
    int cmp<T extends Comparable>(T a, T b) => a.compareTo(b);
    switch (sort) {
      case CommunitySortOption.newest:
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
      final currentState = _state;
      if (currentState is CommunityLoaded) {
        final list = List<Mix>.from(currentState.mixes);
        _sortLocal(list, _filterState.sortOption);
        _state = currentState.copyWith(mixes: list);
        notifyListeners();
      }
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
      final list = List<Mix>.from(_localFavoritesCache!);
      _sortLocal(list, _filterState.sortOption);
      _state = CommunityLoaded(
        mixes: list,
        hasMoreData: false,
        isLoadingMore: false,
      );
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
      final needle = name.toLowerCase();
      final list = List<Mix>.from(_localFavoritesCache!)
          .where((m) => m.ingredients.any((i) => i.toLowerCase() == needle))
          .toList();
      _sortLocal(list, _filterState.sortOption);
      _state = CommunityLoaded(
        mixes: list,
        hasMoreData: false,
        isLoadingMore: false,
      );
      notifyListeners();
    } else {
      loadMixes();
    }
  }

  /// Inyecta una lista local de favoritas (proveniente de FavoritesProvider) sin ir a red.
  /// Aplica filtros locales (tabaco) y orden seleccionado.
  void setLocalFavorites(List<Mix> localFavorites) {
    _localFavoritesCache = localFavorites;
    if (!_filterState.favoritesOnly) {
      _filterState = _filterState.copyWith(favoritesOnly: true);
    }
    final list = List<Mix>.from(localFavorites);
    if (_filterState.tobaccoName != null) {
      final needle = _filterState.tobaccoName!.toLowerCase();
      list.removeWhere(
        (m) => !m.ingredients.any((i) => i.toLowerCase() == needle),
      );
    }
    _sortLocal(list, _filterState.sortOption);
    _state = CommunityLoaded(
      mixes: list,
      hasMoreData: false,
      isLoadingMore: false,
    );
    notifyListeners();
  }

  /// Recarga las mezclas con el filtro actual.
  Future<void> refresh() async {
    await loadMixes();
  }

  /// Crea una nueva mezcla.
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
        if (_legacyFilter == LegacyCommunityFilter.recent) {
          final currentState = _state;
          if (currentState is CommunityLoaded) {
            final updated = List<Mix>.from(currentState.mixes)..insert(0, newMix);
            _state = currentState.copyWith(mixes: updated);
            notifyListeners();
          } else {
            _state = CommunityLoaded(mixes: [newMix]);
            notifyListeners();
          }
        } else {
          await loadMixes();
        }
      }

      return newMix;
    } catch (e, stackTrace) {
      AppLogger.error('Error al crear mezcla', error: e, stackTrace: stackTrace);
      DatabaseHealthProvider.reportFailure(e);
      return null;
    }
  }

  /// Actualiza una mezcla en la lista local.
  void updateMix(Mix updatedMix) {
    final currentState = _state;
    if (currentState is! CommunityLoaded) return;
    final index = currentState.mixes.indexWhere((m) => m.id == updatedMix.id);
    if (index != -1) {
      final updated = List<Mix>.from(currentState.mixes);
      updated[index] = updatedMix;
      _state = currentState.copyWith(mixes: updated);
      notifyListeners();
    }
  }

  /// Elimina una mezcla del backend y la lista local si tiene éxito.
  Future<bool> deleteMix(String mixId) async {
    try {
      final ok = await _repository.deleteMix(mixId);
      if (ok) {
        removeMixLocally(mixId);
      }
      return ok;
    } catch (e, stackTrace) {
      AppLogger.error('Error en deleteMix', error: e, stackTrace: stackTrace);
      DatabaseHealthProvider.reportFailure(e);
      return false;
    }
  }

  /// Elimina una mezcla solo en memoria (por ejemplo, cuando otra vista la borra).
  void removeMixLocally(String mixId) {
    final currentState = _state;
    if (currentState is! CommunityLoaded) return;
    final updated = List<Mix>.from(currentState.mixes)
      ..removeWhere((m) => m.id == mixId);
    _state = currentState.copyWith(mixes: updated);
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
        final currentState = _state;
        if (currentState is CommunityLoaded) {
          final idx = currentState.mixes.indexWhere((m) => m.id == updated.id);
          if (idx != -1) {
            final list = List<Mix>.from(currentState.mixes);
            list[idx] = updated;
            _state = currentState.copyWith(mixes: list);
            notifyListeners();
          }
        }
      }
      return updated;
    } catch (e, stackTrace) {
      AppLogger.error('Error en updateMix', error: e, stackTrace: stackTrace);
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
