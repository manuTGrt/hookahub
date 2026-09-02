import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/data/supabase_service.dart';
import '../../core/providers/database_health_provider.dart';
import '../../core/utils/app_logger.dart';

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

        if (ev == AuthChangeEvent.signedIn) {
          _notifySignIn();
        }
      } else if (ev == AuthChangeEvent.signedOut || _session == null) {
        _notifySignOut();
      }
      notifyListeners();
    });
    _session = _svc.client.auth.currentSession;
  }

  final SupabaseService _svc;
  Session? _session;
  StreamSubscription<AuthState>? _sub;

  final List<VoidCallback> _signInListeners = [];
  final List<VoidCallback> _signOutListeners = [];

  Session? get session => _session;
  User? get user => _session?.user;
  bool get isAuthenticated => user != null;

  /// Registra un listener que se ejecutará cuando el usuario inicie sesión
  void addSignInListener(VoidCallback listener) {
    _signInListeners.add(listener);
  }

  /// Desregistra un listener de inicio de sesión
  void removeSignInListener(VoidCallback listener) {
    _signInListeners.remove(listener);
  }

  /// Registra un listener que se ejecutará cuando el usuario cierre sesión
  void addSignOutListener(VoidCallback listener) {
    _signOutListeners.add(listener);
  }

  /// Desregistra un listener de cierre de sesión
  void removeSignOutListener(VoidCallback listener) {
    _signOutListeners.remove(listener);
  }

  void _notifySignIn() {
    for (final listener in List<VoidCallback>.of(_signInListeners)) {
      try {
        listener();
      } catch (e, stack) {
        AppLogger.error('Error en listener de inicio de sesión', error: e, stackTrace: stack);
      }
    }
  }

  void _notifySignOut() {
    for (final listener in List<VoidCallback>.of(_signOutListeners)) {
      try {
        listener();
      } catch (e, stack) {
        AppLogger.error('Error en listener de cierre de sesión', error: e, stackTrace: stack);
      }
    }
  }

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
      await _svc.signInWithGoogle();
      return null;
    } on AuthException catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return e.message;
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return 'Error inesperado: $e';
    }
  }

  Future<void> signOut() async {
    try {
      await _svc.signOut().timeout(const Duration(seconds: 4));
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      // Ignorar error de signOut, ya que el token local se borrará de todos modos
    } finally {
      _session = null;
      _notifySignOut();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _signInListeners.clear();
    _signOutListeners.clear();
    super.dispose();
  }
}
