import 'package:flutter/material.dart';
import '../../../../core/constants.dart';

/// Widget para resaltar visualmente los caracteres coincidentes de una búsqueda
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    this.maxLines = 1,
  });

  final String text;
  final String query;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty || !text.toLowerCase().contains(cleanQuery)) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlightColor = isDark ? darkTurquoise : turquoiseDark;
    final spans = <TextSpan>[];

    final lowerText = text.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(cleanQuery, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: style));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + cleanQuery.length),
          style: style.copyWith(
            color: highlightColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

      start = index + cleanQuery.length;
    }

    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }
}
