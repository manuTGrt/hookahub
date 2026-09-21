import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/models/mix.dart';
import 'package:hookahub/features/favorites/domain/favorites_repository.dart';
import 'package:hookahub/features/favorites/presentation/favorites_provider.dart';

class MockFavoritesRepository implements FavoritesRepository {
  List<Mix> favorites = [];
  List<String> top5Ids = [];

  @override
  Future<List<Mix>> loadFavorites() async => List.from(favorites);

  @override
  Future<void> saveFavorites(List<Mix> mixes) async {
    favorites = List.from(mixes);
  }

  @override
  Future<List<String>> loadTop5Ids() async => List.from(top5Ids);

  @override
  Future<void> saveTop5Ids(List<String> ids) async {
    top5Ids = List.from(ids);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFavoritesRepository mockRepo;
  late FavoritesProvider provider;

  const testMix1 = Mix(
    id: 'mix-1',
    name: 'Love 66',
    author: 'HookahMaster',
    rating: 4.8,
    ingredients: ['Sandía', 'Melón', 'Menta'],
    color: Colors.red,
  );

  const testMix2 = Mix(
    id: 'mix-2',
    name: 'Mi Amor',
    author: 'ShishaFan',
    rating: 4.5,
    ingredients: ['Plátano', 'Piña', 'Menta'],
    color: Colors.green,
  );

  setUp(() {
    mockRepo = MockFavoritesRepository();
    provider = FavoritesProvider(mockRepo);
  });

  group('FavoritesProvider Clean Architecture Unit Tests', () {
    test('load() carga favoritos y top 5 correctamente', () async {
      mockRepo.favorites = [testMix1];
      mockRepo.top5Ids = ['mix-1'];

      await provider.load();

      expect(provider.isLoaded, isTrue);
      expect(provider.favorites.length, 1);
      expect(provider.favorites.first.id, 'mix-1');
      expect(provider.isTop5('mix-1'), isTrue);
      expect(provider.top5.length, 1);
    });

    test('addFavorite() añade una mezcla y persiste en el repositorio', () async {
      await provider.load();
      await provider.addFavorite(testMix1);

      expect(provider.favorites.length, 1);
      expect(mockRepo.favorites.length, 1);
      expect(mockRepo.favorites.first.name, 'Love 66');
    });

    test('removeFavorite() elimina la mezcla de favoritos y de top 5', () async {
      mockRepo.favorites = [testMix1, testMix2];
      mockRepo.top5Ids = ['mix-1', 'mix-2'];
      await provider.load();

      await provider.removeFavorite('mix-1');

      expect(provider.favorites.length, 1);
      expect(provider.favorites.first.id, 'mix-2');
      expect(provider.isTop5('mix-1'), isFalse);
      expect(mockRepo.top5Ids.contains('mix-1'), isFalse);
    });

    test('toggleTop5() añade y quita del top 5 respetando límite de 5', () async {
      mockRepo.favorites = [testMix1];
      await provider.load();

      await provider.toggleTop5('mix-1');
      expect(provider.isTop5('mix-1'), isTrue);
      expect(mockRepo.top5Ids.contains('mix-1'), isTrue);

      await provider.toggleTop5('mix-1');
      expect(provider.isTop5('mix-1'), isFalse);
      expect(mockRepo.top5Ids.contains('mix-1'), isFalse);
    });
  });
}
