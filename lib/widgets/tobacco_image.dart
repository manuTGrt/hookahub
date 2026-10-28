import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Widget optimizado para mostrar imágenes de tabacos con:
/// - Caché inteligente de red
/// - Placeholder animado durante la carga
/// - Fallback a icono cuando no hay imagen
/// - Optimización de memoria con dimensiones específicas
class TobaccoImage extends StatelessWidget {
  const TobaccoImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = 12.0,
    this.placeholderColor,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? placeholderColor;
  final BoxFit fit;

  /// Tope máximo por defecto en píxeles físicos para evitar picos de RAM (OOM) en listas/grids.
  static const int maxDefaultCacheDimension = 512;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Si no hay URL, mostrar placeholder directamente
        if (imageUrl == null || imageUrl!.trim().isEmpty) {
          return _buildPlaceholder(context, constraints);
        }

        final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
        final cacheWidth = resolveCacheDimension(
          explicitSize: width,
          constraintSize: constraints.maxWidth,
          devicePixelRatio: dpr,
        );
        final cacheHeight = resolveCacheDimension(
          explicitSize: height,
          constraintSize: constraints.maxHeight,
          devicePixelRatio: dpr,
        );
        // IMPORTANTE: En Flutter (ResizeImage), pasar simultáneamente memCacheWidth y
        // memCacheHeight fuerza el bitmap decodificado a esas dimensiones exactas sin
        // respetar la relación de aspecto original (deformando/achatando la imagen antes
        // de que BoxFit.cover actúe). Al especificar únicamente memCacheWidth con el lado
        // mayor del contenedor, el codec preserva el aspect ratio original y BoxFit.cover
        // recorta limpiamente el excedente sin distorsión.
        final targetCacheWidth = math.max(cacheWidth, cacheHeight);

        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            width: width,
            height: height,
            fit: fit,
            alignment: Alignment.center,
            placeholder: (context, url) => _buildLoadingPlaceholder(context),
            errorWidget: (context, url, error) =>
                _buildPlaceholder(context, constraints),
            memCacheWidth: targetCacheWidth,
            fadeInDuration: const Duration(milliseconds: 300),
            fadeOutDuration: const Duration(milliseconds: 100),
          ),
        );
      },
    );
  }

  /// Placeholder cuando no hay imagen disponible
  Widget _buildPlaceholder(BuildContext context, BoxConstraints constraints) {
    final effectiveColor = placeholderColor ?? Theme.of(context).primaryColor;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          Icons.local_fire_department,
          size: _getIconSize(context, constraints),
          color: effectiveColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// Placeholder animado durante la carga
  Widget _buildLoadingPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).primaryColor.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  /// Calcula el tamaño del icono asegurando que sea finito y razonable
  double _getIconSize(BuildContext context, BoxConstraints constraints) {
    final effectiveHeight = (height != null && height!.isFinite && height! > 0)
        ? height!
        : (constraints.maxHeight.isFinite && constraints.maxHeight > 0
              ? constraints.maxHeight
              : null);
    if (effectiveHeight != null) {
      return (effectiveHeight * 0.4).clamp(24.0, 128.0).toDouble();
    }

    final effectiveWidth = (width != null && width!.isFinite && width! > 0)
        ? width!
        : (constraints.maxWidth.isFinite && constraints.maxWidth > 0
              ? constraints.maxWidth
              : null);
    if (effectiveWidth != null) {
      return (effectiveWidth * 0.4).clamp(24.0, 128.0).toDouble();
    }

    return (Theme.of(context).iconTheme.size ?? 48.0)
        .clamp(24.0, 128.0)
        .toDouble();
  }

  /// Calcula la dimensión física de decodificación en RAM para [CachedNetworkImage].
  /// Si [explicitSize] es `double.infinity` o `null`, utiliza [constraintSize] del [LayoutBuilder].
  @visibleForTesting
  static int resolveCacheDimension({
    required double? explicitSize,
    required double constraintSize,
    required double devicePixelRatio,
  }) {
    double? logicalSize;
    if (explicitSize != null && explicitSize.isFinite && explicitSize > 0) {
      logicalSize = explicitSize;
    } else if (constraintSize.isFinite && constraintSize > 0) {
      logicalSize = constraintSize;
    }

    if (logicalSize == null) {
      return maxDefaultCacheDimension;
    }

    final physicalPixels = (logicalSize * devicePixelRatio).round();
    return physicalPixels.clamp(64, maxDefaultCacheDimension);
  }
}
