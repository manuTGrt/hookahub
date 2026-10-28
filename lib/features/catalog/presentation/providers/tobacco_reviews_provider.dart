import 'package:hookahub/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/models/review.dart';
import '../../data/tobacco_reviews_repository.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class TobaccoReviewsState {
  const TobaccoReviewsState();
}

/// Estado inicial previo a la carga.
class TobaccoReviewsInitial extends TobaccoReviewsState {
  const TobaccoReviewsInitial();
}

/// Carga de reseñas en progreso.
class TobaccoReviewsLoading extends TobaccoReviewsState {
  const TobaccoReviewsLoading();
}

/// Reseñas cargadas con éxito.
class TobaccoReviewsLoaded extends TobaccoReviewsState {
  const TobaccoReviewsLoaded(this.reviews);
  final List<Review> reviews;
}

/// Error al cargar o enviar reseñas.
class TobaccoReviewsError extends TobaccoReviewsState {
  const TobaccoReviewsError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class TobaccoReviewsProvider extends ChangeNotifier {
  TobaccoReviewsProvider(this._repository);

  final TobaccoReviewsRepository _repository;

  TobaccoReviewsState _state = const TobaccoReviewsInitial();
  List<Review> _cachedReviews = const [];

  // Cache the tobacco ID to allow refreshing seamlessly
  String? _tobaccoId;

  TobaccoReviewsState get state => _state;

  List<Review> get reviews => switch (_state) {
        TobaccoReviewsLoaded(:final reviews) => reviews,
        _ => _cachedReviews,
      };

  bool get isLoading => _state is TobaccoReviewsLoading;

  String? get error => switch (_state) {
        TobaccoReviewsError(:final message) => message,
        _ => null,
      };

  double get averageRating {
    final list = reviews;
    if (list.isEmpty) return 0.0;
    final total = list.fold(0.0, (sum, r) => sum + r.rating);
    return total / list.length;
  }

  int get reviewCount => reviews.length;

  Future<void> loadReviews(String tobaccoId) async {
    _tobaccoId = tobaccoId;
    _state = const TobaccoReviewsLoading();
    notifyListeners();

    try {
      final fetched = await _repository.fetchReviews(tobaccoId);
      _cachedReviews = fetched;
      _state = TobaccoReviewsLoaded(fetched);
    } catch (e, stackTrace) {
      _state = const TobaccoReviewsError('Error al cargar las reseñas');
      AppLogger.error('Error loading tobacco reviews', error: e, stackTrace: stackTrace);
    } finally {
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
    } catch (e, stackTrace) {
      AppLogger.error('Error adding review', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
