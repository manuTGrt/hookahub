/// Contrato para elementos que participan en el cálculo y balanceo de porcentajes de una mezcla.
abstract class MixPercentageItem {
  bool get isManual;
  set isManual(bool value);
  double get percentage;
  set percentage(double value);
}

/// Servicio de dominio para el balanceo y cálculo equitativo de porcentajes en mezclas.
class MixPercentageCalculator {
  const MixPercentageCalculator._();

  /// Recalcula los porcentajes de la lista de [items] de modo que la suma total sea exactamente 100%.
  ///
  /// Reglas de negocio:
  /// 1. Si un item tiene [isManual] == true, su porcentaje NO se recalcula.
  /// 2. El remanente (100% - suma de manuales) se reparte equitativamente entre los items automáticos.
  /// 3. Si no hay items automáticos, no se efectúa ningún cambio.
  /// 4. Si el remanente es <= 0, los automáticos reciben 0.0 para reflejar el exceso de asignación manual.
  /// 5. El reparto entre automáticos garantiza una suma exacta de 100.0 (distribución de resto entero).
  static void rebalance(List<MixPercentageItem> items) {
    if (items.isEmpty) return;

    final manualItems = items.where((i) => i.isManual).toList();
    final autoItems = items.where((i) => !i.isManual).toList();

    if (autoItems.isEmpty) return;

    final manualSum = manualItems.fold<double>(
      0.0,
      (sum, item) => sum + item.percentage,
    );

    final remaining = 100.0 - manualSum;

    if (remaining <= 0) {
      for (final item in autoItems) {
        item.percentage = 0.0;
      }
      return;
    }

    final autoCount = autoItems.length;

    // Si remaining es prácticamente entero o exacto, usamos reparto entero con residuo
    final isVirtuallyInteger = (remaining - remaining.round()).abs() < 0.001;

    if (isVirtuallyInteger) {
      final totalInt = remaining.round();
      final base = totalInt ~/ autoCount;
      final remainder = totalInt % autoCount;

      for (int i = 0; i < autoCount; i++) {
        final extra = i < remainder ? 1 : 0;
        autoItems[i].percentage = (base + extra).toDouble();
      }
    } else {
      // Si el remanente contiene decimales introducidos por el usuario
      final portion = double.parse((remaining / autoCount).toStringAsFixed(1));
      double accumulated = 0.0;
      for (int i = 0; i < autoCount - 1; i++) {
        autoItems[i].percentage = portion;
        accumulated += portion;
      }
      final lastPortion = double.parse(
        (remaining - accumulated).toStringAsFixed(1),
      );
      autoItems.last.percentage = lastPortion;
    }
  }
}
