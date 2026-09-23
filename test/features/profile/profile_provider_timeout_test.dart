import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/data/supabase_service.dart';
import 'package:hookahub/core/providers/database_health_provider.dart';
import 'package:hookahub/core/services/database_health_service.dart';
import 'package:hookahub/features/auth/auth_provider.dart';
import 'package:hookahub/features/profile/data/profile_repository.dart';
import 'package:hookahub/features/profile/domain/profile.dart';
import 'package:hookahub/features/profile/presentation/profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeDatabaseHealthService implements DatabaseHealthService {
  @override
  Future<bool> checkDatabaseConnection() async => true;
}

class FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Session? get currentSession => Session(
        accessToken: 'fake-token',
        tokenType: 'bearer',
        user: const User(
          id: 'user-123',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        ),
      );
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  @override
  GoTrueClient get auth => FakeGoTrueClient();
}

class FakeAuthSupabaseService implements SupabaseService {
  @override
  SupabaseClient get client => FakeSupabaseClient();

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TimeoutProfileRepository implements ProfileRepository {
  bool shouldTimeout = true;

  @override
  Future<Profile?> getCurrentUserProfile() async {
    if (shouldTimeout) {
      throw TimeoutException('Supabase query timeout');
    }
    return Profile(
      id: 'user-123',
      username: 'testuser',
      email: 'test@example.com',
    );
  }

  @override
  Future<int> countCurrentUserMixes() async {
    return 0;
  }

  @override
  Future<String?> createSignedAvatarUrl(String? storagePath) async {
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHealthProvider healthProvider;

  setUp(() {
    healthProvider = DatabaseHealthProvider(
      healthService: FakeDatabaseHealthService(),
    );
  });

  tearDown(() {
    healthProvider.dispose();
  });

  group('ProfileProvider Timeout Handling', () {
    test('load() ante TimeoutException desactiva isLoading y registra error', () async {
      final fakeAuthSvc = FakeAuthSupabaseService();
      final authProvider = AuthProvider(fakeAuthSvc);
      final profileRepo = TimeoutProfileRepository();
      final profileProvider = ProfileProvider(
        repository: profileRepo,
        auth: authProvider,
      );

      expect(profileProvider.isLoading, isFalse);

      await profileProvider.load();

      // No debe quedarse en spinner perpetuo
      expect(profileProvider.isLoading, isFalse);
      expect(profileProvider.error, equals('Error cargando perfil'));
      expect(profileProvider.profile, isNull);

      profileProvider.dispose();
      authProvider.dispose();
    });
  });
}
