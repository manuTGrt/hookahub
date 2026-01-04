import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/providers/database_health_provider.dart';
import '../data/history_repository.dart';
import '../domain/visit_entry.dart';

/// Provider para gestionar el estado del historial de mezclas visitadas.
/// Utiliza [HistoryRepository] para interactuar con Supabase.
class HistoryProvider extends ChangeNotifier {
  HistoryProvider(this._repository) {
    _reconnectedSub = DatabaseHealthProvider.instance.onReconnected.listen((_) {
      unawaited(refresh());
    });
  }

  final HistoryRepository _repository;
  StreamSubscription<void>? _reconnectedSub;

  // Estado de carga
  bool _isLoading = false;
  bool _isLoaded = false;
  String? _error;

  // Datos del historial
  List<VisitEntry> _entries = [];
  int _uniqueCount = 0;

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  String? get error => _error;
  List<VisitEntry> get entries => List.unmodifiable(_entries);
  int get uniqueCount => _uniqueCount;

  /// Carga el historial de mezclas visitadas en los últimos 2 días.
  /// Previene llamadas concurrentes y retorna inmediatamente si ya está cargando.
  Future<void> load() async {
    // Prevenir llamadas concurrentes
    if (_isLoading) {
      debugPrint('⏳ HistoryProvider: Ya hay una carga en progreso, ignorando nueva llamada');
      return;
    }

    debugPrint('🔄 HistoryProvider: Iniciando carga del historial');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Cargar historial de los últimos 2 días
      _entries = await _repository.fetchRecentHistory(days: 2);
      _uniqueCount = await _repository.getUniqueVisitedCount(days: 2);
      
      debugPrint('✅ HistoryProvider: Historial cargado - ${_entries.length} entradas, $_uniqueCount únicas');
      _isLoaded = true;
      _error = null;
    } catch (e) {
      _error = 'Error al cargar historial: $e';
      debugPrint('❌ HistoryProvider: $_error');
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recarga el historial desde el servidor.
  /// Fuerza una nueva carga completa ignorando el estado previo.
  Future<void> refresh() async {
    debugPrint('🔄 HistoryProvider: Forzando refresh del historial');
    _isLoaded = false;
    await load();
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
      debugPrint('Error al registrar vista: $e');
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  /// Elimina todo el historial del usuario.
  Future<bool> clearAll() async {
    try {
      final success = await _repository.clearAllHistory();
      
      if (success) {
        _entries = [];
        _uniqueCount = 0;
        _isLoaded = true;
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      _error = 'Error al limpiar historial: $e';
      debugPrint(_error);
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

    @override
    void dispose() {
      _reconnectedSub?.cancel();
      super.dispose();
    }
        // Recargar historial después de la limpieza
        await load();
      }
      
      return deletedCount;
    } catch (e) {
      _error = 'Error al limpiar historial antiguo: $e';
      debugPrint(_error);
      notifyListeners();
      DatabaseHealthProvider.reportFailure(e);
      return 0;
    }
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

    for (final entry in _entries) {
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
