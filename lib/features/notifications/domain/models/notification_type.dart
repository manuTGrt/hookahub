/// Tipos de notificación soportados en el dominio de Hookahub.
///
/// Diseñado bajo el principio de compatibilidad hacia adelante (Forward-Compatible).
enum NotificationType {
  // Social & Mezclas
  reviewOnMyMix('review_on_my_mix'),
  favoriteMyMix('favorite_my_mix'),
  mixTrending('mix_trending'),
  followNewMix('follow_new_mix'),
  reviewReply('review_reply'),
  recommendedMix('recommended_mix'),

  // Catálogo
  newTobacco('new_tobacco'),

  // Gamificación & Engagement
  weeklyDigest('weekly_digest'),
  achievement('achievement'),

  // Soporte & Sistema
  generalAnnouncement('general_announcement'),
  feedbackResponse('feedback_response'),
  systemMaintenance('system_maintenance'),

  // Fallback seguro de dominio ante futuros tipos no contemplados
  unknown('unknown');

  const NotificationType(this.wireValue);

  /// Valor serializado en la columna `type` de Supabase.
  final String wireValue;

  /// Conversión defensiva desde cadena con fallback garantizado a [unknown].
  /// Cero riesgo de excepción por deserialización o casting.
  static NotificationType fromString(String? rawType) {
    if (rawType == null || rawType.trim().isEmpty) {
      return NotificationType.unknown;
    }

    final normalized = rawType.trim().toLowerCase();
    for (final type in NotificationType.values) {
      if (type.wireValue == normalized) {
        return type;
      }
    }
    return NotificationType.unknown;
  }

  /// Serialización segura a formato JSON / PostgREST
  String toJson() => wireValue;
}
