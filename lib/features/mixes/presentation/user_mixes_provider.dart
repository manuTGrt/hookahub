import 'package:flutter/foundation.dart';
import '../../../core/models/mix.dart';
import '../../../core/providers/database_health_provider.dart';
import '../data/user_mixes_repository.dart';

class UserMixesProvider extends ChangeNotifier {
  UserMixesProvider(this._repo);

  final UserMixesRepository _repo;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isLoaded = false;
  String? _error;
  final int _pageSize = 20;
  int _offset = 0;
  bool _hasMore = true;

  List<Mix> _mixes = [];

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoaded => _isLoaded;
  String? get error => _error;
  bool get hasMore => _hasMore;
  List<Mix> get mixes => List.unmodifiable(_mixes);

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _offset = 0;
      final result = await _repo.fetchMyMixes(
        limit: _pageSize,
        offset: _offset,
      );
      _mixes = result;
      _offset = _mixes.length;
      _hasMore = result.length >= _pageSize;
      _isLoaded = true;
    } catch (e) {
      _error = 'No se pudieron cargar tus mezclas';
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _isLoaded = false;
    await load();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await _repo.fetchMyMixes(
        limit: _pageSize,
        offset: _offset,
      );
      if (result.isNotEmpty) {
        _mixes.addAll(result);
        _offset += result.length;
        _hasMore = result.length >= _pageSize;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
}
