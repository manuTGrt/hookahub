import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/features/community/domain/mix_percentage_calculator.dart';

class _TestPercentageItem implements MixPercentageItem {
  _TestPercentageItem({
    required this.percentage,
    this.isManual = false,
  });

  @override
  bool isManual;

  @override
  double percentage;
}

void main() {
  group('MixPercentageCalculator Tests', () {
    test('Empty list does nothing without error', () {
      final items = <_TestPercentageItem>[];
      expect(() => MixPercentageCalculator.rebalance(items), returnsNormally);
      expect(items, isEmpty);
    });

    test('1 automatic item receives 100%', () {
      final items = [_TestPercentageItem(percentage: 25)];
      MixPercentageCalculator.rebalance(items);

      expect(items[0].percentage, 100.0);
    });

    test('2 automatic items receive 50% each', () {
      final items = [
        _TestPercentageItem(percentage: 25),
        _TestPercentageItem(percentage: 25),
      ];
      MixPercentageCalculator.rebalance(items);

      expect(items[0].percentage, 50.0);
      expect(items[1].percentage, 50.0);
      expect(items[0].percentage + items[1].percentage, 100.0);
    });

    test('3 automatic items receive 34%, 33%, 33% summing exactly 100%', () {
      final items = [
        _TestPercentageItem(percentage: 25),
        _TestPercentageItem(percentage: 25),
        _TestPercentageItem(percentage: 25),
      ];
      MixPercentageCalculator.rebalance(items);

      expect(items[0].percentage, 34.0);
      expect(items[1].percentage, 33.0);
      expect(items[2].percentage, 33.0);
      expect(items.fold<double>(0, (a, b) => a + b.percentage), 100.0);
    });

    test('4 automatic items receive 25% each summing 100%', () {
      final items = [
        _TestPercentageItem(percentage: 0),
        _TestPercentageItem(percentage: 0),
        _TestPercentageItem(percentage: 0),
        _TestPercentageItem(percentage: 0),
      ];
      MixPercentageCalculator.rebalance(items);

      expect(items.map((i) => i.percentage), [25.0, 25.0, 25.0, 25.0]);
      expect(items.fold<double>(0, (a, b) => a + b.percentage), 100.0);
    });

    test('Manual item percentage is preserved and remaining is assigned to new item', () {
      final items = [
        _TestPercentageItem(percentage: 70, isManual: true),
        _TestPercentageItem(percentage: 0, isManual: false),
      ];
      MixPercentageCalculator.rebalance(items);

      expect(items[0].percentage, 70.0, reason: 'El porcentaje manual no se debe recalcular');
      expect(items[1].percentage, 30.0, reason: 'El restante debe asignarse al nuevo tabaco');
      expect(items[0].percentage + items[1].percentage, 100.0);
    });

    test('Manual item is preserved and remaining is split among multiple automatic items', () {
      final items = [
        _TestPercentageItem(percentage: 40, isManual: true),
        _TestPercentageItem(percentage: 0, isManual: false),
        _TestPercentageItem(percentage: 0, isManual: false),
      ];
      MixPercentageCalculator.rebalance(items);

      expect(items[0].percentage, 40.0);
      expect(items[1].percentage, 30.0);
      expect(items[2].percentage, 30.0);
      expect(items.fold<double>(0, (a, b) => a + b.percentage), 100.0);
    });

    test('Removing an item rebalances remaining automatic items to 100%', () {
      final items = [
        _TestPercentageItem(percentage: 34, isManual: false),
        _TestPercentageItem(percentage: 33, isManual: false),
        _TestPercentageItem(percentage: 33, isManual: false),
      ];

      // Simular borrado de un tabaco
      items.removeLast();
      MixPercentageCalculator.rebalance(items);

      expect(items.length, 2);
      expect(items[0].percentage, 50.0);
      expect(items[1].percentage, 50.0);
      expect(items[0].percentage + items[1].percentage, 100.0);
    });

    test('Removing an item with a manual item rebalances remaining auto items keeping manual intact', () {
      final items = [
        _TestPercentageItem(percentage: 40, isManual: true),
        _TestPercentageItem(percentage: 30, isManual: false),
        _TestPercentageItem(percentage: 30, isManual: false),
      ];

      // Borrar el último item
      items.removeLast();
      MixPercentageCalculator.rebalance(items);

      expect(items.length, 2);
      expect(items[0].percentage, 40.0, reason: 'El item manual debe mantenerse');
      expect(items[1].percentage, 60.0, reason: 'El restante 60% va al único automático');
      expect(items[0].percentage + items[1].percentage, 100.0);
    });

    test('Over-allocated manual items assign 0% to automatic items', () {
      final items = [
        _TestPercentageItem(percentage: 70, isManual: true),
        _TestPercentageItem(percentage: 40, isManual: true),
        _TestPercentageItem(percentage: 25, isManual: false),
      ];
      MixPercentageCalculator.rebalance(items);

      expect(items[0].percentage, 70.0);
      expect(items[1].percentage, 40.0);
      expect(items[2].percentage, 0.0);
    });

    test('All manual items are preserved untouched', () {
      final items = [
        _TestPercentageItem(percentage: 60, isManual: true),
        _TestPercentageItem(percentage: 40, isManual: true),
      ];
      MixPercentageCalculator.rebalance(items);

      expect(items[0].percentage, 60.0);
      expect(items[1].percentage, 40.0);
    });

    test('Decimal remaining distributes with exact 100% sum', () {
      final items = [
        _TestPercentageItem(percentage: 33.5, isManual: true),
        _TestPercentageItem(percentage: 0, isManual: false),
        _TestPercentageItem(percentage: 0, isManual: false),
      ];
      MixPercentageCalculator.rebalance(items);

      expect(items[0].percentage, 33.5);
      expect(items[1].percentage, 33.3);
      expect(items[2].percentage, 33.2);
      expect(items.fold<double>(0, (a, b) => a + b.percentage), 100.0);
    });
  });
}
