import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/env.dart';
import 'core/utils/app_logger.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase si las credenciales están configuradas
  if (!Env.isSupabaseConfigured) {
    AppLogger.warning('ATENCIÓN: SUPABASE_URL / SUPABASE_ANON_KEY no configurados.');
    runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      'Configuración Incompleta',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No se han detectado las variables de entorno.\n\nPara ejecutar desde la terminal incluye el flag:\nflutter run --dart-define-from-file=.env',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
    // Para OAuth (Google) el redirect URL se gestiona via deep links en cada plataforma.
    // y podremos pasar opciones adicionales si fuese necesario.
  );

  runApp(const HookahubApp());
}

