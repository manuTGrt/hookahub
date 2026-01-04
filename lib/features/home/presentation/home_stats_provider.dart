import 'package:flutter/material.dart';

import '../../../core/providers/database_health_provider.dart';
import '../data/home_stats_repository.dart';
import '../domain/home_stats.dart';

class HomeStatsProvider extends ChangeNotifier {
  HomeStatsProvider(this._repository);

  final HomeStatsRepository _repository;

  HomeStats _stats = HomeStats.empty;
  HomeStats get stats => _stats;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasData = false;
  bool get hasData => _hasData;

  String? _error;
  String? get error => _error;

  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasData && !force) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stats = await _repository.fetchStats();
      _hasData = true;
      DatabaseHealthProvider.reportSuccess();
    } catch (e) {
      _hasData = false;
      _error = 'No se pudieron cargar las estadísticas';
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(force: true);
}
