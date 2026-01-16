import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/models/review.dart';

class TobaccoReviewsRepository {
  TobaccoReviewsRepository(this._supabase);

  final SupabaseClient _supabase;

  /// Fetch reviews for a specific tobacco
  Future<List<Review>> fetchReviews(String tobaccoId) async {
    final List<dynamic> response = await _supabase
        .from('tobacco_reviews')
        .select('*, profiles:author_id(username, display_name)')
        .eq('tobacco_id', tobaccoId)
        .order('created_at', ascending: false);

    return response.map((data) {
      final profile = data['profiles'] as Map<String, dynamic>?;
      final authorName = profile != null
          ? (profile['username'] ?? profile['display_name'] ?? 'Unknown')
          : 'Unknown';

      return Review(
        id: data['id'] as String,
        author: authorName as String,
        authorId: data['author_id'] as String?,
        rating: (data['rating'] as num).toDouble(),
        comment: data['comment'] as String? ?? '',
        createdAt: DateTime.parse(data['created_at'] as String),
      );
    }).toList();
  }

  /// Add a new review
  Future<void> addReview({
    required String tobaccoId,
    required String userId,
    required double rating,
    required String comment,
  }) async {
    await _supabase.from('tobacco_reviews').insert({
      'tobacco_id': tobaccoId,
      'author_id': userId,
      'rating': rating,
      'comment': comment,
    });
  }
}
