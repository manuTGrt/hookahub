import 'package:flutter/material.dart';
import '../../features/notifications/domain/entities/app_notification.dart';
import '../../features/notifications/domain/models/notification_type.dart';

// Re-exportamos los componentes de dominio limpio de la feature
export '../../features/notifications/domain/entities/app_notification.dart';
export '../../features/notifications/domain/models/notification_payload.dart';
export '../../features/notifications/domain/models/notification_type.dart';

/// Extensiones de compatibilidad hacia atrás para código legado
extension LegacyAppNotificationUiExtension on AppNotification {
  @Deprecated('Utiliza NotificationPresentationAdapter para desacoplar UI de la entidad')
  IconData get icon {
    return switch (type) {
      NotificationType.reviewOnMyMix => Icons.rate_review,
      NotificationType.newTobacco => Icons.inventory_2,
      NotificationType.mixTrending => Icons.trending_up,
      NotificationType.favoriteMyMix => Icons.favorite,
      NotificationType.followNewMix => Icons.person_add,
      NotificationType.reviewReply => Icons.reply,
      NotificationType.weeklyDigest => Icons.calendar_today,
      NotificationType.achievement => Icons.emoji_events,
      NotificationType.recommendedMix => Icons.lightbulb,
      NotificationType.generalAnnouncement => Icons.campaign,
      NotificationType.feedbackResponse => Icons.support_agent,
      NotificationType.systemMaintenance => Icons.build_circle,
      NotificationType.unknown => Icons.notifications,
    };
  }

  @Deprecated('Utiliza NotificationPresentationAdapter para aplicar el Design System')
  Color get color {
    return switch (type) {
      NotificationType.reviewOnMyMix => Colors.blue,
      NotificationType.newTobacco => Colors.green,
      NotificationType.mixTrending => Colors.orange,
      NotificationType.favoriteMyMix => Colors.red,
      NotificationType.followNewMix => Colors.purple,
      NotificationType.reviewReply => Colors.teal,
      NotificationType.weeklyDigest => Colors.indigo,
      NotificationType.achievement => Colors.amber,
      NotificationType.recommendedMix => Colors.cyan,
      NotificationType.generalAnnouncement => const Color(0xFFE5A93C),
      NotificationType.feedbackResponse => const Color(0xFF3A9B94),
      NotificationType.systemMaintenance => const Color(0xFFD84343),
      NotificationType.unknown => Colors.grey,
    };
  }
}

/// Extension de compatibilidad para código legado que invoque NotificationTypeExtension
extension NotificationTypeExtension on NotificationType {
  static NotificationType fromString(String type) =>
      NotificationType.fromString(type);
}
