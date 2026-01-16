import 'package:flutter/foundation.dart';
import '../../../../core/models/mix.dart';
import '../../../../core/providers/database_health_provider.dart';
import '../../../community/data/community_repository.dart';

class TobaccoMixesProvider extends ChangeNotifier {
  TobaccoMixesProvider(this._repository);

  final CommunityRepository _repository;

  List<Mix> _mixes = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _error;

  static const int _pageSize = 10;
  int _currentOffset = 0;
  String? _tobaccoName;
  String? _tobaccoBrand;

  List<Mix> get mixes => List.unmodifiable(_mixes);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  String? get error => _error;

  Future<void> loadMixes({
    required String tobaccoName,
    String? tobaccoBrand,
  }) async {
    _tobaccoName = tobaccoName;
    _tobaccoBrand = tobaccoBrand;

    _isLoading = true;
    _error = null;
    _currentOffset = 0;
    _hasMoreData = true;
    _mixes = [];
    notifyListeners();

    try {
      _mixes = await _repository.fetchMixes(
        orderBy: 'recent',
        limit: _pageSize,
        offset: 0,
        tobaccoName: tobaccoName,
        tobaccoBrand: tobaccoBrand,
      );

      _currentOffset = _mixes.length;
      _hasMoreData = _mixes.length >= _pageSize;
    } catch (e) {
      _error = 'Error al cargar las mezclas';
      debugPrint('Error loading tobacco mixes: $e');
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMoreData || _tobaccoName == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final newMixes = await _repository.fetchMixes(
        orderBy: 'recent',
        limit: _pageSize,
        offset: _currentOffset,
        tobaccoName: _tobaccoName,
        tobaccoBrand: _tobaccoBrand,
      );

      if (newMixes.isNotEmpty) {
        _mixes.addAll(newMixes);
        _currentOffset += newMixes.length;
        _hasMoreData = newMixes.length >= _pageSize;
      } else {
        _hasMoreData = false;
      }
    } catch (e) {
      debugPrint('Error loading more tobacco mixes: $e');
      // No seteamos error principal para no bloquear la UI ya cargada
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_tobaccoName != null) {
      await loadMixes(tobaccoName: _tobaccoName!, tobaccoBrand: _tobaccoBrand);
    }
  }
}
