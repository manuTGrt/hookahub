import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  SupabaseClient get client => Supabase.instance.client;

  // Auth API

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) {
    return client.auth.signUp(
      email: email,
      password: password,
      data: data,
      emailRedirectTo:
          'io.supabase.flutter://login-callback/', // Deep link para confirmación
    );
  }

  Future<void> signOut() async {
    // Sign out del proveedor nativo de Google si fue utilizado
    try {
      await gsi.GoogleSignIn.instance.signOut();
    } catch (_) {}
    return client.auth.signOut();
  }

  /// Asegura que exista un perfil para el usuario recién autenticado
  Future<void> ensureProfile({
    String? username,
    String? displayName,
    String? firstName,
    String? lastName,
    DateTime? birthdate,
    String? bio,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return;
    final uid = user.id;
    final email = user.email;
    // Construir datos de perfil (idempotente vía upsert)
    final profileData = <String, dynamic>{
      'id': uid,
      'username':
          username ??
          (email?.split('@').first ?? 'user_${uid.substring(0, 6)}'),
      'email': email,
      'display_name':
          displayName ?? firstName ?? email?.split('@').first ?? 'Usuario',
      'bio': bio,
      'birthdate': birthdate?.toIso8601String(),
      // No forzamos is_public si ya existía; pero para primer insert irá true.
      'is_public': true,
      // updated_at será manejado por la DB si tienes trigger; si no, lo dejamos a la DB.
    }..removeWhere((key, value) => value == null);

    // Crear/actualizar perfil. onConflict asegura que no se duplique.
    await client.from('profiles').upsert(profileData, onConflict: 'id');

    // Crear/actualizar configuración por defecto sin sobreescribir elecciones existentes
    await client.from('user_settings').upsert({
      'user_id': uid,
      'theme': 'system',
      'push_notifications': true,
      'email_notifications': false,
      'analytics_opt_in': false,
    }, onConflict: 'user_id');
  }

  // OAuth Google Nativo
  Future<void> signInWithGoogle() async {
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'];

    if (webClientId == null || webClientId.isEmpty) {
      throw const AuthException(
        'Falta GOOGLE_WEB_CLIENT_ID en el archivo .env. Por favor, configúralo.',
      );
    }

    final signInInstance = gsi.GoogleSignIn.instance;
    await signInInstance.initialize(
      serverClientId: webClientId,
      clientId: iosClientId?.isNotEmpty == true ? iosClientId : null,
    );

    gsi.GoogleSignInAccount googleUser;
    try {
      googleUser = await signInInstance.authenticate();
    } on gsi.GoogleSignInException catch (e) {
      if (e.code == gsi.GoogleSignInExceptionCode.canceled) {
        throw const AuthException('El inicio de sesión fue cancelado.');
      }
      throw AuthException(
        'Error al iniciar sesión con Google: ${e.toString()}',
      );
    }

    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw const AuthException('No se pudo obtener el ID Token de Google.');
    }

    // El accessToken opcional se solicita obteniendo la autorización del cliente
    String? accessToken;
    try {
      final authClient = await googleUser.authorizationClient.authorizeScopes(
        [],
      );
      accessToken = authClient.accessToken;
    } catch (_) {
      // Ignorar de forma segura si no podemos obtener accessToken
    }

    await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  /// Inicia sesión con Facebook mediante el flujo OAuth de Supabase.
  /// Abre un navegador (Custom Tab en Android, ASWebAuthenticationSession en iOS)
  /// y redirige de vuelta a la app via deep link al completar.
  Future<void> signInWithFacebook() async {
    await client.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: kIsWeb ? null : 'io.supabase.flutter://login-callback/',
    );
  }
}
