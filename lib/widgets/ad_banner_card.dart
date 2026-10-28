import 'package:flutter/material.dart';
import 'ad_banner_widget.dart';

/// Tarjeta publicitaria que envuelve un banner de AdMob adaptándolo a la
/// estética visual de las tarjetas del catálogo de Hookahub.
class AdBannerCard extends StatelessWidget {
  const AdBannerCard({
    super.key,
    this.color,
    this.margin = const EdgeInsets.symmetric(vertical: 6.0),
  });

  final Color? color;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).primaryColor;

    return AdBannerWidget(
      builder: (context, adChild) => Container(
        margin: margin,
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 16,
                      color: accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Patrocinado',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ANUNCIO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: adChild,
            ),
          ],
        ),
      ),
    );
  }
}
