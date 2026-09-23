import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/utils/app_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppErrorMapper.toSpanish - AuthException', () {
    test('mapea credenciales incorrectas a español', () {
      expect(
        AppErrorMapper.toSpanish(
          const AuthException('Invalid login credentials', statusCode: '400'),
        ),
        'El correo o la contraseña son incorrectos.',
      );
    });

    test('mapea usuario existente a español', () {
      expect(
        AppErrorMapper.toSpanish(
          const AuthException('User already registered', statusCode: '422'),
        ),
        'Ya existe una cuenta registrada con este correo electrónico.',
      );
    });

    test('mapea contraseña corta a español', () {
      expect(
        AppErrorMapper.toSpanish(
          const AuthException(
            'Password should be at least 6 characters',
            statusCode: '422',
          ),
        ),
        'La contraseña debe tener al menos 6 caracteres.',
      );
    });

    test('mapea email no confirmado a español', () {
      expect(
        AppErrorMapper.toSpanish(
          const AuthException('Email not confirmed', statusCode: '400'),
        ),
        'Tu correo electrónico aún no ha sido confirmado. Revisa tu bandeja de entrada.',
      );
    });

    test('mapea límite de intentos / rate limit a español', () {
      expect(
        AppErrorMapper.toSpanish(
          const AuthException('Over request rate limit', statusCode: '429'),
        ),
        'Has superado el límite de intentos. Por favor, espera unos minutos antes de volver a intentarlo.',
      );
      expect(
        AppErrorMapper.toSpanish(
          const AuthException(
            'For security purposes, you can only request this once every 60 seconds',
            statusCode: '429',
          ),
        ),
        'Has superado el límite de intentos. Por favor, espera unos minutos antes de volver a intentarlo.',
      );
    });

    test('mapea formato de email inválido a español', () {
      expect(
        AppErrorMapper.toSpanish(
          const AuthException('Unable to validate email address: invalid format'),
        ),
        'El formato del correo electrónico no es válido.',
      );
    });

    test('mapea cancelación de login a español', () {
      expect(
        AppErrorMapper.toSpanish(
          const AuthException('El inicio de sesión fue cancelado.'),
        ),
        'El inicio de sesión fue cancelado.',
      );
    });
  });

  group('AppErrorMapper.toSpanish - PostgrestException', () {
    test('mapea violación de unicidad 23505 a español', () {
      expect(
        AppErrorMapper.toSpanish(
          const PostgrestException(
            message: 'duplicate key value violates unique constraint',
            code: '23505',
          ),
        ),
        'Ya existe un registro con estos datos.',
      );
    });

    test('mapea violación de clave foránea 23503 a español', () {
      expect(
        AppErrorMapper.toSpanish(
          const PostgrestException(
            message: 'violates foreign key constraint',
            code: '23503',
          ),
        ),
        'La operación no pudo completarse porque hace referencia a un elemento que no existe.',
      );
    });

    test('mapea violación de no nulo 23502 a español', () {
      expect(
        AppErrorMapper.toSpanish(
          const PostgrestException(
            message: 'null value in column violates not-null constraint',
            code: '23502',
          ),
        ),
        'Por favor, completa todos los campos requeridos.',
      );
    });

    test('mapea permisos RLS 42501 a español', () {
      expect(
        AppErrorMapper.toSpanish(
          const PostgrestException(
            message: 'permission denied for table',
            code: '42501',
          ),
        ),
        'No tienes permisos suficientes para realizar esta acción.',
      );
    });

    test('mapea 0 filas PGRST116 a español', () {
      expect(
        AppErrorMapper.toSpanish(
          const PostgrestException(
            message: '0 rows returned',
            code: 'PGRST116',
          ),
        ),
        'No se encontró la información solicitada.',
      );
    });

    test('mapea desconexión de PostgreSQL 08006 a español', () {
      expect(
        AppErrorMapper.toSpanish(
          const PostgrestException(
            message: 'connection failure',
            code: '08006',
          ),
        ),
        'No se pudo conectar con el servidor. Revisa tu conexión a internet.',
      );
    });
  });

  group('AppErrorMapper.toSpanish - Red y genéricos', () {
    test('mapea SocketException a español', () {
      expect(
        AppErrorMapper.toSpanish(const SocketException('Failed host lookup')),
        'Sin conexión a internet. Revisa tu red.',
      );
    });

    test('mapea TimeoutException a español', () {
      expect(
        AppErrorMapper.toSpanish(TimeoutException('timeout')),
        'Tiempo de espera agotado. Revisa tu conexión a internet.',
      );
    });

    test('mapea ClientException a español', () {
      expect(
        AppErrorMapper.toSpanish(Exception('ClientException: connection reset')),
        'No se pudo conectar con el servidor. Verifica tu conexión a internet.',
      );
    });

    test('excepción desconocida no expone traza en inglés', () {
      final msg = AppErrorMapper.toSpanish(Exception('Internal cryptic failure 500'));
      expect(
        msg,
        'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.',
      );
    });
  });
}
