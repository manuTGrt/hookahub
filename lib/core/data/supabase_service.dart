import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> signOut() => client.auth.signOut();

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

  // OAuth
  Future<void> signInWithGoogle() async {
    await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.flutter://login-callback/',
    );
  }

  Future<void> signInWithFacebook() async {
    await client.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: 'io.supabase.flutter://login-callback/',
    );
  }
}
