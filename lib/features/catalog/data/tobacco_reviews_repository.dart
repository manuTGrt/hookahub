import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants.dart';
import '../../../../core/models/review.dart';
import '../../../../core/utils/app_logger.dart';

class TobaccoReviewsRepository {
  TobaccoReviewsRepository(this._supabase);

  final SupabaseClient _supabase;

  /// Fetch reviews for a specific tobacco with limit and timeout
  Future<List<Review>> fetchReviews(String tobaccoId, {int limit = 50}) async {
    try {
      final List<dynamic> response = await _supabase
          .from('tobacco_reviews')
          .select('*, profiles:author_id(username, display_name, avatar_url)')
          .eq('tobacco_id', tobaccoId)
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(supabaseReadTimeout);

      return response.map((data) {
        final profile = data['profiles'] as Map<String, dynamic>?;
        final authorName = profile != null
            ? (profile['username'] ?? profile['display_name'] ?? 'Unknown')
            : 'Unknown';
        final authorAvatarUrl = profile != null
            ? profile['avatar_url'] as String?
            : null;

        return Review(
          id: data['id'] as String,
          author: authorName as String,
          authorId: data['author_id'] as String?,
          authorAvatarUrl: authorAvatarUrl,
          rating: (data['rating'] as num).toDouble(),
          comment: data['comment'] as String? ?? '',
          createdAt: DateTime.parse(data['created_at'] as String),
        );
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error al obtener reseñas de tabaco: $tobaccoId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Add a new review with timeout and error logging
  Future<void> addReview({
    required String tobaccoId,
    required String userId,
    required double rating,
    required String comment,
  }) async {
    try {
      await _supabase.from('tobacco_reviews').insert({
        'tobacco_id': tobaccoId,
        'author_id': userId,
        'rating': rating,
        'comment': comment,
      }).timeout(supabaseWriteTimeout);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error al publicar reseña de tabaco: $tobaccoId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
