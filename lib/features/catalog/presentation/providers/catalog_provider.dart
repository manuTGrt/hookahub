import 'package:hookahub/core/utils/app_logger.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/providers/database_health_provider.dart';
import '../../../../core/utils/app_error_mapper.dart';

import '../../../../core/models/tobacco.dart';
import '../../data/tobacco_repository.dart';
import '../../domain/catalog_filters.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class CatalogState {
  const CatalogState();
}

/// Estado inicial previo al primer intento de carga.
class CatalogInitial extends CatalogState {
  const CatalogInitial();
}

/// Carga inicial en progreso.
class CatalogLoading extends CatalogState {
  const CatalogLoading();
}

/// Catálogo cargado con éxito.
class CatalogLoaded extends CatalogState {
  const CatalogLoaded({
    required this.items,
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  final List<Tobacco> items;
  final bool isLoadingMore;
  final bool hasMore;

  CatalogLoaded copyWith({
    List<Tobacco>? items,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return CatalogLoaded(
      items: items ?? this.items,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Ocurrió un error al cargar el catálogo.
class CatalogError extends CatalogState {
  const CatalogError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class CatalogProvider extends ChangeNotifier {
  CatalogProvider(this._repository) {
    // Carga de marcas en segundo plano; la lista se cargará bajo demanda
    unawaited(_loadBrands());
    // Carga de datos diferida: se realizará al entrar en la pestaña Catálogo
    // La reconexión se gestiona desde la navegación principal para el tab visible
  }

  final TobaccoRepository _repository;

  /// Callback delegado opcional para solicitar scroll hacia arriba en la vista activa
  VoidCallback? onScrollToTopRequested;

  void scrollToTop() {
    onScrollToTopRequested?.call();
  }

  // Estado sellado (única fuente de verdad)
  CatalogState _state = const CatalogInitial();

  CatalogState get state => _state;

  // Getters derivados para compatibilidad y consumo simplificado
  List<Tobacco> get items =>
      _state is CatalogLoaded ? (_state as CatalogLoaded).items : const [];

  bool get isLoading =>
      _state is CatalogLoading ||
      (_state is CatalogLoaded && (_state as CatalogLoaded).isLoadingMore);

  bool get isLoaded => _state is CatalogLoaded;

  bool get isLoadingMore =>
      _state is CatalogLoaded && (_state as CatalogLoaded).isLoadingMore;

  bool get hasMore =>
      _state is CatalogLoaded ? (_state as CatalogLoaded).hasMore : true;

  bool get hasAttemptedLoad =>
      _state is CatalogLoaded || _state is CatalogError;

  String? get error =>
      _state is CatalogError ? (_state as CatalogError).message : null;

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
      AppLogger.error('Error cargando marcas: $e');
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _isLoadingBrands = false;
      notifyListeners();
    }
  }

  /// Aplica un filtro por marca
  void setFilterByBrand(String? brand) {
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
    await loadMore(resetCursor: true);
  }

  /// Refresca un único elemento en la lista si existe, sin perder el scroll
  void updateItem(Tobacco updatedTobacco) {
    final currentState = _state;
    if (currentState is! CatalogLoaded) return;
    final index =
        currentState.items.indexWhere((t) => t.id == updatedTobacco.id);
    if (index != -1) {
      final updatedList = List<Tobacco>.from(currentState.items);
      updatedList[index] = updatedTobacco;
      _state = currentState.copyWith(items: updatedList);
      notifyListeners();
    }
  }

  /// Recarga un único ítem desde el repositorio y actualiza su estado localmente
  Future<void> refreshItem(String id) async {
    try {
      final updated = await _repository.fetchTobaccoById(id);
      if (updated != null) {
        updateItem(updated);
      }
    } catch (e) {
      AppLogger.error('Error refrescando tabaco individual: $e');
    }
  }

  /// Obtiene un tabaco completo por id. Si está cargado localmente lo intenta devolver.
  Future<Tobacco?> getTobaccoById(String id) async {
    try {
      final currentState = _state;
      if (currentState is CatalogLoaded) {
        final local = currentState.items.where((t) => t.id == id).firstOrNull;
        if (local != null) return local;
      }

      return await _repository.fetchTobaccoById(id);
    } catch (e, stackTrace) {
      AppLogger.error('Error fetching tobacco by id', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> loadMore({bool resetCursor = false}) async {
    if (isLoading || (!resetCursor && !hasMore)) return;

    final currentState = _state;
    final isInitialOrReset = resetCursor || currentState is! CatalogLoaded;

    if (isInitialOrReset) {
      _state = const CatalogLoading();
    } else {
      _state = currentState.copyWith(isLoadingMore: true);
    }
    notifyListeners();

    try {
      final currentItems =
          isInitialOrReset ? <Tobacco>[] : currentState.items;
      final offset = resetCursor ? 0 : currentItems.length;

      final newItems = await _repository.fetchTobaccos(
        offset: offset,
        limit: _pageSize,
        filter: _filter,
      );

      final combined = List<Tobacco>.from(currentItems)..addAll(newItems);
      final hasMoreData = newItems.length >= _pageSize;

      _state = CatalogLoaded(
        items: combined,
        hasMore: hasMoreData,
        isLoadingMore: false,
      );
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      final isConn = DatabaseHealthProvider.isConnectionError(e);
      final errorMessage = isConn ? null : AppErrorMapper.toSpanish(e);

      if (errorMessage != null) {
        _state = CatalogError(errorMessage);
      } else {
        if (currentState is CatalogLoaded && !resetCursor) {
          _state = currentState.copyWith(isLoadingMore: false);
        } else {
          _state = const CatalogLoaded(items: [], hasMore: true, isLoadingMore: false);
        }
      }
    } finally {
      notifyListeners();
    }
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    onScrollToTopRequested = null;
    _reconnectedSub?.cancel();
    super.dispose();
  }
}
