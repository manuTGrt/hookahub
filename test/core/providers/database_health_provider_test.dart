import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/providers/database_health_provider.dart';
import 'package:hookahub/core/services/database_health_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeDatabaseHealthService implements DatabaseHealthService {
  bool healthyResult = true;

  @override
  Future<bool> checkDatabaseConnection() async => healthyResult;
}

void main() {
  group('DatabaseHealthProvider.isConnectionError', () {
    test('clasifica errores de red y timeout como errores de conexión', () {
      expect(
        DatabaseHealthProvider.isConnectionError(
          const SocketException('Failed host lookup'),
        ),
        isTrue,
      );
      expect(
        DatabaseHealthProvider.isConnectionError(
          TimeoutException('Connection timed out'),
        ),
        isTrue,
      );
      expect(
        DatabaseHealthProvider.isConnectionError(
          const HttpException('Connection closed unexpectedly'),
        ),
        isTrue,
      );
      expect(
        DatabaseHealthProvider.isConnectionError(
          Exception('ClientException: Failed host lookup for supabase.co'),
        ),
        isTrue,
      );
      expect(
        DatabaseHealthProvider.isConnectionError(
          Exception('OS Error: Connection reset by peer'),
        ),
        isTrue,
      );
    });

    test('NO clasifica AuthException de cliente (400, 401, 422, 429) como error de conexión', () {
      // Credenciales inválidas
      expect(
        DatabaseHealthProvider.isConnectionError(
          const AuthException('Invalid login credentials', statusCode: '400'),
        ),
        isFalse,
      );

      // Usuario ya registrado
      expect(
        DatabaseHealthProvider.isConnectionError(
          const AuthException('User already registered', statusCode: '422'),
        ),
        isFalse,
      );

      // Token no autorizado / expirado
      expect(
        DatabaseHealthProvider.isConnectionError(
          const AuthException('Invalid JWT', statusCode: '401'),
        ),
        isFalse,
      );

      // Límite de tasa excedido
      expect(
        DatabaseHealthProvider.isConnectionError(
          const AuthException('Over rate limit', statusCode: '429'),
        ),
        isFalse,
      );

      // AuthException genérica
      expect(
        DatabaseHealthProvider.isConnectionError(
          const AuthException('Email not confirmed'),
        ),
        isFalse,
      );
    });

    test('NO clasifica PostgrestException de restricciones de cliente o lógica de negocio como error de conexión', () {
      // Violación de unicidad (Clase 23)
      expect(
        DatabaseHealthProvider.isConnectionError(
          const PostgrestException(
            message: 'duplicate key value violates unique constraint',
            code: '23505',
          ),
        ),
        isFalse,
      );

      // Violación de clave foránea (Clase 23)
      expect(
        DatabaseHealthProvider.isConnectionError(
          const PostgrestException(
            message: 'insert or update on table violates foreign key constraint',
            code: '23503',
          ),
        ),
        isFalse,
      );

      // Violación de campo no nulo (Clase 23)
      expect(
        DatabaseHealthProvider.isConnectionError(
          const PostgrestException(
            message: 'null value in column violates not-null constraint',
            code: '23502',
          ),
        ),
        isFalse,
      );

      // Formato o tipo de datos inválido (Clase 22)
      expect(
        DatabaseHealthProvider.isConnectionError(
          const PostgrestException(
            message: 'invalid input syntax for type uuid',
            code: '22P02',
          ),
        ),
        isFalse,
      );

      // Permisos / políticas RLS (Clase 42)
      expect(
        DatabaseHealthProvider.isConnectionError(
          const PostgrestException(
            message: 'permission denied for table mixes',
            code: '42501',
          ),
        ),
        isFalse,
      );

      // Códigos de cliente PostgREST
      expect(
        DatabaseHealthProvider.isConnectionError(
          const PostgrestException(
            message: 'JSON object requested, multiple (or no) rows returned',
            code: 'PGRST116',
          ),
        ),
        isFalse,
      );
      expect(
        DatabaseHealthProvider.isConnectionError(
          const PostgrestException(
            message: 'Column not found',
            code: 'PGRST204',
          ),
        ),
        isFalse,
      );
    });

    test('SÍ clasifica PostgrestException de infraestructura / caída de PostgreSQL como error de conexión', () {
      // Error de conexión PostgreSQL (Clase 08)
      expect(
        DatabaseHealthProvider.isConnectionError(
          const PostgrestException(
            message: 'connection failure',
            code: '08006',
          ),
        ),
        isTrue,
      );

      // Parada de servidor / caída (Clase 57)
      expect(
        DatabaseHealthProvider.isConnectionError(
          const PostgrestException(
            message: 'admin shutdown',
            code: '57P01',
          ),
        ),
        isTrue,
      );

      // Conexiones de pool agotadas
      expect(
        DatabaseHealthProvider.isConnectionError(
          const PostgrestException(
            message: 'too many connections',
            code: '53300',
          ),
        ),
        isTrue,
      );

      // Fallo de red explícito en mensaje de Postgrest
      expect(
        DatabaseHealthProvider.isConnectionError(
          const PostgrestException(
            message: 'Connection refused by remote host',
          ),
        ),
        isTrue,
      );
      expect(
        DatabaseHealthProvider.isConnectionError(
          const PostgrestException(
            message: 'Network request timed out',
          ),
        ),
        isTrue,
      );
    });

    test('errores estándar de Dart no son errores de conexión', () {
      expect(
        DatabaseHealthProvider.isConnectionError(const FormatException('Bad format')),
        isFalse,
      );
      expect(
        DatabaseHealthProvider.isConnectionError(ArgumentError('Invalid argument')),
        isFalse,
      );
    });
  });

  group('DatabaseHealthProvider.reportFailure', () {
    late FakeDatabaseHealthService fakeHealthService;
    late DatabaseHealthProvider provider;

    setUp(() {
      fakeHealthService = FakeDatabaseHealthService();
      provider = DatabaseHealthProvider(healthService: fakeHealthService);
    });

    tearDown(() {
      provider.dispose();
    });

    test('ignora AuthException y NO marca desconectado', () {
      expect(provider.isConnected, isTrue);

      DatabaseHealthProvider.reportFailure(
        const AuthException('Invalid login credentials', statusCode: '400'),
      );

      // La app debe permanecer conectada
      expect(provider.isConnected, isTrue);
    });

    test('ignora violaciones de restricciones PostgrestException y NO marca desconectado', () {
      expect(provider.isConnected, isTrue);

      DatabaseHealthProvider.reportFailure(
        const PostgrestException(
          message: 'duplicate key value violates unique constraint',
          code: '23505',
        ),
      );

      // La app debe permanecer conectada
      expect(provider.isConnected, isTrue);
    });

    test('marca desconectado inmediatamente ante un error de red real (SocketException)', () {
      expect(provider.isConnected, isTrue);

      DatabaseHealthProvider.reportFailure(
        const SocketException('Network unreachable'),
      );

      // Debe marcar desconectado inmediatamente
      expect(provider.isConnected, isFalse);
    });
  });
}
