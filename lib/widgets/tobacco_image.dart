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

  @override
  Widget build(BuildContext context) {
    // Si no hay URL, mostrar placeholder directamente
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return _buildPlaceholder(context);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildLoadingPlaceholder(context),
        errorWidget: (context, url, error) => _buildPlaceholder(context),
        // Optimización de memoria: limitar dimensiones en caché
        memCacheWidth: _getValidCacheWidth(),
        memCacheHeight: _getValidCacheHeight(),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 100),
      ),
    );
  }

  /// Placeholder cuando no hay imagen disponible
  Widget _buildPlaceholder(BuildContext context) {
    final effectiveColor = placeholderColor ?? Theme.of(context).primaryColor;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          Icons.local_fire_department,
          size: _getIconSize(context),
          color: effectiveColor.withOpacity(0.5),
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
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).primaryColor.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  /// Calcula el tamaño del icono asegurando que sea finito y razonable
  double _getIconSize(BuildContext context) {
    // Prioriza altura si es válida
    if (height != null && height!.isFinite && height! > 0) {
      final size = height! * 0.4; // 40% de la altura
      return size.clamp(24.0, 128.0).toDouble();
    }
    // Si la altura no es válida, usa ancho si es válido
    if (width != null && width!.isFinite && width! > 0) {
      final size = width! * 0.4; // 40% del ancho
      return size.clamp(24.0, 128.0).toDouble();
    }
    // Fallback: usa el tamaño del tema si existe, o 48
    return (Theme.of(context).iconTheme.size ?? 48.0).clamp(24.0, 128.0).toDouble();
  }

  /// Obtiene el ancho válido del caché, con validación para evitar NaN/Infinity
  int? _getValidCacheWidth() {
    // Si width es infinity o no es un número finito, no especificamos memCacheWidth
    if (width == null || !width!.isFinite || width! <= 0) {
      return null;
    }
    return (width! * 2).toInt().clamp(0, 2000);
  }

  /// Obtiene el alto válido del caché, con validación para evitar NaN/Infinity
  int? _getValidCacheHeight() {
    // Si height es infinity o no es un número finito, no especificamos memCacheHeight
    if (height == null || !height!.isFinite || height! <= 0) {
      return null;
    }
    return (height! * 2).toInt().clamp(0, 2000);
  }
}
