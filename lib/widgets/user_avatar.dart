import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/data/supabase_service.dart';
import '../core/storage.dart';

/// Widget reutilizable para mostrar el avatar de un usuario con soporte para:
/// - Foto de perfil (almacenada en Storage o URL web directa) con caché y límites de memoria
/// - Iconos predefinidos (`icon:<index>`)
/// - Fallback elegante a la inicial del nombre de usuario si no hay avatar o falla la red
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.username,
    this.avatarUrl,
    this.radius = 20.0,
    this.backgroundColor,
    this.foregroundColor = Colors.white,
    this.fontSize,
  });

  /// Nombre de usuario del que se extrae la inicial en caso de fallback
  final String username;

  /// URL, ruta en Storage o identificador del tipo `'icon:<index>'`
  final String? avatarUrl;

  /// Radio del círculo
  final double radius;

  /// Color de fondo del círculo
  final Color? backgroundColor;

  /// Color del icono o texto
  final Color foregroundColor;

  /// Tamaño de fuente para la inicial (opcional)
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final effectiveBgColor = backgroundColor ?? Theme.of(context).primaryColor;
    final size = radius * 2;

    // Caso 1: Sin avatar especificado -> Mostrar inicial
    if (avatarUrl == null || avatarUrl!.trim().isEmpty) {
      return _buildInitialCircle(effectiveBgColor);
    }

    final trimmed = avatarUrl!.trim();

    // Caso 2: Avatar de icono predefinido ('icon:<index>')
    if (trimmed.startsWith('icon:')) {
      final index = int.tryParse(trimmed.substring(5));
      if (index != null && index >= 0 && index < appAvatarIcons.length) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: effectiveBgColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              appAvatarIcons[index],
              size: radius * 1.1,
              color: foregroundColor,
            ),
          ),
        );
      }
      return _buildInitialCircle(effectiveBgColor);
    }

    // Caso 3: Foto (Storage path o URL HTTP/HTTPS)
    final String resolvedUrl =
        (trimmed.startsWith('http://') || trimmed.startsWith('https://'))
            ? trimmed
            : SupabaseService()
                .client
                .storage
                .from(StorageConfig.avatarsBucket)
                .getPublicUrl(trimmed);

    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final cacheDimension = (size * pixelRatio).round();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: resolvedUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: cacheDimension > 0 ? cacheDimension : 120,
          memCacheHeight: cacheDimension > 0 ? cacheDimension : 120,
          fadeInDuration: const Duration(milliseconds: 200),
          fadeOutDuration: const Duration(milliseconds: 100),
          placeholder: (context, url) => _buildInitialContent(),
          errorWidget: (context, url, error) => _buildInitialContent(),
        ),
      ),
    );
  }

  Widget _buildInitialCircle(Color bgColor) {
    final size = radius * 2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: _buildInitialContent(),
    );
  }

  Widget _buildInitialContent() {
    final initial =
        username.trim().isNotEmpty ? username.trim()[0].toUpperCase() : '?';
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.bold,
          fontSize: fontSize ?? (radius * 0.9),
        ),
      ),
    );
  }
}
