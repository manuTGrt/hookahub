import 'package:flutter/material.dart';
import '../../../../core/constants.dart';

class RecentSearchesSection extends StatelessWidget {
  const RecentSearchesSection({
    super.key,
    required this.searches,
    required this.onSelect,
    required this.onRemove,
    required this.onClearAll,
  });

  final List<String> searches;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark ? darkNavy : navy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history, size: 18, color: headerColor),
                  const SizedBox(width: 8),
                  Text(
                    'BÚSQUEDAS RECIENTES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: headerColor,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onClearAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: isDark ? pastelPink : warningRed,
                ),
                child: const Text(
                  'Borrar todo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: searches.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            indent: 52,
            endIndent: 16,
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05),
          ),
          itemBuilder: (context, index) {
            final term = searches[index];
            return InkWell(
              onTap: () => onSelect(term),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 20,
                      color: isDark
                          ? darkNavy.withValues(alpha: 0.6)
                          : Colors.black45,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        term,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Eliminar de recientes',
                      color: isDark ? Colors.white38 : Colors.black38,
                      onPressed: () => onRemove(term),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
