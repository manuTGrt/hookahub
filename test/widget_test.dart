// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:hookahub/app.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});
  });

  testWidgets('La app arranca y muestra la pantalla inicial', (tester) async {
    await tester.pumpWidget(const HookahubApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // La app por defecto carga LoginPage; comprobamos textos comunes
    // según el diseño mínimo (si cambia, ajusta el finder).
    expect(find.textContaining('Hookahub'), findsWidgets);
  });
}
