import 'package:flutter/material.dart';
import '../../../../core/constants.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/models/notification_type.dart';

/// Datos de presentación formateados y listos para renderizar en la interfaz de usuario.
class NotificationUiModel {
  const NotificationUiModel({
    required this.title,
    required this.message,
    required this.categoryBadge,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
  });

  final String title;
  final String message;
  final String categoryBadge;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
}

/// Adaptador encargado de mapear la entidad de dominio a especificaciones visuales del Design System de Hookahub.
class NotificationPresentationAdapter {
  const NotificationPresentationAdapter._();

  /// Transforma una [AppNotification] en un [NotificationUiModel] reactivo al tema visual activo.
  static NotificationUiModel adapt(
    BuildContext context,
    AppNotification notification,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return switch (notification.type) {
      // 1. Soporte al usuario
      NotificationType.feedbackResponse => NotificationUiModel(
          title: notification.title,
          message: notification.message,
          categoryBadge: 'SOPORTE',
          icon: Icons.support_agent_rounded,
          accentColor: isDark ? darkTurquoise : turquoiseDark,
          backgroundColor: isDark ? fieldDark : fieldLight,
        ),

      // 2. Comunicado oficial / Anuncio general
      NotificationType.generalAnnouncement => NotificationUiModel(
          title: notification.title,
          message: notification.message,
          categoryBadge: 'ANUNCIO',
          icon: Icons.campaign_rounded,
          accentColor: const Color(0xFFE5A93C), // Ámbar dorado Hookahub
          backgroundColor: isDark ? fieldDark : const Color(0xFFFFF9E6),
        ),

      // 3. Mantenimiento del sistema
      NotificationType.systemMaintenance => NotificationUiModel(
          title: notification.title,
          message: notification.message,
          categoryBadge: 'SISTEMA',
          icon: Icons.build_circle_rounded,
          accentColor: warningRed,
          backgroundColor:
              isDark ? warningSurfaceDark : warningSurfaceLight,
        ),

      // 4. Catálogo: Nuevo tabaco
      NotificationType.newTobacco => NotificationUiModel(
          title: notification.title,
          message: notification.message,
          categoryBadge: 'CATÁLOGO',
          icon: Icons.inventory_2_rounded,
          accentColor: const Color(0xFF4CAF50),
          backgroundColor: isDark ? fieldDark : const Color(0xFFE8F5E9),
        ),

      // 5. Interacciones sociales de mezclas
      NotificationType.reviewOnMyMix => NotificationUiModel(
          title: notification.title,
          message: notification.message,
          categoryBadge: 'MEZCLA',
          icon: Icons.rate_review_rounded,
          accentColor: const Color(0xFF29B6F6),
          backgroundColor: isDark ? fieldDark : const Color(0xFFE1F5FE),
        ),

      NotificationType.favoriteMyMix => NotificationUiModel(
          title: notification.title,
          message: notification.message,
          categoryBadge: 'FAVORITO',
          icon: Icons.favorite_rounded,
          accentColor: const Color(0xFFEC407A),
          backgroundColor: isDark ? fieldDark : const Color(0xFFFCE4EC),
        ),

      NotificationType.mixTrending => NotificationUiModel(
          title: notification.title,
          message: notification.message,
          categoryBadge: 'TENDENCIA',
          icon: Icons.local_fire_department_rounded,
          accentColor: const Color(0xFFFF7043),
          backgroundColor: isDark ? fieldDark : const Color(0xFFFBE9E7),
        ),

      NotificationType.followNewMix => NotificationUiModel(
          title: notification.title,
          message: notification.message,
          categoryBadge: 'COMUNIDAD',
          icon: Icons.person_add_alt_1_rounded,
          accentColor: const Color(0xFFAB47BC),
          backgroundColor: isDark ? fieldDark : const Color(0xFFF3E5F5),
        ),

      NotificationType.reviewReply => NotificationUiModel(
          title: notification.title,
          message: notification.message,
          categoryBadge: 'RESPUESTA',
          icon: Icons.reply_rounded,
          accentColor: isDark ? darkTurquoise : turquoiseDark,
          backgroundColor: isDark ? fieldDark : fieldLight,
        ),

      NotificationType.weeklyDigest => NotificationUiModel(
          title: notification.title,
          message: notification.message,
          categoryBadge: 'RESUMEN',
          icon: Icons.auto_awesome_rounded,
          accentColor: const Color(0xFF5C6BC0),
          backgroundColor: isDark ? fieldDark : const Color(0xFFEDE7F6),
        ),

      NotificationType.achievement => NotificationUiModel(
          title: notification.title,
          message: notification.message,
          categoryBadge: 'LOGRO',
          icon: Icons.emoji_events_rounded,
          accentColor: const Color(0xFFFFB300),
          backgroundColor: isDark ? fieldDark : const Color(0xFFFFF8E1),
        ),

      NotificationType.recommendedMix => NotificationUiModel(
          title: notification.title,
          message: notification.message,
          categoryBadge: 'SUGERENCIA',
          icon: Icons.explore_rounded,
          accentColor: const Color(0xFF26A69A),
          backgroundColor: isDark ? fieldDark : const Color(0xFFE0F2F1),
        ),

      // Fallback seguro ante tipos futuros no contemplados
      NotificationType.unknown => NotificationUiModel(
          title: notification.title,
          message: notification.message,
          categoryBadge: 'AVISO',
          icon: Icons.notifications_active_outlined,
          accentColor: isDark ? darkNavy : navy,
          backgroundColor: isDark ? fieldDark : fieldLight,
        ),
    };
  }
}
