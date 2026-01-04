import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/models/tobacco.dart';
import '../../data/tobacco_repository.dart';

/// Provider para búsquedas y listado paginado de tabacos en el desplegable
class TobaccoLookupProvider extends ChangeNotifier {
  TobaccoLookupProvider(this._repository, {bool autoLoad = true}) {
    // Carga inicial solo si autoLoad es true
    if (autoLoad) {
      unawaited(loadMore(resetCursor: true));
    }
  }

  final TobaccoRepository _repository;

  final List<Tobacco> _items = [];
  List<Tobacco> get items => List.unmodifiable(_items);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  String? _error;
  String? get error => _error;

  static const int _pageSize = TobaccoRepository.defaultPageSize;

  String _query = '';
  String get query => _query;

  /// Actualiza la consulta de búsqueda (por nombre o descripción) y reinicia el listado
  Future<void> setQuery(String value) async {
    final q = value.trim();
    if (q == _query) return;
    _query = q;
    _items.clear();
    _hasMore = true;
    _error = null;
    notifyListeners();
    await loadMore(resetCursor: true);
  }

  Future<void> refresh() async {
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
        query: _query.isEmpty ? null : _query,
      );
      _items.addAll(newItems);
      if (newItems.length < _pageSize) {
        _hasMore = false;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
