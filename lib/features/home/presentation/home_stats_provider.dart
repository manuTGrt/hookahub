import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/providers/database_health_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/home_stats_repository.dart';
import '../domain/home_stats.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class HomeStatsState {
  const HomeStatsState();
}

/// Estado inicial previo a la carga de estadísticas.
class HomeStatsInitial extends HomeStatsState {
  const HomeStatsInitial();
}

/// Carga en progreso.
class HomeStatsLoading extends HomeStatsState {
  const HomeStatsLoading();
}

/// Estadísticas cargadas con éxito.
class HomeStatsLoaded extends HomeStatsState {
  const HomeStatsLoaded(this.stats);
  final HomeStats stats;
}

/// Ocurrió un error al cargar o recibir estadísticas.
class HomeStatsError extends HomeStatsState {
  const HomeStatsError(this.message, {this.cachedStats});
  final String message;
  final HomeStats? cachedStats;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class HomeStatsProvider extends ChangeNotifier {
  HomeStatsProvider(this._repository, {AuthProvider? auth}) : _auth = auth {
    _auth?.addSignOutListener(clear);
  }

  final HomeStatsRepository _repository;
  final AuthProvider? _auth;
  StreamSubscription<HomeStats>? _subscription;

  HomeStatsState _state = const HomeStatsInitial();
  HomeStatsState get state => _state;

  HomeStats _stats = HomeStats.empty;
  HomeStats get stats => _stats;

  // Getters derivados para compatibilidad y consumo simplificado
  bool get isLoading => _state is HomeStatsLoading;
  bool get hasData =>
      _state is HomeStatsLoaded ||
      (_state is HomeStatsError && (_state as HomeStatsError).cachedStats != null);
  String? get error => switch (_state) {
    HomeStatsError(:final message) => message,
    _ => null,
  };

  Future<void> load({bool force = false}) async {
    if (_subscription != null && !force) return;

    _state = const HomeStatsLoading();
    notifyListeners();

    try {
      // Carga inicial rápida
      _stats = await _repository.fetchStats();
      _state = HomeStatsLoaded(_stats);
      DatabaseHealthProvider.reportSuccess();
    } catch (e, stack) {
      _state = HomeStatsError(
        'No se pudieron cargar las estadísticas iniciales',
        cachedStats: _stats == HomeStats.empty ? null : _stats,
      );
      AppLogger.error('Error fetching initial stats', error: e, stackTrace: stack);
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      notifyListeners();
    }

    // Suscripción a cambios en tiempo real
    _subscription?.cancel();
    _subscription = _repository.streamStats().listen(
      (newStats) {
        _stats = newStats;
        _state = HomeStatsLoaded(newStats);
        notifyListeners();
        DatabaseHealthProvider.reportSuccess();
      },
      onError: (e, stack) {
        final errorString = e.toString();
        if (errorString.contains('RealtimeSubscribeException') || 
            errorString.contains('RealtimeCloseEvent') ||
            errorString.contains('InvalidJWTToken')) {
          AppLogger.warning('Desconexión temporal en el stream de estadísticas: $errorString');
        } else {
          AppLogger.error('Error en el stream de estadísticas', error: e, stackTrace: stack);
        }
        DatabaseHealthProvider.reportFailure(e);
      },
    );
  }

  /// Cancela la suscripción al stream de estadísticas (ej. al pausar o cambiar de pantalla)
  void cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Limpia el estado en memoria y cancela suscripciones al cerrar sesión
  void clear() {
    cancelSubscription();
    _state = const HomeStatsInitial();
    _stats = HomeStats.empty;
    notifyListeners();
  }

  Future<void> refresh() => load(force: true);

  @override
  void dispose() {
    _auth?.removeSignOutListener(clear);
    _subscription?.cancel();
    super.dispose();
  }
}
