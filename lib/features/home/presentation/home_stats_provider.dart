import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/providers/database_health_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../data/home_stats_repository.dart';
import '../domain/home_stats.dart';

class HomeStatsProvider extends ChangeNotifier {
  HomeStatsProvider(this._repository);

  final HomeStatsRepository _repository;
  StreamSubscription<HomeStats>? _subscription;

  HomeStats _stats = HomeStats.empty;
  HomeStats get stats => _stats;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasData = false;
  bool get hasData => _hasData;

  String? _error;
  String? get error => _error;

  Future<void> load({bool force = false}) async {
    if (_subscription != null && !force) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Carga inicial rápida
      _stats = await _repository.fetchStats();
      _hasData = true;
      DatabaseHealthProvider.reportSuccess();
    } catch (e, stack) {
      _hasData = false;
      _error = 'No se pudieron cargar las estadísticas iniciales';
      AppLogger.error('Error fetching initial stats', error: e, stackTrace: stack);
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Suscripción a cambios en tiempo real
    _subscription?.cancel();
    _subscription = _repository.streamStats().listen(
      (newStats) {
        _stats = newStats;
        _hasData = true;
        _error = null;
        notifyListeners();
        DatabaseHealthProvider.reportSuccess();
      },
      onError: (e, stack) {
        AppLogger.error('Error en el stream de estadísticas', error: e, stackTrace: stack);
        DatabaseHealthProvider.reportFailure(e);
      },
    );
  }

  Future<void> refresh() => load(force: true);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
