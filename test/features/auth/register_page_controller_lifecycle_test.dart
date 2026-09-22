import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/data/supabase_service.dart';
import 'package:hookahub/features/auth/auth_provider.dart';
import 'package:hookahub/features/auth/presentation/register_page.dart';
import 'package:hookahub/widgets/pastel_textfield.dart';
import 'package:provider/provider.dart';
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

  Widget buildTestWidget({required AuthProvider authProvider}) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: const MaterialApp(
        home: RegisterPage(),
      ),
    );
  }

  group('RegisterPage Controller Lifecycle & Memory Leak Fix', () {
    testWidgets(
        'El controlador de fecha de nacimiento conserva su instancia y no se recrea en cada build()',
        (tester) async {
      final fakeSvc = FakeAuthSupabaseService();
      final authProvider = AuthProvider(fakeSvc);

      await tester.pumpWidget(buildTestWidget(authProvider: authProvider));
      await tester.pumpAndSettle();

      // Encontrar el PastelTextField correspondiente a la fecha de nacimiento
      final dateFinder = find.widgetWithText(
        PastelTextField,
        'Selecciona tu fecha de nacimiento',
      );
      expect(dateFinder, findsOneWidget);

      final dateWidgetBefore = tester.widget<PastelTextField>(dateFinder);
      final controllerInstanceBefore = dateWidgetBefore.controller;

      // Provocar múltiples reconstrucciones del widget escribiendo en otros campos
      final usernameField = find.widgetWithText(
        PastelTextField,
        'Introduce tu nombre de usuario',
      );
      expect(usernameField, findsOneWidget);

      // Simular tecleo secuencial para disparar rebuilds continuos
      await tester.enterText(usernameField, 'a');
      await tester.pump();
      await tester.enterText(usernameField, 'ab');
      await tester.pump();
      await tester.enterText(usernameField, 'abc');
      await tester.pump();

      // Obtener el widget tras las reconstrucciones
      final dateWidgetAfter = tester.widget<PastelTextField>(dateFinder);
      final controllerInstanceAfter = dateWidgetAfter.controller;

      // Verificar que es exactamente la misma instancia y no una creada al vuelo
      expect(
        identical(controllerInstanceBefore, controllerInstanceAfter),
        isTrue,
        reason:
            'El controller de fecha no debe recrearse en el build() en cada rebuild',
      );

      // Desmontar el widget y verificar que se desecha limpiamente sin excepciones
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      authProvider.dispose();
    });
  });
}
