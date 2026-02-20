import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/data/supabase_service.dart';
import '../../core/providers/database_health_provider.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._svc) {
    _sub = _svc.client.auth.onAuthStateChange.listen((event) async {
      _session = event.session;
      final ev = event.event;
      if (_session != null &&
          (ev == AuthChangeEvent.signedIn ||
              ev == AuthChangeEvent.userUpdated)) {
        // Solo crear perfil básico si no se creó durante el registro
        final user = _session!.user;
        final metadata = user.userMetadata;

        await _svc.ensureProfile(
          username: metadata?['username']?.toString(),
          displayName:
              metadata != null &&
                  metadata['first_name'] != null &&
                  metadata['last_name'] != null
              ? '${metadata['first_name']} ${metadata['last_name']}'
              : metadata?['first_name']?.toString() ??
                    metadata?['last_name']?.toString(),
          firstName: metadata?['first_name']?.toString(),
          lastName: metadata?['last_name']?.toString(),
          birthdate: metadata?['birthdate'] != null
              ? DateTime.tryParse(metadata!['birthdate'].toString())
              : null,
          bio: metadata?['bio']?.toString(),
        );
      }
      notifyListeners();
    });
    _session = _svc.client.auth.currentSession;
  }

  final SupabaseService _svc;
  Session? _session;
  StreamSubscription<AuthState>? _sub;

  Session? get session => _session;
  User? get user => _session?.user;
  bool get isAuthenticated => user != null;

  Future<String?> signInEmail(String email, String password) async {
    try {
      await _svc
          .signInWithEmail(email: email, password: password)
          .timeout(const Duration(seconds: 4));
      return null;
    } on AuthException catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return e.message;
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return 'Error inesperado';
    }
  }

  Future<String?> registerEmail(
    String email,
    String password, {
    String? username,
    String? firstName,
    String? lastName,
    DateTime? birthdate,
    String? bio,
  }) async {
    try {
      final response = await _svc
          .signUpWithEmail(
            email: email,
            password: password,
            data: {
              'username': username,
              'first_name': firstName,
              'last_name': lastName,
              'birthdate': birthdate?.toIso8601String(),
              'bio': bio,
            }..removeWhere((key, value) => value == null),
          )
          .timeout(const Duration(seconds: 4));

      // Si el usuario se crea inmediatamente (sin confirmación de email)
      if (response.user != null) {
        await _svc
            .ensureProfile(
              username: username,
              displayName: firstName != null && lastName != null
                  ? '$firstName $lastName'
                  : firstName ?? lastName,
              firstName: firstName,
              lastName: lastName,
              birthdate: birthdate,
              bio: bio,
            )
            .timeout(const Duration(seconds: 4));
      }

      return null;
    } on AuthException catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return e.message;
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return 'Error inesperado: ${e.toString()}';
    }
  }

  Future<String?> signInGoogle() async {
    try {
      await _svc.signInWithGoogle().timeout(const Duration(seconds: 4));
      return null;
    } on AuthException catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return e.message;
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return 'Error inesperado';
    }
  }

  Future<String?> signInFacebook() async {
    try {
      await _svc.signInWithFacebook().timeout(const Duration(seconds: 4));
      return null;
    } on AuthException catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return e.message;
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return 'Error inesperado';
    }
  }

  Future<void> signOut() async {
    try {
      await _svc.signOut().timeout(const Duration(seconds: 4));
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      // Ignorar error de signOut, ya que el token local se borrará de todos modos
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
