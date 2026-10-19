import '../models/notification_payload.dart';
import '../models/notification_type.dart';

/// Entidad pura de dominio para notificaciones de usuario (Clean Architecture).
///
/// Completamente desacoplada del framework de presentación de Flutter.
class AppNotification {
  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    NotificationPayload? payload,
    Map<String, dynamic>? data,
    required this.isRead,
    required this.createdAt,
  }) : payload = payload ?? NotificationPayload.fromJson(data);

  final String id;
  final String userId;
  final NotificationType type;
  final NotificationPayload payload;
  final bool isRead;
  final DateTime createdAt;

  /// Getter backward-compatible para código existente que aún acceda al mapa crudo.
  Map<String, dynamic> get data => payload.raw;

  /// Título resuelto dinámicamente: prioriza el payload (`data`) y ofrece fallback semántico.
  String get title {
    if (payload.title != null && payload.title!.isNotEmpty) {
      return payload.title!;
    }

    return switch (type) {
      NotificationType.reviewOnMyMix => 'Nueva reseña',
      NotificationType.newTobacco => 'Nuevo tabaco',
      NotificationType.mixTrending => '🔥 Mezcla trending',
      NotificationType.favoriteMyMix => 'Nuevo favorito',
      NotificationType.followNewMix => 'Nueva mezcla',
      NotificationType.reviewReply => 'Respuesta a tu reseña',
      NotificationType.weeklyDigest => 'Resumen semanal',
      NotificationType.achievement => '🏆 Logro desbloqueado',
      NotificationType.recommendedMix => 'Recomendación para ti',
      NotificationType.generalAnnouncement => 'Comunicado de la Comunidad',
      NotificationType.feedbackResponse => 'Respuesta del equipo de soporte',
      NotificationType.systemMaintenance => 'Mantenimiento del sistema',
      NotificationType.unknown => 'Aviso de Hookahub',
    };
  }

  /// Mensaje resuelto dinámicamente: prioriza el cuerpo del payload y ofrece fallback semántico.
  String get message {
    if (payload.message != null && payload.message!.isNotEmpty) {
      return payload.message!;
    }

    return switch (type) {
      NotificationType.reviewOnMyMix =>
        '${payload.reviewerName ?? 'Alguien'} comentó en "${payload.mixName ?? 'tu mezcla'}"',
      NotificationType.newTobacco =>
        '${payload.tobaccoName ?? 'Un nuevo tabaco'} ${payload.tobaccoBrand ?? ''} se agregó al catálogo'.trim(),
      NotificationType.mixTrending =>
        '${payload.mixName ?? 'Tu mezcla'} está siendo muy bien valorada (${(payload.rating ?? 5.0).toStringAsFixed(1)}⭐)',
      NotificationType.favoriteMyMix =>
        '${payload.favoriterName ?? 'Alguien'} marcó "${payload.mixName ?? 'tu mezcla'}" como favorita',
      NotificationType.followNewMix =>
        '${payload.authorName ?? 'Un usuario'} creó una nueva mezcla: ${payload.mixName ?? ''}'.trim(),
      NotificationType.reviewReply =>
        '${payload.replierName ?? 'Alguien'} respondió a tu reseña',
      NotificationType.weeklyDigest =>
        'Revisa tu actividad de esta semana',
      NotificationType.achievement =>
        'Has desbloqueado: ${payload.achievementName ?? 'Nuevo logro'}',
      NotificationType.recommendedMix =>
        'Creemos que te gustará: ${payload.mixName ?? 'Una mezcla'}',
      NotificationType.generalAnnouncement =>
        'Tienes un nuevo comunicado oficial en Hookahub',
      NotificationType.feedbackResponse =>
        'Hemos respondido a tu solicitud de soporte',
      NotificationType.systemMaintenance =>
        'Trabajos programados de mantenimiento en el sistema',
      NotificationType.unknown =>
        'Has recibido una notificación informativa',
    };
  }

  /// Factory defensivo que valida tipos y previene excepciones en tiempo de ejecución.
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      type: NotificationType.fromString(json['type'] as String?),
      payload: NotificationPayload.fromJson(
        json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : null,
      ),
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
    );
  }

  /// Genera una copia inmutable con valores actualizados.
  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    NotificationPayload? payload,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      payload: payload ?? (data != null ? NotificationPayload.fromJson(data) : this.payload),
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
