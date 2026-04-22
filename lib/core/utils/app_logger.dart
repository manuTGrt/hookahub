import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AppLogger centralizado para la aplicación.
/// Muestra logs en consola solo en modo depuración con formato minimalista.
/// Envía errores críticos a Supabase en todos los entornos.
class AppLogger {
  // Configuración minimalista requerida
  static final Logger _logger = Logger(
    printer: SimplePrinter(
      printTime: true,
      colors: true,
    ),
    filter: DevelopmentFilter(), // Por defecto logger solo imprime en debug
  );

  /// Registra un mensaje de depuración.
  /// No se procesa en modo Release.
  static void debug(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Registra información de flujo de ejecución o estado.
  /// No se procesa en modo Release.
  static void info(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.i(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Registra una advertencia.
  /// No se procesa en modo Release.
  static void warning(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.w(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Registra un error y opcionalmente lo envía a Supabase.
  /// En Release, no se imprime en consola pero SÍ se envía a Supabase.
  static void error(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    }
    
    // Envío remoto de errores críticos a Supabase
    _sendErrorToSupabase(
      level: 'error',
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Registra un fallo crítico (crash o estado irrecuperable).
  /// En Release, no se imprime en consola pero SÍ se envía a Supabase.
  static void fatal(String message, {dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      _logger.f(message, error: error, stackTrace: stackTrace);
    }
    
    _sendErrorToSupabase(
      level: 'fatal',
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Método interno para reportar errores en la base de datos Supabase.
  /// NOTA: Requiere crear una tabla `app_logs` en Supabase con RLS configurado
  /// para permitir inserts (incluso anónimos si es necesario) y las columnas correspondientes.
  static Future<void> _sendErrorToSupabase({
    required String level,
    required String message,
    dynamic error,
    StackTrace? stackTrace,
  }) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      
      await client.from('app_logs').insert({
        'level': level,
        'message': message,
        'error_details': error?.toString(),
        'stack_trace': stackTrace?.toString(),
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      // Ignoramos silenciosamente si falla el registro remoto en producción
      if (kDebugMode) {
        _logger.e('Fallo crítico al enviar log a Supabase: $e');
      }
    }
  }
}
