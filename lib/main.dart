import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno
  await dotenv.load(fileName: '.env');

  final url = dotenv.env['SUPABASE_URL'];
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

  // Inicializar Supabase
  if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
    // Continuar sin inicializar para no romper en dev, pero loguear en consola
    debugPrint('ATENCIÓN: SUPABASE_URL / SUPABASE_ANON_KEY no configurados.');
  } else {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      // Para OAuth (Google/Facebook) añadiremos el redirect URL en plataformas más adelante
      // y podremos pasar opciones adicionales si fuese necesario.
    );
  }

  runApp(const HookahubApp());
}

//
