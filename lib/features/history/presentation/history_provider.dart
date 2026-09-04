import 'package:hookahub/core/utils/app_logger.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/providers/database_health_provider.dart';
import '../../auth/auth_provider.dart';
import '../data/history_repository.dart';
import '../domain/visit_entry.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class HistoryState {
  const HistoryState();
}

/// Estado inicial: historial aún no cargado.
class HistoryInitial extends HistoryState {
  const HistoryInitial();
}

/// Primera carga en progreso.
class HistoryLoading extends HistoryState {
  const HistoryLoading();
}

/// Historial cargado con éxito.
class HistoryLoaded extends HistoryState {
  const HistoryLoaded({
    required this.entries,
    required this.uniqueCount,
    this.isRefreshing = false,
  });

  final List<VisitEntry> entries;
  final int uniqueCount;
  final bool isRefreshing;
}

/// Ocurrió un error al interactuar con el historial.
class HistoryError extends HistoryState {
  const HistoryError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Provider para gestionar el estado del historial de mezclas visitadas.
/// Utiliza [HistoryRepository] para interactuar con Supabase.
class HistoryProvider extends ChangeNotifier {
  HistoryProvider(this._repository, {AuthProvider? auth}) : _auth = auth {
    _auth?.addSignOutListener(clear);
    _reconnectedSub = DatabaseHealthProvider.instance.onReconnected.listen((_) {
      unawaited(refresh());
    });
  }

  final HistoryRepository _repository;
  final AuthProvider? _auth;
  StreamSubscription<void>? _reconnectedSub;

  // Estado sellado (única fuente de verdad)
  HistoryState _state = const HistoryInitial();

  /// Limpia el historial en memoria al cerrar sesión
  void clear() {
    _state = const HistoryInitial();
    notifyListeners();
  }

  // Getters de estado
  HistoryState get state => _state;
  bool get isLoading =>
      _state is HistoryLoading ||
      (_state is HistoryLoaded && (_state as HistoryLoaded).isRefreshing);
  bool get isLoaded => _state is HistoryLoaded;
  String? get error =>
      _state is HistoryError ? (_state as HistoryError).message : null;
  List<VisitEntry> get entries =>
      _state is HistoryLoaded ? (_state as HistoryLoaded).entries : const [];
  int get uniqueCount =>
      _state is HistoryLoaded ? (_state as HistoryLoaded).uniqueCount : 0;

  /// Carga el historial de mezclas visitadas en los últimos 2 días.
  /// Previene llamadas concurrentes y retorna inmediatamente si ya está cargando.
  Future<void> load({bool isRefresh = false}) async {
    // Prevenir llamadas concurrentes
    if (_state is HistoryLoading ||
        (_state is HistoryLoaded && (_state as HistoryLoaded).isRefreshing)) {
      AppLogger.info(
        '⏳ HistoryProvider: Ya hay una carga en progreso, ignorando nueva llamada',
      );
      return;
    }

    AppLogger.info('🔄 HistoryProvider: Iniciando carga del historial');
    if (!isRefresh) {
      _state = const HistoryLoading();
      notifyListeners();
    }

    try {
      // Cargar historial de los últimos 2 días
      final entries = await _repository.fetchRecentHistory(days: 2);
      final uniqueCount = await _repository.getUniqueVisitedCount(days: 2);

      AppLogger.info(
        '✅ HistoryProvider: Historial cargado - ${entries.length} entradas, $uniqueCount únicas',
      );
      _state = HistoryLoaded(
        entries: entries,
        uniqueCount: uniqueCount,
      );
    } catch (e) {
      final errorMessage = 'Error al cargar historial: $e';
      _state = HistoryError(errorMessage);
      AppLogger.error('❌ HistoryProvider: $errorMessage');
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      notifyListeners();
    }
  }

  /// Recarga el historial desde el servidor.
  /// Fuerza una nueva carga completa ignorando el estado previo.
  Future<void> refresh() async {
    AppLogger.info('🔄 HistoryProvider: Forzando refresh del historial');
    if (_state is HistoryLoaded) {
      final current = _state as HistoryLoaded;
      _state = HistoryLoaded(
        entries: current.entries,
        uniqueCount: current.uniqueCount,
        isRefreshing: true,
      );
      notifyListeners();
    }
    await load(isRefresh: true);
  }

  /// Registra una visita a una mezcla.
  /// Llama a este método cuando el usuario abre la página de detalle de una mezcla.
  ///
  /// [mixId]: ID de la mezcla visitada.
  /// [silent]: Si es `true`, no notifica a los listeners ni actualiza la UI.
  Future<void> recordView(String mixId, {bool silent = true}) async {
    try {
      final success = await _repository.recordMixView(mixId);

      if (success && !silent) {
        // Recargar historial si no es silencioso
        await load();
      }
    } catch (e) {
      AppLogger.error('Error al registrar vista: $e');
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  /// Elimina todo el historial del usuario.
  Future<bool> clearAll() async {
    try {
      final success = await _repository.clearAllHistory();

      if (success) {
        _state = const HistoryLoaded(entries: [], uniqueCount: 0);
        notifyListeners();
      }

      return success;
    } catch (e) {
      final errorMessage = 'Error al limpiar historial: $e';
      _state = HistoryError(errorMessage);
      AppLogger.error(errorMessage);
      notifyListeners();
      DatabaseHealthProvider.reportFailure(e);
      return false;
    }
  }

  /// Elimina vistas anteriores a [days] días.
  Future<int> clearOld({int days = 7}) async {
    try {
      final deletedCount = await _repository.clearOldHistory(days: days);

      if (deletedCount > 0) {
        // Recargar historial después de la limpieza
        await load();
      }

      return deletedCount;
    } catch (e) {
      final errorMessage = 'Error al limpiar historial antiguo: $e';
      _state = HistoryError(errorMessage);
      AppLogger.error(errorMessage);
      notifyListeners();
      DatabaseHealthProvider.reportFailure(e);
      return 0;
    }
  }

  @override
  void dispose() {
    _auth?.removeSignOutListener(clear);
    _reconnectedSub?.cancel();
    super.dispose();
  }

  /// Agrupa las entradas del historial por día.
  /// Retorna un mapa donde la clave es el día y el valor es la lista de entradas.
  Map<String, List<VisitEntry>> get groupedByDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<VisitEntry>> grouped = {
      'Hoy': [],
      'Ayer': [],
      'Hace 2 días': [],
    };

    for (final entry in entries) {
      final viewDate = DateTime(
        entry.visitedAt.year,
        entry.visitedAt.month,
        entry.visitedAt.day,
      );

      if (viewDate == today) {
        grouped['Hoy']!.add(entry);
      } else if (viewDate == yesterday) {
        grouped['Ayer']!.add(entry);
      } else {
        grouped['Hace 2 días']!.add(entry);
      }
    }

    // Eliminar claves vacías
    grouped.removeWhere((key, value) => value.isEmpty);

    return grouped;
  }
}
