import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/models/mix.dart';
import 'package:hookahub/core/providers/database_health_provider.dart';
import 'package:hookahub/core/services/database_health_service.dart';
import 'package:hookahub/features/community/data/community_repository.dart';
import 'package:hookahub/features/community/presentation/community_provider.dart';

class FakeSealedCommunityRepository implements CommunityRepository {
  bool shouldThrow = false;
  List<Mix> mockMixes = List.generate(
    20,
    (i) => Mix(
      id: 'mix-$i',
      name: 'Mix $i',
      author: 'Author $i',
      rating: 4.5,
      reviews: 5,
      ingredients: const ['Menta'],
      color: Colors.green,
    ),
  );

  @override
  Future<List<Mix>> fetchMixes({
    String orderBy = 'recent',
    int limit = 20,
    int offset = 0,
    String? tobaccoName,
    String? tobaccoBrand,
    String? query,
  }) async {
    if (shouldThrow) throw Exception('Database error');
    return mockMixes;
  }

  @override
  Future<List<Mix>> fetchFavorites() async => mockMixes;

  @override
  Future<Mix?> createMix({
    required String name,
    String? description,
    required List<Map<String, dynamic>> components,
  }) async {
    if (shouldThrow) throw Exception('Database error');
    return Mix(
      id: 'new-mix-id',
      name: name,
      author: 'Current User',
      rating: 0.0,
      reviews: 0,
      ingredients: const ['Fresa'],
      color: Colors.red,
    );
  }

  @override
  Future<Mix?> updateMix({
    required String mixId,
    required String name,
    String? description,
    required List<Map<String, dynamic>> components,
  }) async {
    return Mix(
      id: mixId,
      name: name,
      author: 'Current User',
      rating: 4.0,
      reviews: 1,
      ingredients: const ['Menta'],
      color: Colors.blue,
    );
  }

  @override
  Future<bool> deleteMix(String mixId) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDatabaseHealthService implements DatabaseHealthService {
  @override
  Future<bool> checkDatabaseConnection() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHealthProvider healthProvider;
  late FakeSealedCommunityRepository fakeRepo;
  late CommunityProvider provider;

  setUp(() {
    healthProvider = DatabaseHealthProvider(
      healthService: FakeDatabaseHealthService(),
    );
    fakeRepo = FakeSealedCommunityRepository();
    provider = CommunityProvider(fakeRepo);
  });

  tearDown(() {
    provider.dispose();
    healthProvider.dispose();
  });

  group('CommunityProvider Sealed State Transitions', () {
    test('Inicia en CommunityInitial y getters iniciales son consistentes', () {
      expect(provider.state, isA<CommunityInitial>());
      expect(provider.isLoading, isFalse);
      expect(provider.isLoaded, isFalse);
      expect(provider.mixes, isEmpty);
      expect(provider.error, isNull);
      expect(provider.hasMoreData, isTrue);
    });

    test('loadMixes() exitoso transita a CommunityLoaded con mixes', () async {
      final future = provider.loadMixes();
      expect(provider.state, isA<CommunityLoading>());
      expect(provider.isLoading, isTrue);

      await future;

      expect(provider.state, isA<CommunityLoaded>());
      final loadedState = provider.state as CommunityLoaded;
      expect(loadedState.mixes.length, 20);
      expect(loadedState.hasMoreData, isTrue);
      expect(loadedState.isLoadingMore, isFalse);

      expect(provider.isLoaded, isTrue);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
    });

    test('loadMixes() con fallo transita a CommunityError y evita estados contradictorios', () async {
      fakeRepo.shouldThrow = true;

      await provider.loadMixes();

      expect(provider.state, isA<CommunityError>());
      final errorState = provider.state as CommunityError;
      expect(errorState.message, contains('Database error'));

      expect(provider.isLoading, isFalse);
      expect(provider.isLoaded, isFalse);
      expect(provider.mixes, isEmpty);
      expect(provider.error, isNotNull);
    });

    test('loadMoreMixes() actualiza isLoadingMore dentro de CommunityLoaded', () async {
      await provider.loadMixes();
      expect(provider.state, isA<CommunityLoaded>());

      fakeRepo.mockMixes = List.generate(
        10,
        (i) => Mix(
          id: 'mix-extra-$i',
          name: 'Extra $i',
          author: 'Author $i',
          rating: 4.0,
          reviews: 1,
          ingredients: const ['Fresa'],
          color: Colors.red,
        ),
      );

      final secondLoadFuture = provider.loadMoreMixes();
      final inProgressState = provider.state as CommunityLoaded;
      expect(inProgressState.isLoadingMore, isTrue);
      expect(provider.isLoadingMore, isTrue);

      await secondLoadFuture;

      final finishedState = provider.state as CommunityLoaded;
      expect(finishedState.isLoadingMore, isFalse);
      expect(provider.isLoadingMore, isFalse);
      expect(provider.mixes.length, 30);
      // 10 < 20 (pageSize) -> hasMoreData = false
      expect(finishedState.hasMoreData, isFalse);
      expect(provider.hasMoreData, isFalse);
    });

    test('createMix(), updateMix() y deleteMix() actualizan inmutablemente CommunityLoaded', () async {
      await provider.loadMixes();
      expect(provider.mixes.length, 20);

      // Create
      await provider.createMix(
        name: 'Nuevo Mix',
        components: [
          {'tobacco_name': 'Menta', 'percentage': 100.0, 'color': '#00FF00'},
        ],
      );
      expect(provider.state, isA<CommunityLoaded>());

      // Update
      final updatedMix = Mix(
        id: 'mix-0',
        name: 'Mix 0 Editado',
        author: 'Author 0',
        rating: 5.0,
        reviews: 10,
        ingredients: const ['Menta'],
        color: Colors.green,
      );
      provider.updateMix(updatedMix);
      expect(provider.mixes.first.name, 'Mix 0 Editado');

      // Delete
      await provider.deleteMix('mix-0');
      expect(provider.mixes.any((m) => m.id == 'mix-0'), isFalse);
    });

    test('setLocalFavorites() inyecta favoritas como CommunityLoaded', () {
      final local = [
        const Mix(
          id: 'fav-1',
          name: 'Fav Mix',
          author: 'Me',
          rating: 5.0,
          reviews: 2,
          ingredients: ['Menta'],
          color: Colors.blue,
        ),
      ];

      provider.setLocalFavorites(local);

      expect(provider.state, isA<CommunityLoaded>());
      expect(provider.mixes.length, 1);
      expect(provider.mixes.first.name, 'Fav Mix');
      expect(provider.hasMoreData, isFalse);
      expect(provider.isLoading, isFalse);
    });
  });
}
