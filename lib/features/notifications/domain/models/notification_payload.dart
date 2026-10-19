/// Value Object inmutable que normaliza de forma segura el JSONB `data`.
class NotificationPayload {
  const NotificationPayload({
    this.title,
    this.message,
    this.mixId,
    this.mixName,
    this.tobaccoId,
    this.tobaccoName,
    this.tobaccoBrand,
    this.feedbackId,
    this.status,
    this.reviewerName,
    this.favoriterName,
    this.authorName,
    this.replierName,
    this.achievementName,
    this.rating,
    this.raw = const {},
  });

  final String? title;
  final String? message;
  final String? mixId;
  final String? mixName;
  final String? tobaccoId;
  final String? tobaccoName;
  final String? tobaccoBrand;
  final String? feedbackId;
  final String? status;
  final String? reviewerName;
  final String? favoriterName;
  final String? authorName;
  final String? replierName;
  final String? achievementName;
  final double? rating;

  /// Mapa original sin modificar para acceso a campos adicionales no modelados.
  final Map<String, dynamic> raw;

  /// Constructor factoría defensivo con tolerancia a variaciones en nombres de claves.
  factory NotificationPayload.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const NotificationPayload();
    }

    // Extracción tolerante de títulos (aliases comunes en bases de datos y paneles admin)
    final resolvedTitle = json['title'] as String? ??
        json['subject'] as String? ??
        json['heading'] as String?;

    // Extracción tolerante de cuerpos de mensaje
    final resolvedMessage = json['message'] as String? ??
        json['body'] as String? ??
        json['content'] as String? ??
        json['description'] as String?;

    return NotificationPayload(
      title: resolvedTitle?.trim(),
      message: resolvedMessage?.trim(),
      mixId: json['mix_id']?.toString(),
      mixName: json['mix_name'] as String?,
      tobaccoId: json['tobacco_id']?.toString(),
      tobaccoName: json['tobacco_name'] as String?,
      tobaccoBrand: json['tobacco_brand'] as String?,
      feedbackId: json['feedback_id']?.toString(),
      status: json['status'] as String?,
      reviewerName: json['reviewer_name'] as String?,
      favoriterName: json['favoriter_name'] as String?,
      authorName: json['author_name'] as String?,
      replierName: json['replier_name'] as String?,
      achievementName: json['achievement_name'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      raw: Map<String, dynamic>.unmodifiable(json),
    );
  }
}
