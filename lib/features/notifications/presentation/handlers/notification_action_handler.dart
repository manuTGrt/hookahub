import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants.dart';
import '../../../../core/models/mix.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../catalog/presentation/providers/catalog_provider.dart';
import '../../../catalog/presentation/tobacco_detail_page.dart';
import '../../../community/presentation/mix_detail_page.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/models/notification_type.dart';
import '../notifications_provider.dart';
import '../widgets/notification_detail_sheet.dart';

/// Orquestador central de interacciones sobre notificaciones.
///
/// Desacopla la lógica de navegación (GoRouter/Navigator) y modales de los widgets de celda.
class NotificationActionHandler {
  const NotificationActionHandler._();

  /// Procesa la pulsación de una notificación de manera atómica y segura.
  static Future<void> handleTap(
    BuildContext context,
    AppNotification notification,
  ) async {
    // 1. Marca como leída de forma optimista
    if (!notification.isRead) {
      context.read<NotificationsProvider>().markAsRead(notification.id);
    }

    final payload = notification.payload;

    // 2. Despacho condicional según el tipo de notificación y datos presentes
    switch (notification.type) {
      // Navegación hacia Mezclas
      case NotificationType.reviewOnMyMix:
      case NotificationType.favoriteMyMix:
      case NotificationType.mixTrending:
      case NotificationType.followNewMix:
      case NotificationType.reviewReply:
      case NotificationType.recommendedMix:
        if (payload.mixId != null && payload.mixId!.isNotEmpty) {
          final mix = Mix(
            id: payload.mixId!,
            name: payload.mixName ?? 'Mezcla',
            author: 'Cargando...',
            rating: payload.rating ?? 0.0,
            reviews: 0,
            ingredients: [],
            color: turquoise,
          );

          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MixDetailPage(mix: mix)),
          );
          return;
        }

        // Si la notificación no trae ID de mezcla válido, abrimos el modal de detalle
        if (context.mounted) {
          await NotificationDetailSheet.show(context, notification);
        }

      // Navegación hacia Tabacos en el Catálogo
      case NotificationType.newTobacco:
        if (payload.tobaccoId != null && payload.tobaccoId!.isNotEmpty) {
          final tobacco = await context
              .read<CatalogProvider>()
              .getTobaccoById(payload.tobaccoId!);

          if (!context.mounted) return;

          if (tobacco != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TobaccoDetailPage(tobacco: tobacco),
              ),
            );
          } else {
            AppToast.showInfo(
              context,
              'El tabaco ya no se encuentra disponible',
            );
          }
          return;
        }

        if (context.mounted) {
          await NotificationDetailSheet.show(context, notification);
        }

      // Soporte, Anuncios, Mantenimiento, Resúmenes, Logros y tipos desconocidos
      case NotificationType.generalAnnouncement:
      case NotificationType.feedbackResponse:
      case NotificationType.systemMaintenance:
      case NotificationType.weeklyDigest:
      case NotificationType.achievement:
      case NotificationType.unknown:
        // Si de forma secundaria incluye tobacco_id o mix_id, priorizamos la navegación si existe
        if (payload.tobaccoId != null && payload.tobaccoId!.isNotEmpty) {
          final tobacco = await context
              .read<CatalogProvider>()
              .getTobaccoById(payload.tobaccoId!);
          if (context.mounted && tobacco != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TobaccoDetailPage(tobacco: tobacco),
              ),
            );
            return;
          }
        }

        if (context.mounted) {
          await NotificationDetailSheet.show(context, notification);
        }
    }
  }
}
