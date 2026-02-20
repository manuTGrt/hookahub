import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/database_health_service.dart';

/// Gestiona el estado de la conexión con la base de datos y ejecuta healthchecks.
class DatabaseHealthProvider extends ChangeNotifier {
  DatabaseHealthProvider({required DatabaseHealthService healthService})
    : _healthService = healthService {
    _instance = this;
  }

  final DatabaseHealthService _healthService;

  static DatabaseHealthProvider? _instance;

  /// Acceso global para reportar fallos críticos desde otras capas.
  static DatabaseHealthProvider get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('DatabaseHealthProvider no ha sido inicializado');
    }
    return instance;
  }

  bool _isConnected = true;
  bool _isChecking = false;
  DateTime? _lastCheckedAt;

  // Evento para notificar cuando se recupera la conexión
  final StreamController<void> _reconnectedController =
      StreamController<void>.broadcast();
  Stream<void> get onReconnected => _reconnectedController.stream;

  bool get isConnected => _isConnected;
  bool get isChecking => _isChecking;
  DateTime? get lastCheckedAt => _lastCheckedAt;

  /// Ejecuta un healthcheck manual (por ejemplo, desde el botón "Reintentar").
  Future<void> retryConnection() async {
    await _runHealthcheck(force: true);
  }

  /// Reporta una excepción proveniente de una operación crítica.
  /// Si la excepción es relacionada con conectividad, se dispara un healthcheck.
  static void reportFailure(Object error) {
    final instance = _instance;
    if (instance == null) {
      return;
    }
    if (!isConnectionError(error)) {
      return;
    }
    // Marca desconectado inmediatamente para sincronizar banner y mensajes de UI
    instance._markDisconnectedImmediate();
    instance._triggerHealthcheck();
  }

  /// Indica si el error proviene de red/BD para suprimir mensajes duplicados en UI.
  static bool isConnectionError(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is PostgrestException ||
        error is AuthException ||
        error is HttpException;
  }

  /// Permite marcar la conexión como saludable cuando una operación remota
  /// finaliza con éxito (útil si no se disparó un healthcheck explícito).
  static void reportSuccess() {
    final instance = _instance;
    instance?._markConnectedImmediate();
  }

  void _triggerHealthcheck() {
    if (_isChecking) return;
    unawaited(_runHealthcheck());
  }

  /// Marca el estado como desconectado y notifica de inmediato.
  /// Útil para que el banner y los mensajes de vaciado aparezcan a la vez
  /// cuando detectamos un fallo de conectividad en otra capa.
  void _markDisconnectedImmediate() {
    if (_isConnected) {
      _isConnected = false;
      notifyListeners();
    }
  }

  /// Marca conectado y notifica si estaba en estado offline.
  void _markConnectedImmediate() {
    if (!_isConnected) {
      _isConnected = true;
      _lastCheckedAt = DateTime.now();
      notifyListeners();
    }
  }

  Future<void> _runHealthcheck({bool force = false}) async {
    if (_isChecking && !force) return;
    _isChecking = true;
    notifyListeners();

    final wasConnected = _isConnected;
    final healthy = await _healthService.checkDatabaseConnection();
    _isConnected = healthy;
    _lastCheckedAt = DateTime.now();

    _isChecking = false;
    notifyListeners();

    // Si antes estaba desconectado y ahora volvió a conectar, emitir evento
    if (!wasConnected && healthy) {
      _reconnectedController.add(null);
    }
  }

  @override
  void dispose() {
    _reconnectedController.close();
    super.dispose();
  }
}
