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
  bool authenticated = true;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Session? get currentSession => authenticated
      ? Session(
          accessToken: 'fake-token',
          tokenType: 'bearer',
          user: const User(
            id: 'test-user-id',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-01-01',
          ),
        )
      : null;
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  FakeSupabaseClient(this._auth);
  final FakeGoTrueClient _auth;

  @override
  GoTrueClient get auth => _auth;
}

class FakeAuthSupabaseService implements SupabaseService {
  FakeAuthSupabaseService({this.authenticated = true});
  bool authenticated;

  @override
  SupabaseClient get client =>
      FakeSupabaseClient(FakeGoTrueClient()..authenticated = authenticated);

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSealedProfileRepository implements ProfileRepository {
  bool shouldThrow = false;
  Profile testProfile = Profile(
    id: 'test-user-id',
    username: 'test_hookah',
    displayName: 'Hookah Tester',
    email: 'tester@example.com',
    avatarUrl: 'https://example.com/avatar.png',
  );
  int countMixes = 5;

  @override
  Future<Profile?> getCurrentUserProfile() async {
    if (shouldThrow) throw Exception('Database error');
    return testProfile;
  }

  @override
  Future<int> countCurrentUserMixes() async {
    if (shouldThrow) throw Exception('Database error');
    return countMixes;
  }

  @override
  Future<String?> createSignedAvatarUrl(String? path) async {
    if (path == null) return null;
    return 'https://signed.example.com/$path';
  }

  @override
  Future<String> uploadAvatarAndSave(String filePath) async {
    return 'avatars/new_avatar.png';
  }

  @override
  Future<void> clearAvatarForCurrentUser() async {
    testProfile = Profile(
      id: testProfile.id,
      username: testProfile.username,
      displayName: testProfile.displayName,
      email: testProfile.email,
      avatarUrl: null,
    );
  }

  @override
  Future<void> setAvatarIcon(int iconIndex) async {
    testProfile = Profile(
      id: testProfile.id,
      username: testProfile.username,
      displayName: testProfile.displayName,
      email: testProfile.email,
      avatarUrl: 'icon:$iconIndex',
    );
  }

  @override
  Future<void> updateCurrentUser(ProfileUpdate update) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHealthProvider healthProvider;
  late FakeAuthSupabaseService fakeAuthSvc;
  late AuthProvider authProvider;
  late FakeSealedProfileRepository fakeRepo;
  late ProfileProvider profileProvider;

  setUp(() {
    healthProvider = DatabaseHealthProvider(
      healthService: FakeDatabaseHealthService(),
    );
    fakeAuthSvc = FakeAuthSupabaseService(authenticated: true);
    authProvider = AuthProvider(fakeAuthSvc);
    fakeRepo = FakeSealedProfileRepository();
    profileProvider = ProfileProvider(
      repository: fakeRepo,
      auth: authProvider,
    );
  });

  tearDown(() {
    profileProvider.dispose();
    authProvider.dispose();
    healthProvider.dispose();
  });

  group('ProfileProvider Sealed State Transitions', () {
    test('Inicia en ProfileInitial y getters iniciales son consistentes', () {
      expect(profileProvider.state, isA<ProfileInitial>());
      expect(profileProvider.isLoading, isFalse);
      expect(profileProvider.isLoaded, isFalse);
      expect(profileProvider.error, isNull);
      expect(profileProvider.profile, isNull);
      expect(profileProvider.mixesCount, 0);
      expect(profileProvider.signedAvatarUrl, isNull);
    });

    test('load() sin autenticación transita a ProfileError("No autenticado")', () async {
      final unauthSvc = FakeAuthSupabaseService(authenticated: false);
      final unauthProvider = AuthProvider(unauthSvc);
      final unauthProfileProvider = ProfileProvider(
        repository: fakeRepo,
        auth: unauthProvider,
      );

      await unauthProfileProvider.load();

      expect(unauthProfileProvider.state, isA<ProfileError>());
      final errorState = unauthProfileProvider.state as ProfileError;
      expect(errorState.message, 'No autenticado');
      expect(unauthProfileProvider.isLoading, isFalse);
      expect(unauthProfileProvider.isLoaded, isFalse);
      expect(unauthProfileProvider.profile, isNull);

      unauthProfileProvider.dispose();
      unauthProvider.dispose();
    });

    test('load() autenticado transita a ProfileLoaded con perfil y conteo', () async {
      final future = profileProvider.load();
      // Durante load debe estar en ProfileLoading
      expect(profileProvider.state, isA<ProfileLoading>());
      expect(profileProvider.isLoading, isTrue);

      await future;

      expect(profileProvider.state, isA<ProfileLoaded>());
      final loadedState = profileProvider.state as ProfileLoaded;
      expect(loadedState.profile?.username, 'test_hookah');
      expect(loadedState.mixesCount, 5);
      expect(loadedState.signedAvatarUrl, contains('https://signed.example.com/'));

      // Comprobar getters derivados
      expect(profileProvider.isLoaded, isTrue);
      expect(profileProvider.isLoading, isFalse);
      expect(profileProvider.error, isNull);
      expect(profileProvider.profile?.displayName, 'Hookah Tester');
    });

    test('load() con fallo en repositorio transita a ProfileError y evita estados contradictorios', () async {
      fakeRepo.shouldThrow = true;

      await profileProvider.load();

      expect(profileProvider.state, isA<ProfileError>());
      final errorState = profileProvider.state as ProfileError;
      expect(errorState.message, 'Error cargando perfil');
      expect(profileProvider.isLoading, isFalse);
      expect(profileProvider.isLoaded, isFalse);
      expect(profileProvider.error, isNotNull);
      expect(profileProvider.profile, isNull);
    });

    test('clear() restablece el estado a ProfileInitial', () async {
      await profileProvider.load();
      expect(profileProvider.state, isA<ProfileLoaded>());

      profileProvider.clear();

      expect(profileProvider.state, isA<ProfileInitial>());
      expect(profileProvider.profile, isNull);
      expect(profileProvider.isLoaded, isFalse);
      expect(profileProvider.isLoading, isFalse);
      expect(profileProvider.error, isNull);
    });

    test('uploadAvatar() y clearAvatar() actualizan ProfileLoaded de forma inmutable', () async {
      await profileProvider.load();
      expect(profileProvider.state, isA<ProfileLoaded>());

      await profileProvider.uploadAvatar('/dummy/path.png');
      expect(profileProvider.state, isA<ProfileLoaded>());
      expect(profileProvider.signedAvatarUrl, contains('avatars/new_avatar.png'));

      await profileProvider.clearAvatar();
      expect(profileProvider.state, isA<ProfileLoaded>());
      expect(profileProvider.signedAvatarUrl, isNull);
    });
  });
}
