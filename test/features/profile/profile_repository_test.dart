import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/data/supabase_service.dart';
import 'package:hookahub/features/profile/data/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockGoTrueClientWithoutUser extends Fake implements GoTrueClient {
  @override
  User? get currentUser => null;
}

class MockSupabaseClientWithoutUser extends Fake implements SupabaseClient {
  @override
  GoTrueClient get auth => MockGoTrueClientWithoutUser();
}

class MockSupabaseServiceWithoutUser implements SupabaseService {
  @override
  SupabaseClient get client => MockSupabaseClientWithoutUser();

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockGoTrueClientWithUser extends Fake implements GoTrueClient {
  @override
  User? get currentUser => const User(
        id: 'test-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );
}

class MockSupabaseClientWithError extends Fake implements SupabaseClient {
  @override
  GoTrueClient get auth => MockGoTrueClientWithUser();

  @override
  SupabaseQueryBuilder from(String table) {
    throw TimeoutException('Supabase connection timed out');
  }
}

class MockSupabaseServiceWithError implements SupabaseService {
  @override
  SupabaseClient get client => MockSupabaseClientWithError();

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileRepository.countCurrentUserMixes', () {
    test('retorna 0 de inmediato si no hay usuario autenticado', () async {
      final repo = ProfileRepository(MockSupabaseServiceWithoutUser());
      final count = await repo.countCurrentUserMixes();

      expect(count, equals(0));
    });

    test('captura excepciones y retorna 0 como fallback resiliente', () async {
      final repo = ProfileRepository(MockSupabaseServiceWithError());
      final count = await repo.countCurrentUserMixes();

      expect(count, equals(0));
    });
  });
}
