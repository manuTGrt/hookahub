/// Configuración de variables de entorno inyectadas en tiempo de compilación.
///
/// Se utiliza `--dart-define-from-file=.env` durante la ejecución o compilación.
/// De esta forma se evita empaquetar archivos de texto plano dentro de los
/// assets de la aplicación y se elimina el coste de lectura asíncrona en el arranque.
abstract final class Env {
  /// URL del proyecto de Supabase.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Clave pública anónima (anon key) de Supabase.
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Client ID web de Google para Google Sign-In (OAuth).
  static const String googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// Client ID iOS de Google para Google Sign-In (OAuth).
  static const String googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  /// Comprueba si las variables mínimas esenciales de Supabase están definidas.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
