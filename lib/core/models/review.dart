/// Modelo de Reseña
class Review {
  final String id;
  final String author;
  final String? authorId; // ID del autor para verificar permisos
  final double rating; // 0..5
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.author,
    this.authorId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Review copyWith({
    String? id,
    String? author,
    String? authorId,
    double? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return Review(
      id: id ?? this.id,
      author: author ?? this.author,
      authorId: authorId ?? this.authorId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
