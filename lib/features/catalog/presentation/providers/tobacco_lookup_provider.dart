import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/models/tobacco.dart';
import '../../../../core/utils/app_error_mapper.dart';
import '../../data/tobacco_repository.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class TobaccoLookupState {
  const TobaccoLookupState();
}

/// Estado inicial antes de comenzar la búsqueda o paginación.
class TobaccoLookupInitial extends TobaccoLookupState {
  const TobaccoLookupInitial();
}

/// Primera página cargándose.
class TobaccoLookupLoading extends TobaccoLookupState {
  const TobaccoLookupLoading();
}

/// Resultados cargados (incluye flag de paginación adicional en curso).
class TobaccoLookupLoaded extends TobaccoLookupState {
  const TobaccoLookupLoaded({
    required this.items,
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  final List<Tobacco> items;
  final bool isLoadingMore;
  final bool hasMore;

  TobaccoLookupLoaded copyWith({
    List<Tobacco>? items,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return TobaccoLookupLoaded(
      items: items ?? this.items,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Error al consultar el catálogo de tabacos.
class TobaccoLookupError extends TobaccoLookupState {
  const TobaccoLookupError(
    this.message, {
    this.previousItems = const [],
    this.hasMore = true,
  });

  final String message;
  final List<Tobacco> previousItems;
  final bool hasMore;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Provider para búsquedas y listado paginado de tabacos en el desplegable
class TobaccoLookupProvider extends ChangeNotifier {
  TobaccoLookupProvider(this._repository, {bool autoLoad = true}) {
    // Carga inicial solo si autoLoad es true
    if (autoLoad) {
      unawaited(loadMore(resetCursor: true));
    }
  }

  final TobaccoRepository _repository;

  TobaccoLookupState _state = const TobaccoLookupInitial();
  TobaccoLookupState get state => _state;

  List<Tobacco> get items => switch (_state) {
    TobaccoLookupLoaded(items: final list) => List.unmodifiable(list),
    TobaccoLookupError(previousItems: final list) => List.unmodifiable(list),
    _ => const <Tobacco>[],
  };

  bool get isLoading => switch (_state) {
    TobaccoLookupLoading() => true,
    TobaccoLookupLoaded(isLoadingMore: final loadingMore) => loadingMore,
    _ => false,
  };

  bool get hasMore => switch (_state) {
    TobaccoLookupLoaded(hasMore: final more) => more,
    TobaccoLookupError(hasMore: final more) => more,
    _ => true,
  };

  String? get error => switch (_state) {
    TobaccoLookupError(message: final msg) => msg,
    _ => null,
  };

  static const int _pageSize = TobaccoRepository.defaultPageSize;

  String _query = '';
  String get query => _query;

  /// Actualiza la consulta de búsqueda (por nombre o descripción) y reinicia el listado
  Future<void> setQuery(String value) async {
    final q = value.trim();
    if (q == _query) return;
    _query = q;
    _state = const TobaccoLookupInitial();
    notifyListeners();
    await loadMore(resetCursor: true);
  }

  Future<void> refresh() async {
    _state = const TobaccoLookupInitial();
    notifyListeners();
    await loadMore(resetCursor: true);
  }

  Future<void> loadMore({bool resetCursor = false}) async {
    if (isLoading || (!resetCursor && !hasMore)) return;

    final currentItems = resetCursor ? const <Tobacco>[] : List<Tobacco>.of(items);
    final previousHasMore = resetCursor ? true : hasMore;

    if (currentItems.isEmpty) {
      _state = const TobaccoLookupLoading();
    } else {
      _state = TobaccoLookupLoaded(
        items: currentItems,
        isLoadingMore: true,
        hasMore: previousHasMore,
      );
    }
    notifyListeners();

    try {
      final offset = resetCursor ? 0 : currentItems.length;
      final newItems = await _repository.fetchTobaccos(
        offset: offset,
        limit: _pageSize,
        query: _query.isEmpty ? null : _query,
      );
      final merged = <Tobacco>[...currentItems, ...newItems];
      _state = TobaccoLookupLoaded(
        items: merged,
        isLoadingMore: false,
        hasMore: newItems.length >= _pageSize,
      );
    } catch (e) {
      _state = TobaccoLookupError(
        AppErrorMapper.toSpanish(e),
        previousItems: currentItems,
        hasMore: previousHasMore,
      );
    } finally {
      notifyListeners();
    }
  }
}
