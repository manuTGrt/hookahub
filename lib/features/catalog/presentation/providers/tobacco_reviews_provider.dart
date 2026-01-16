import 'package:flutter/foundation.dart';
import '../../../../core/models/review.dart';
import '../../data/tobacco_reviews_repository.dart';

class TobaccoReviewsProvider extends ChangeNotifier {
  TobaccoReviewsProvider(this._repository);

  final TobaccoReviewsRepository _repository;

  List<Review> _reviews = [];
  bool _isLoading = false;
  String? _error;

  // Cache the tobacco ID to allow refreshing seamlessly
  String? _tobaccoId;

  List<Review> get reviews => List.unmodifiable(_reviews);
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get averageRating {
    if (_reviews.isEmpty) return 0.0;
    final total = _reviews.fold(0.0, (sum, r) => sum + r.rating);
    return total / _reviews.length;
  }

  int get reviewCount => _reviews.length;

  Future<void> loadReviews(String tobaccoId) async {
    _tobaccoId = tobaccoId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _reviews = await _repository.fetchReviews(tobaccoId);
    } catch (e) {
      _error = 'Error al cargar las reseñas';
      debugPrint('Error loading tobacco reviews: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addReview({
    required String userId,
    required double rating,
    required String comment,
  }) async {
    if (_tobaccoId == null) return;

    try {
      await _repository.addReview(
        tobaccoId: _tobaccoId!,
        userId: userId,
        rating: rating,
        comment: comment,
      );
      // Reload to get the updated list and server-side timestamp
      await loadReviews(_tobaccoId!);
    } catch (e) {
      debugPrint('Error adding review: $e');
      rethrow;
    }
  }
}
