import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/models/review.dart';
import 'package:hookahub/features/catalog/data/tobacco_reviews_repository.dart';
import 'package:hookahub/features/catalog/presentation/providers/tobacco_reviews_provider.dart';

class FakeTobaccoReviewsRepository implements TobaccoReviewsRepository {
  FakeTobaccoReviewsRepository({this.shouldThrow = false});

  bool shouldThrow;
  final List<Review> mockReviews = [
    Review(
      id: 'rev-1',
      author: 'User1',
      rating: 4.5,
      comment: 'Muy buen sabor',
      createdAt: DateTime(2026, 1, 1),
    ),
    Review(
      id: 'rev-2',
      author: 'User2',
      rating: 3.5,
      comment: 'Aceptable',
      createdAt: DateTime(2026, 1, 2),
    ),
  ];

  @override
  Future<List<Review>> fetchReviews(String tobaccoId, {int limit = 50}) async {
    if (shouldThrow) {
      throw Exception('Database query timeout');
    }
    return mockReviews;
  }

  @override
  Future<void> addReview({
    required String tobaccoId,
    required String userId,
    required double rating,
    required String comment,
  }) async {
    if (shouldThrow) {
      throw Exception('Database write error');
    }
    mockReviews.insert(
      0,
      Review(
        id: 'rev-new',
        author: 'Me',
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      ),
    );
  }
}

void main() {
  group('TobaccoReviewsProvider Sealed State Transitions', () {
    test('Inicia en TobaccoReviewsInitial con estado consistente', () {
      final fakeRepo = FakeTobaccoReviewsRepository();
      final provider = TobaccoReviewsProvider(fakeRepo);

      expect(provider.state, isA<TobaccoReviewsInitial>());
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.reviews, isEmpty);
      expect(provider.reviewCount, equals(0));
      expect(provider.averageRating, equals(0.0));
    });

    test('loadReviews transita a Loading y luego a Loaded con datos correctos', () async {
      final fakeRepo = FakeTobaccoReviewsRepository();
      final provider = TobaccoReviewsProvider(fakeRepo);

      final future = provider.loadReviews('tobacco-123');

      expect(provider.state, isA<TobaccoReviewsLoading>());
      expect(provider.isLoading, isTrue);

      await future;

      expect(provider.state, isA<TobaccoReviewsLoaded>());
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.reviews.length, equals(2));
      expect(provider.reviewCount, equals(2));
      expect(provider.averageRating, equals(4.0));
    });

    test('loadReviews con error transita a TobaccoReviewsError', () async {
      final fakeRepo = FakeTobaccoReviewsRepository(shouldThrow: true);
      final provider = TobaccoReviewsProvider(fakeRepo);

      await provider.loadReviews('tobacco-123');

      expect(provider.state, isA<TobaccoReviewsError>());
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.reviews, isEmpty);
    });

    test('addReview añade reseña y recarga lista', () async {
      final fakeRepo = FakeTobaccoReviewsRepository();
      final provider = TobaccoReviewsProvider(fakeRepo);

      await provider.loadReviews('tobacco-123');
      expect(provider.reviews.length, equals(2));

      await provider.addReview(
        userId: 'user-xyz',
        rating: 5.0,
        comment: 'Excelente',
      );

      expect(provider.state, isA<TobaccoReviewsLoaded>());
      expect(provider.reviews.length, equals(3));
      expect(provider.reviewCount, equals(3));
    });
  });
}
