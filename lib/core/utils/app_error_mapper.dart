import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Mapea excepciones técnicas (Supabase GoTrue, PostgreSQL, red y Dart)
/// a mensajes claros, amigables y 100% en español para la interfaz de usuario.
class AppErrorMapper {
  AppErrorMapper._();

  /// Convierte cualquier excepción en un mensaje en español comprensible para el usuario.
  static String toSpanish(Object? error, {String? defaultMessage}) {
    if (error == null) {
      return defaultMessage ?? 'Ha ocurrido un error inesperado.';
    }

    if (error is AuthException) {
      return _mapAuthException(error);
    }

    if (error is PostgrestException) {
      return _mapPostgrestException(error);
    }

    if (error is SocketException) {
      return 'Sin conexión a internet. Revisa tu red.';
    }

    if (error is TimeoutException) {
      return 'Tiempo de espera agotado. Revisa tu conexión a internet.';
    }

    if (error is HttpException) {
      return 'Error de comunicación con el servidor.';
    }

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('clientexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('connection reset') ||
        errorString.contains('broken pipe')) {
      return 'No se pudo conectar con el servidor. Verifica tu conexión a internet.';
    }

    if (errorString.contains('jwt') || errorString.contains('token')) {
      return 'Tu sesión ha expirado. Por favor, vuelve a iniciar sesión.';
    }

    return defaultMessage ??
        'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.';
  }

  static String _mapAuthException(AuthException error) {
    final msg = error.message.toLowerCase();
    final code = error.code?.toLowerCase() ?? '';

    // Credenciales incorrectas
    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'El correo o la contraseña son incorrectos.';
    }

    // Usuario existente en registro
    if (code == 'user_already_exists' ||
        msg.contains('user already registered') ||
        msg.contains('already registered') ||
        msg.contains('already exists')) {
      return 'Ya existe una cuenta registrada con este correo electrónico.';
    }

    // Contraseña demasiado corta o inválida
    if (msg.contains('password should be at least') ||
        msg.contains('requires a valid password') ||
        code == 'weak_password') {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    // Correo pendiente de confirmación
    if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
      return 'Tu correo electrónico aún no ha sido confirmado. Revisa tu bandeja de entrada.';
    }

    // Límite de tasa / Demasiados intentos
    if (code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit' ||
        msg.contains('rate limit') ||
        msg.contains('over request rate limit') ||
        msg.contains('for security purposes, you can only request')) {
      return 'Has superado el límite de intentos. Por favor, espera unos minutos antes de volver a intentarlo.';
    }

    // Formato de correo inválido
    if (code == 'invalid_email' ||
        msg.contains('unable to validate email') ||
        msg.contains('invalid email') ||
        msg.contains('invalid format')) {
      return 'El formato del correo electrónico no es válido.';
    }

    // Falta correo o campos obligatorios
    if (msg.contains('to signup, please provide your email') ||
        msg.contains('missing email')) {
      return 'Por favor, introduce tu correo electrónico.';
    }

    // Usuario no encontrado
    if (code == 'user_not_found' || msg.contains('user not found')) {
      return 'No se encontró ninguna cuenta asociada a este correo electrónico.';
    }

    // Cancelación en autenticación externa (ej. Google)
    if (msg.contains('cancelado') || msg.contains('canceled')) {
      return 'El inicio de sesión fue cancelado.';
    }

    // Si ya está redactado en español y es legible, conservarlo
    if (error.message.isNotEmpty &&
        !error.message.contains(RegExp(r'[A-Za-z]{4,}\s[A-Za-z]{4,}')) &&
        (error.message.startsWith('El ') ||
            error.message.startsWith('No ') ||
            error.message.startsWith('Error '))) {
      return error.message;
    }

    return 'Error de autenticación. Por favor, verifica tus datos e inténtalo de nuevo.';
  }

  static String _mapPostgrestException(PostgrestException error) {
    final code = error.code;

    if (code != null) {
      // 23505: unique_violation
      if (code == '23505') {
        return 'Ya existe un registro con estos datos.';
      }

      // 23503: foreign_key_violation
      if (code == '23503') {
        return 'La operación no pudo completarse porque hace referencia a un elemento que no existe.';
      }

      // 23502: not_null_violation
      if (code == '23502') {
        return 'Por favor, completa todos los campos requeridos.';
      }

      // 23514: check_violation
      if (code == '23514') {
        return 'Uno o más datos ingresados no cumplen con las reglas requeridas.';
      }

      // 42501: insufficient_privilege (RLS)
      if (code == '42501') {
        return 'No tienes permisos suficientes para realizar esta acción.';
      }

      // PGRST116: JSON single row requested, 0 rows returned
      if (code == 'PGRST116') {
        return 'No se encontró la información solicitada.';
      }

      // Códigos de conexión e infraestructura PostgreSQL
      if (code.startsWith('08') || code == '08006' || code == '08001') {
        return 'No se pudo conectar con el servidor. Revisa tu conexión a internet.';
      }

      if (code.startsWith('57') || code == '57P01') {
        return 'El servidor se encuentra temporalmente en mantenimiento.';
      }

      if (code == '53300') {
        return 'El servidor está temporalmente ocupado. Inténtalo de nuevo en unos momentos.';
      }
    }

    final msg = error.message.toLowerCase();
    if (msg.contains('connection refused') ||
        msg.contains('connection closed') ||
        msg.contains('network') ||
        msg.contains('socketexception')) {
      return 'No se pudo conectar con el servidor. Revisa tu conexión a internet.';
    }

    if (msg.contains('timeout')) {
      return 'Tiempo de espera agotado al consultar la base de datos.';
    }

    return 'Ha ocurrido un error al procesar los datos en el servidor.';
  }
}
