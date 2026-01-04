import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/providers/database_health_provider.dart';

import '../../../../core/models/tobacco.dart';
import '../../data/tobacco_repository.dart';
import '../../domain/catalog_filters.dart';

class CatalogProvider extends ChangeNotifier {
  CatalogProvider(this._repository) {
    _scrollController.addListener(_onScroll);
    // Carga de marcas en segundo plano; la lista se cargará bajo demanda
    unawaited(_loadBrands());
    // Carga de datos diferida: se realizará al entrar en la pestaña Catálogo
    // La reconexión se gestiona desde la navegación principal para el tab visible
  }

  final TobaccoRepository _repository;

  final ScrollController _scrollController = ScrollController();
  ScrollController get scrollController => _scrollController;

  final List<Tobacco> _items = [];
  List<Tobacco> get items => List.unmodifiable(_items);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  bool _hasAttemptedLoad = false;
  bool get hasAttemptedLoad => _hasAttemptedLoad;

  String? _error;
  String? get error => _error;

  // Estado de filtros
  CatalogFilter _filter = const CatalogFilter();
  CatalogFilter get filter => _filter;

  // Marcas disponibles
  List<String> _availableBrands = [];
  List<String> get availableBrands => List.unmodifiable(_availableBrands);

  bool _isLoadingBrands = false;
  bool get isLoadingBrands => _isLoadingBrands;

  StreamSubscription<void>? _reconnectedSub;

  static const int _pageSize = TobaccoRepository.defaultPageSize;

  /// Carga la lista de marcas disponibles
  Future<void> _loadBrands() async {
    _isLoadingBrands = true;
    notifyListeners();
    try {
      _availableBrands = await _repository.fetchAvailableBrands();
    } catch (e) {
      // Silenciosamente ignorar errores en la carga de marcas
      debugPrint('Error cargando marcas: $e');
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _isLoadingBrands = false;
      notifyListeners();
    }
  }

  /// Aplica un filtro por marca
  void setFilterByBrand(String? brand) {
    // Necesitamos diferenciar entre "no cambiar" y "limpiar".
    // El copyWith actual mantiene la marca previa cuando se pasa null.
    // Por eso, al intentar volver a "Todas las marcas" (brand == null) la marca anterior persistía.
    if (_filter.brand == brand) return; // Sin cambios reales
    if (brand == null) {
      _filter = _filter.clearBrand();
    } else {
      _filter = _filter.copyWith(brand: brand);
    }
    refresh();
  }

  /// Aplica un filtro de ordenamiento
  void setSortOption(SortOption sortOption) {
    if (_filter.sortOption == sortOption) return;
    _filter = _filter.copyWith(sortOption: sortOption);
    refresh();
  }

  /// Limpia todos los filtros
  void clearFilters() {
    _filter = const CatalogFilter();
    refresh();
  }

  Future<void> refresh() async {
    _hasAttemptedLoad = false;
    _items.clear();
    _hasMore = true;
    _error = null;
    notifyListeners();
    await loadMore(resetCursor: true);
  }

  Future<void> loadMore({bool resetCursor = false}) async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final offset = resetCursor ? 0 : _items.length;
      final newItems = await _repository.fetchTobaccos(
        offset: offset,
        limit: _pageSize,
        filter: _filter,
      );
      _items.addAll(newItems);
      if (newItems.length < _pageSize) {
        _hasMore = false;
      }
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      // Si es error de conexión, solo mostramos banner global y suprimimos texto en la lista
      _error = DatabaseHealthProvider.isConnectionError(e) ? null : e.toString();
    } finally {
      _hasAttemptedLoad = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoading || !_hasMore) return;
    final threshold = 300.0; // px antes del final
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (max - current <= threshold) {
      unawaited(loadMore());
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _reconnectedSub?.cancel();
    super.dispose();
  }
}
