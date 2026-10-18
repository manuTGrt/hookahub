import 'package:flutter/material.dart';
import '../../../../core/constants.dart';
import '../../domain/models/search_suggestion.dart';
import 'highlighted_text.dart';

class SuggestionTile extends StatelessWidget {
  const SuggestionTile({
    super.key,
    required this.suggestion,
    required this.query,
    required this.onTap,
    required this.onFillQuery,
  });

  final SearchSuggestion suggestion;
  final String query;
  final VoidCallback onTap;
  final VoidCallback onFillQuery;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTobacco = suggestion.isTobacco;
    final scaleFactor = MediaQuery.textScalerOf(context).scale(1.0);

    final iconColor = isTobacco
        ? (isDark ? turquoise : turquoiseDark)
        : (isDark ? pastelPurple : Colors.deepPurpleAccent);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Icono distintivo según tipo
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: iconColor.withValues(alpha: 0.3)),
              ),
              child: Icon(
                isTobacco ? Icons.local_fire_department : Icons.blender_outlined,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Título resaltado y subtítulo categorizado
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HighlightedText(
                    text: suggestion.title,
                    query: query,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        isTobacco ? 'Tabaco • ' : 'Mezcla • ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: iconColor,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          suggestion.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? darkNavy.withValues(alpha: 0.7)
                                : Colors.black54,
                          ),
                        ),
                      ),
                      if (suggestion.rating > 0 && scaleFactor < 1.3) ...[
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          suggestion.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Botón para autocompletar término en el input
            IconButton(
              icon: Icon(
                Icons.north_west,
                size: 18,
                color: isDark ? darkNavy.withValues(alpha: 0.6) : Colors.black38,
              ),
              tooltip: 'Rellenar búsqueda',
              onPressed: onFillQuery,
            ),
          ],
        ),
      ),
    );
  }
}
