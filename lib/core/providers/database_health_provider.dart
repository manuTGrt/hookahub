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

  /// Indica si el error proviene de red o pérdida de conectividad con la base de datos/backend.
  ///
  /// Excluye explícitamente errores de validación, credenciales de cliente (AuthException 4xx)
  /// y violaciones de restricciones de integridad o lógica de negocio (PostgrestException 23xxx, 22xxx, 42xxx, etc.).
  static bool isConnectionError(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException) {
      return true;
    }

    if (error is AuthException) {
      // Los errores de autenticación comunes (400 Bad Request por credenciales inválidas,
      // 401 Unauthorized, 422 Unprocessable Entity por usuario duplicado, 429 Rate Limit)
      // son respuestas válidas de GoTrue ante acciones del usuario, NUNCA caídas de BD/red.
      final status = int.tryParse(error.statusCode ?? '');
      if (status != null && status >= 400 && status < 500) {
        return false;
      }
      // Por defecto, una AuthException significa que el servicio de autenticación respondió.
      return false;
    }

    if (error is PostgrestException) {
      final code = error.code;
      if (code != null) {
        // Excluir errores de cliente y restricciones según estándar SQLSTATE:
        // - Clase 23: Violación de restricciones de integridad (23505 unique, 23503 foreign key, 23502 not null, etc.)
        // - Clase 22: Excepciones de datos / formato de cliente (22001 string data, 22P02 invalid text representation, etc.)
        // - Clase 42: Errores de sintaxis o permisos / RLS (42501 insufficient privilege, 42703 undefined column, etc.)
        // - Códigos de cliente PostgREST: PGRST1xx (ej. PGRST116: 0 filas encontradas), PGRST2xx
        if (code.startsWith('23') ||
            code.startsWith('22') ||
            code.startsWith('42') ||
            code.startsWith('PGRST1') ||
            code.startsWith('PGRST2')) {
          return false;
        }

        // Reconocer errores genuinos de conexión PostgreSQL / infraestructura:
        // - Clase 08: Connection exceptions (08000, 08003, 08006, 08001, 08004, 08007)
        // - Clase 57: Operator intervention / shutdown (57P01, 57P02, 57P03)
        // - 53300: Too many connections (pool agotado)
        if (code.startsWith('08') || code.startsWith('57') || code == '53300') {
          return true;
        }
      }

      // Evaluar si el mensaje describe una caída de transporte o socket subyacente
      final msg = error.message.toLowerCase();
      if (msg.contains('connection refused') ||
          msg.contains('connection closed') ||
          msg.contains('network') ||
          msg.contains('timeout') ||
          msg.contains('socketexception')) {
        return true;
      }

      // Por defecto, excepciones genéricas de Postgrest con respuestas 4xx no son caídas de red
      return false;
    }

    // Detección de fallos de red encapsulados en mensajes de transporte (ej. ClientException de package:http)
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('clientexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('connection reset') ||
        errorString.contains('broken pipe')) {
      return true;
    }

    return false;
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
