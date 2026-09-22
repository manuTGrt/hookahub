import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/data/supabase_service.dart';
import 'package:hookahub/core/theme_provider.dart';
import 'package:hookahub/features/auth/auth_provider.dart';
import 'package:hookahub/features/auth/login_page.dart';
import 'package:hookahub/widgets/pastel_textfield.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  @override
  SupabaseClient get client => FakeSupabaseClient();

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoginPage Controller Lifecycle & Memory Leak Tests', () {
    testWidgets(
      'LoginPage disposes _emailController and _passwordController when unmounted',
      (tester) async {
        final fakeSvc = FakeAuthSupabaseService();
        final authProvider = AuthProvider(fakeSvc);
        final themeProvider = ThemeProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
            ],
            child: const MaterialApp(
              home: LoginPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Encontrar los campos PastelTextField de correo y contraseña
        final emailFinder = find.widgetWithText(
          PastelTextField,
          'Correo electrónico',
        );
        final passwordFinder = find.widgetWithText(
          PastelTextField,
          'Contraseña',
        );

        expect(emailFinder, findsOneWidget);
        expect(passwordFinder, findsOneWidget);

        final emailWidget = tester.widget<PastelTextField>(emailFinder);
        final passwordWidget = tester.widget<PastelTextField>(passwordFinder);

        final emailController = emailWidget.controller;
        final passwordController = passwordWidget.controller;

        expect(emailController, isNotNull);
        expect(passwordController, isNotNull);

        // Los controladores funcionan normalmente mientras LoginPage está activa
        expect(() => emailController.text = 'test@example.com', returnsNormally);
        expect(() => passwordController.text = 'secret123', returnsNormally);

        // Desmontar LoginPage reemplazando la vista
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pumpAndSettle();

        // Al haberse llamado a dispose(), cualquier intento de interactuar con los
        // controladores debe lanzar la excepción de Flutter indicando que ya han sido disposed.
        expect(
          () => emailController.addListener(() {}),
          throwsA(
            isA<FlutterError>().having(
              (e) => e.message,
              'message',
              contains('used after being disposed'),
            ),
          ),
          reason: '_emailController debe ser disposed al desmontar LoginPage',
        );

        expect(
          () => passwordController.addListener(() {}),
          throwsA(
            isA<FlutterError>().having(
              (e) => e.message,
              'message',
              contains('used after being disposed'),
            ),
          ),
          reason: '_passwordController debe ser disposed al desmontar LoginPage',
        );

        authProvider.dispose();
        themeProvider.dispose();
      },
    );
  });
}
