import 'package:flutter/material.dart';

/// Modelo de dominio para una notificación
class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  /// Factory desde JSON de Supabase
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: NotificationTypeExtension.fromString(json['type'] as String),
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Título de la notificación según el tipo
  String get title {
    switch (type) {
      case NotificationType.reviewOnMyMix:
        return 'Nueva reseña';
      case NotificationType.newTobacco:
        return 'Nuevo tabaco';
      case NotificationType.mixTrending:
        return '🔥 Mezcla trending';
      case NotificationType.favoriteMyMix:
        return 'Nuevo favorito';
      case NotificationType.followNewMix:
        return 'Nueva mezcla';
      case NotificationType.reviewReply:
        return 'Respuesta a tu reseña';
      case NotificationType.weeklyDigest:
        return 'Resumen semanal';
      case NotificationType.achievement:
        return '🏆 Logro desbloqueado';
      case NotificationType.recommendedMix:
        return 'Recomendación para ti';
    }
  }

  /// Mensaje de la notificación según el tipo
  String get message {
    switch (type) {
      case NotificationType.reviewOnMyMix:
        final reviewerName = data['reviewer_name'] as String? ?? 'Alguien';
        final mixName = data['mix_name'] as String? ?? 'tu mezcla';
        return '$reviewerName comentó en "$mixName"';
        
      case NotificationType.newTobacco:
        final tobaccoName = data['tobacco_name'] as String? ?? 'Un nuevo tabaco';
        final brand = data['tobacco_brand'] as String? ?? '';
        return '$tobaccoName $brand se agregó al catálogo';
        
      case NotificationType.mixTrending:
        final mixName = data['mix_name'] as String? ?? 'Tu mezcla';
        final rating = (data['rating'] as num?)?.toStringAsFixed(1) ?? '5.0';
        return '$mixName está siendo muy bien valorada ($rating⭐)';
        
      case NotificationType.favoriteMyMix:
        final favoriterName = data['favoriter_name'] as String? ?? 'Alguien';
        final mixName = data['mix_name'] as String? ?? 'tu mezcla';
        return '$favoriterName marcó "$mixName" como favorita';
        
      case NotificationType.followNewMix:
        final authorName = data['author_name'] as String? ?? 'Un usuario';
        final mixName = data['mix_name'] as String? ?? '';
        return '$authorName creó una nueva mezcla: $mixName';
        
      case NotificationType.reviewReply:
        final replierName = data['replier_name'] as String? ?? 'Alguien';
        return '$replierName respondió a tu reseña';
        
      case NotificationType.weeklyDigest:
        return 'Revisa tu actividad de esta semana';
        
      case NotificationType.achievement:
        final achievementName = data['achievement_name'] as String? ?? 'Nuevo logro';
        return 'Has desbloqueado: $achievementName';
        
      case NotificationType.recommendedMix:
        final mixName = data['mix_name'] as String? ?? 'Una mezcla';
        return 'Creemos que te gustará: $mixName';
    }
  }

  /// Icono para el tipo de notificación
  IconData get icon {
    switch (type) {
      case NotificationType.reviewOnMyMix:
        return Icons.rate_review;
      case NotificationType.newTobacco:
        return Icons.inventory_2;
      case NotificationType.mixTrending:
        return Icons.trending_up;
      case NotificationType.favoriteMyMix:
        return Icons.favorite;
      case NotificationType.followNewMix:
        return Icons.person_add;
      case NotificationType.reviewReply:
        return Icons.reply;
      case NotificationType.weeklyDigest:
        return Icons.calendar_today;
      case NotificationType.achievement:
        return Icons.emoji_events;
      case NotificationType.recommendedMix:
        return Icons.lightbulb;
    }
  }

  /// Color del icono
  Color get color {
    switch (type) {
      case NotificationType.reviewOnMyMix:
        return Colors.blue;
      case NotificationType.newTobacco:
        return Colors.green;
      case NotificationType.mixTrending:
        return Colors.orange;
      case NotificationType.favoriteMyMix:
        return Colors.red;
      case NotificationType.followNewMix:
        return Colors.purple;
      case NotificationType.reviewReply:
        return Colors.teal;
      case NotificationType.weeklyDigest:
        return Colors.indigo;
      case NotificationType.achievement:
        return Colors.amber;
      case NotificationType.recommendedMix:
        return Colors.cyan;
    }
  }

  /// Copia con cambios
  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Enum para tipos de notificaciones
enum NotificationType {
  reviewOnMyMix,
  newTobacco,
  mixTrending,
  favoriteMyMix,
  followNewMix,
  reviewReply,
  weeklyDigest,
  achievement,
  recommendedMix,
}

/// Extension para convertir string a enum
extension NotificationTypeExtension on NotificationType {
  static NotificationType fromString(String type) {
    switch (type) {
      case 'review_on_my_mix':
        return NotificationType.reviewOnMyMix;
      case 'new_tobacco':
        return NotificationType.newTobacco;
      case 'mix_trending':
        return NotificationType.mixTrending;
      case 'favorite_my_mix':
        return NotificationType.favoriteMyMix;
      case 'follow_new_mix':
        return NotificationType.followNewMix;
      case 'review_reply':
        return NotificationType.reviewReply;
      case 'weekly_digest':
        return NotificationType.weeklyDigest;
      case 'achievement':
        return NotificationType.achievement;
      case 'recommended_mix':
        return NotificationType.recommendedMix;
      default:
        return NotificationType.reviewOnMyMix; // fallback
    }
  }

  String toJson() {
    switch (this) {
      case NotificationType.reviewOnMyMix:
        return 'review_on_my_mix';
      case NotificationType.newTobacco:
        return 'new_tobacco';
      case NotificationType.mixTrending:
        return 'mix_trending';
      case NotificationType.favoriteMyMix:
        return 'favorite_my_mix';
      case NotificationType.followNewMix:
        return 'follow_new_mix';
      case NotificationType.reviewReply:
        return 'review_reply';
      case NotificationType.weeklyDigest:
        return 'weekly_digest';
      case NotificationType.achievement:
        return 'achievement';
      case NotificationType.recommendedMix:
        return 'recommended_mix';
    }
  }
}
