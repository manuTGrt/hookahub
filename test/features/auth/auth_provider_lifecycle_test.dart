import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/data/supabase_service.dart';
import 'package:hookahub/features/auth/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Session? get currentSession => null;
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  @override
  GoTrueClient get auth => FakeGoTrueClient();
}

class FakeAuthSupabaseService implements SupabaseService {
  bool signOutCalled = false;

  @override
  SupabaseClient get client => FakeSupabaseClient();

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthProvider Lifecycle Listeners', () {
    test('addSignOutListener se ejecuta cuando se llama a signOut()', () async {
      final fakeSvc = FakeAuthSupabaseService();
      final authProvider = AuthProvider(fakeSvc);

      bool signOutListenerCalled = false;
      authProvider.addSignOutListener(() {
        signOutListenerCalled = true;
      });

      await authProvider.signOut();

      expect(fakeSvc.signOutCalled, isTrue);
      expect(signOutListenerCalled, isTrue);

      authProvider.dispose();
    });

    test('removeSignOutListener desregistra el callback correctamente', () async {
      final fakeSvc = FakeAuthSupabaseService();
      final authProvider = AuthProvider(fakeSvc);

      int callCount = 0;
      void listener() {
        callCount++;
      }

      authProvider.addSignOutListener(listener);
      authProvider.removeSignOutListener(listener);

      await authProvider.signOut();

      expect(callCount, 0);

      authProvider.dispose();
    });
  });
}
