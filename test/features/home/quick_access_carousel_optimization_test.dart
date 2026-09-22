import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/features/home/home_page.dart';

void main() {
  testWidgets('QuickAccessCarousel no reconstruye buildCard durante el scroll horizontal', (
    WidgetTester tester,
  ) async {
    int buildCardCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: QuickAccessCarousel(
                scaleFactor: 1.0,
                buildCard: (context) {
                  buildCardCalls++;
                  return List.generate(
                    8,
                    (index) => Container(
                      key: ValueKey('card_$index'),
                      color: Colors.blue,
                      child: Center(child: Text('Card $index')),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Se construye inicialmente una sola vez
    expect(buildCardCalls, 1);

    // Realizar un arrastre continuo en múltiples pasos
    final gesture = await tester.startGesture(const Offset(200, 100));
    for (int i = 0; i < 15; i++) {
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    // Verificación clave: buildCard NO se ejecutó durante el scroll
    expect(
      buildCardCalls,
      1,
      reason: 'buildCard debe llamarse solo al montar o por layout, no durante el scroll a 60/120 fps',
    );
  });

  testWidgets('QuickAccessCarousel actualiza visibilidad de fades sin reconstruir el contenido', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: QuickAccessCarousel(
                scaleFactor: 1.0,
                buildCard: (context) {
                  return List.generate(
                    10,
                    (index) => Container(
                      key: ValueKey('item_$index'),
                      color: Colors.green,
                      child: Center(child: Text('Item $index')),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // En posición 0:
    // El fade izquierdo no debe renderizarse (SizedBox.shrink), el derecho sí (Container)
    expect(find.byKey(const Key('quick_access_fade_left')), findsNothing);
    expect(find.byKey(const Key('quick_access_fade_right')), findsOneWidget);

    // Desplazamos 100px a la izquierda usando tester.drag
    await tester.drag(find.byType(SingleChildScrollView), const Offset(-100, 0));
    await tester.pumpAndSettle();

    // Ahora ambos fades deben estar visibles (izquierdo y derecho)
    expect(find.byKey(const Key('quick_access_fade_left')), findsOneWidget);
    expect(find.byKey(const Key('quick_access_fade_right')), findsOneWidget);

    // Desplazamos hasta el final (más de 1500px hacia la izquierda)
    await tester.drag(find.byType(SingleChildScrollView), const Offset(-2000, 0));
    await tester.pumpAndSettle();

    // En el final: izquierdo visible, derecho oculto
    expect(find.byKey(const Key('quick_access_fade_left')), findsOneWidget);
    expect(find.byKey(const Key('quick_access_fade_right')), findsNothing);

    // Retornamos al inicio (desplazamiento hacia la derecha)
    await tester.drag(find.byType(SingleChildScrollView), const Offset(2000, 0));
    await tester.pumpAndSettle();

    // De vuelta al inicio: izquierdo oculto, derecho visible
    expect(find.byKey(const Key('quick_access_fade_left')), findsNothing);
    expect(find.byKey(const Key('quick_access_fade_right')), findsOneWidget);
  });
}
