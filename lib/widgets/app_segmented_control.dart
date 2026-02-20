import 'package:flutter/material.dart';

/// Control segmentado reutilizable para toda la aplicación.
/// Mantiene un estilo consistente y permite personalización ligera.
///
/// Características:
/// - Soporta cualquier número de segmentos.
/// - Animación suave al cambiar de selección.
/// - Accesible (Semantics + labels).
/// - Parametrizable en radio, relleno y colores opcionales.
class AppSegmentedControl extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.currentIndex,
    required this.onChanged,
    this.backgroundColor,
    this.activeColor,
    this.inactiveTextColor,
    this.radius = 12,
    this.segmentRadius = 8,
    this.padding = const EdgeInsets.all(4),
    this.segmentPadding = const EdgeInsets.symmetric(vertical: 10),
    this.useFilledActive = false,
  }) : assert(segments.length > 0, 'Debe haber al menos un segmento');

  final List<String> segments;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final Color? backgroundColor;
  final Color? activeColor;
  final Color? inactiveTextColor;
  final double radius;
  final double segmentRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry segmentPadding;
  final bool
  useFilledActive; // Si true, estilo "pill" relleno (como tabaco detail)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = activeColor ?? theme.primaryColor;
    final bg = backgroundColor ?? theme.colorScheme.surface;
    final inactiveColor = inactiveTextColor ?? theme.textTheme.bodyLarge?.color;

    return Semantics(
      container: true,
      label: 'Selector',
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
        ),
        padding: padding,
        child: Row(
          children: [
            for (int i = 0; i < segments.length; i++)
              Expanded(
                child: _SegmentButton(
                  label: segments[i],
                  index: i,
                  selected: i == currentIndex,
                  onChanged: onChanged,
                  primary: primary,
                  inactiveColor: inactiveColor,
                  segmentRadius: segmentRadius,
                  padding: segmentPadding,
                  useFilledActive: useFilledActive,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.index,
    required this.selected,
    required this.onChanged,
    required this.primary,
    required this.inactiveColor,
    required this.segmentRadius,
    required this.padding,
    required this.useFilledActive,
  });

  final String label;
  final int index;
  final bool selected;
  final ValueChanged<int> onChanged;
  final Color primary;
  final Color? inactiveColor;
  final double segmentRadius;
  final EdgeInsetsGeometry padding;
  final bool useFilledActive;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final fillColor = useFilledActive
        ? (selected ? primary : Colors.transparent)
        : (selected ? primary.withOpacity(0.12) : Colors.transparent);
    final textColor = useFilledActive
        ? (selected ? Colors.white : inactiveColor)
        : (selected ? primary : inactiveColor);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () => onChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: padding,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(segmentRadius),
          ),
          child: Center(
            child: Text(
              label,
              style: style?.copyWith(
                color: textColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
