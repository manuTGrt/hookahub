import 'package:flutter/material.dart';
import 'tobacco_image.dart';

/// Tarjeta de tabaco reutilizable con aspecto similar a MixCard, pero
/// mostrando lista de sabores en lugar de ingredientes de mezcla.
class TobaccoCard extends StatelessWidget {
  const TobaccoCard({
    super.key,
    required this.name,
    required this.brand,
    this.flavors,
    this.description,
    this.color,
    this.rating = 0.0,
    this.reviews = 0,
    this.onTap,
    this.trailing,
  });

  final String name;
  final String brand;
  final List<String>? flavors;
  final String? description;
  final Color? color;
  final double rating;
  final int reviews;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    String _toTitleCase(String input) {
      if (input.trim().isEmpty) return input.trim();
      return input.trim().substring(0, 1).toUpperCase() + 
             input.trim().substring(1).toLowerCase();
    }

    String _toTitleCaseSpaces(String input) {
      if (input.trim().isEmpty) return input.trim();
      final buffer = StringBuffer();
      bool capitalizeNext = true;
      for (var i = 0; i < input.length; i++) {
        final ch = input[i];
        final isWhitespace = ch.trim().isEmpty;
        if (isWhitespace) {
          buffer.write(ch);
          capitalizeNext = true;
        } else {
          buffer.write(capitalizeNext ? ch.toUpperCase() : ch.toLowerCase());
          capitalizeNext = false;
        }
      }
      return buffer.toString();
    }
    // Si no se proporciona color, usar el color primario del tema para que
    // todas las tarjetas de tabacos se vean iguales entre sí.
    final accent = color ?? Theme.of(context).primaryColor;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: accent,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _toTitleCase(name),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _toTitleCase(brand),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            if (description != null && description!.trim().isNotEmpty) ...[
              Text(
                'Descripción:',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.8),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _toTitleCase(description!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (flavors != null && flavors!.isNotEmpty) ...[
              Text(
                'Sabores:',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.8),
                    ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: flavors!
                    .map(
                      (f) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _toTitleCaseSpaces(f),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            // Fila de rating alineada con MixCard
            Row(
              children: () {
                final hasRating = (reviews > 0) && (rating > 0);
                if (hasRating) {
                  return [
                    Icon(Icons.star, size: 16, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        reviews == 1 ? '(1 reseña)' : '($reviews reseñas)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                            ),
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                  ];
                } else {
                  return [
                    Icon(Icons.star_border, size: 16, color: accent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Sin valoraciones',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                            ),
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                  ];
                }
              }(),
            ),
          ],
        ),
      ),
    );
  }
}
