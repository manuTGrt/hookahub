import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/models/tobacco.dart';
import 'package:hookahub/features/community/presentation/create_mix_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tobaccoA = Tobacco(
    id: 'tobacco-1',
    name: 'Love 66',
    brand: 'Adalya',
    flavors: ['Melon', 'Watermelon', 'Mint'],
  );

  const tobaccoB = Tobacco(
    id: 'tobacco-2',
    name: 'Mi Amor',
    brand: 'Adalya',
    flavors: ['Pineapple', 'Banana', 'Mint'],
  );

  const tobaccoC = Tobacco(
    id: 'tobacco-3',
    name: 'Lady Killer',
    brand: 'Adalya',
    flavors: ['Peach', 'Mango', 'Mint'],
  );

  group('SelectedIngredient Lifecycle & Memory Leak Fix Tests', () {
    test('SelectedIngredient initializes with default value 25 and can be edited', () {
      final ingredient = SelectedIngredient(tobacco: tobaccoA);

      expect(ingredient.percentCtrl.text, '25');
      expect(() => ingredient.percentCtrl.text = '50', returnsNormally);
      expect(ingredient.percentCtrl.text, '50');

      ingredient.dispose();
    });

    test('SelectedIngredient.dispose() properly disposes its TextEditingController', () {
      final ingredient = SelectedIngredient(tobacco: tobaccoA);
      final controller = ingredient.percentCtrl;

      expect(() => controller.text = '30', returnsNormally);

      // Disponer el ingrediente
      ingredient.dispose();

      // Al haber sido desechado, cualquier acceso a listeners o mutación debe lanzar FlutterError
      expect(
        () => controller.addListener(() {}),
        throwsA(
          isA<FlutterError>().having(
            (e) => e.message,
            'message',
            contains('used after being disposed'),
          ),
        ),
        reason: 'percentCtrl debe estar disposed tras ingredient.dispose()',
      );
    });

    test(
      'Removing ingredient via _removeIngredient pattern immediately disposes its controller',
      () {
        final ingredients = <SelectedIngredient>[
          SelectedIngredient(tobacco: tobaccoA),
          SelectedIngredient(tobacco: tobaccoB),
          SelectedIngredient(tobacco: tobaccoC),
        ];

        final removedCtrlA = ingredients[0].percentCtrl;
        final keptCtrlB = ingredients[1].percentCtrl;
        final keptCtrlC = ingredients[2].percentCtrl;

        // Simular _removeIngredient('tobacco-1')
        final idToRemove = 'tobacco-1';
        ingredients.removeWhere((e) {
          final matches = e.tobacco.id == idToRemove;
          if (matches) {
            e.dispose();
          }
          return matches;
        });

        // Verificar que la lista sólo contiene los ingredientes restantes
        expect(ingredients.length, 2);
        expect(ingredients.any((e) => e.tobacco.id == 'tobacco-1'), isFalse);
        expect(ingredients[0].tobacco.id, 'tobacco-2');
        expect(ingredients[1].tobacco.id, 'tobacco-3');

        // El controlador del ingrediente eliminado DEBE estar disposed (fuga solventada)
        expect(
          () => removedCtrlA.addListener(() {}),
          throwsA(
            isA<FlutterError>().having(
              (e) => e.message,
              'message',
              contains('used after being disposed'),
            ),
          ),
          reason: 'El controlador del ingrediente eliminado no debe quedar flotando en memoria',
        );

        // Los controladores de los ingredientes restantes deben permanecer perfectamente utilizables
        expect(() => keptCtrlB.text = '60', returnsNormally);
        expect(() => keptCtrlC.text = '40', returnsNormally);
        expect(keptCtrlB.text, '60');
        expect(keptCtrlC.text, '40');

        // Limpieza final de los restantes
        for (final ing in ingredients) {
          ing.dispose();
        }
      },
    );

    test(
      'Reloading existing mix data disposes previous ingredients before clearing',
      () {
        final ingredients = <SelectedIngredient>[
          SelectedIngredient(tobacco: tobaccoA),
          SelectedIngredient(tobacco: tobaccoB),
        ];

        final oldCtrlA = ingredients[0].percentCtrl;
        final oldCtrlB = ingredients[1].percentCtrl;

        final newIngredients = <SelectedIngredient>[
          SelectedIngredient(tobacco: tobaccoC),
        ];

        // Simular lógica de _loadExistingMixData:
        for (final ing in ingredients) {
          ing.dispose();
        }
        ingredients
          ..clear()
          ..addAll(newIngredients);

        expect(ingredients.length, 1);
        expect(ingredients.first.tobacco.id, 'tobacco-3');

        // Los controladores anteriores deben estar desechados
        expect(
          () => oldCtrlA.addListener(() {}),
          throwsA(isA<FlutterError>()),
          reason: 'Los controladores previos deben ser liberados al recargar',
        );
        expect(
          () => oldCtrlB.addListener(() {}),
          throwsA(isA<FlutterError>()),
          reason: 'Los controladores previos deben ser liberados al recargar',
        );

        // El nuevo controlador debe estar operativo
        expect(() => ingredients.first.percentCtrl.text = '100', returnsNormally);

        // Limpieza
        for (final ing in ingredients) {
          ing.dispose();
        }
      },
    );

    test('Disposing all ingredients as in CreateMixPage.dispose cleans up all controllers', () {
      final ingredients = <SelectedIngredient>[
        SelectedIngredient(tobacco: tobaccoA),
        SelectedIngredient(tobacco: tobaccoB),
      ];

      final ctrlA = ingredients[0].percentCtrl;
      final ctrlB = ingredients[1].percentCtrl;

      // Simular CreateMixPage.dispose()
      for (final ing in ingredients) {
        ing.dispose();
      }

      expect(() => ctrlA.addListener(() {}), throwsA(isA<FlutterError>()));
      expect(() => ctrlB.addListener(() {}), throwsA(isA<FlutterError>()));
    });
  });
}
