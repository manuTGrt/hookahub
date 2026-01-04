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
}
