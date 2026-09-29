import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/models/tobacco.dart';
import 'package:hookahub/features/catalog/data/tobacco_repository.dart';
import 'package:hookahub/features/catalog/domain/catalog_filters.dart';
import 'package:hookahub/features/catalog/presentation/providers/catalog_provider.dart';

class FakeSealedTobaccoRepository implements TobaccoRepository {
  bool shouldThrow = false;
  List<Tobacco> mockTobaccos = List.generate(
    20,
    (i) => Tobacco(
      id: 'tobacco-$i',
      name: 'Tobacco Name $i',
      brand: 'Brand $i',
      description: 'Description $i',
      flavors: const ['mint'],
      rating: 4.5,
      reviews: 10,
    ),
  );

  @override
  Future<List<Tobacco>> fetchTobaccos({
    required int offset,
    int limit = 20,
    String? query,
    CatalogFilter? filter,
  }) async {
    if (shouldThrow) throw Exception('Database error');
    return mockTobaccos;
  }

  @override
  Future<List<String>> fetchAvailableBrands() async => ['Brand 0', 'Brand 1'];

  @override
  Future<Tobacco?> fetchTobaccoById(String id) async {
    return mockTobaccos.firstWhere((t) => t.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSealedTobaccoRepository fakeRepo;
  late CatalogProvider provider;

  setUp(() {
    fakeRepo = FakeSealedTobaccoRepository();
    provider = CatalogProvider(fakeRepo);
  });

  tearDown(() {
    provider.dispose();
  });

  group('CatalogProvider Sealed State Transitions', () {
    test('Inicia en CatalogInitial y getters iniciales son consistentes', () {
      expect(provider.state, isA<CatalogInitial>());
      expect(provider.isLoading, isFalse);
      expect(provider.isLoaded, isFalse);
      expect(provider.items, isEmpty);
      expect(provider.error, isNull);
      expect(provider.hasAttemptedLoad, isFalse);
    });

    test('loadMore() exitoso transita a CatalogLoaded con items', () async {
      final future = provider.loadMore();
      // Durante primera carga debe estar en CatalogLoading
      expect(provider.state, isA<CatalogLoading>());
      expect(provider.isLoading, isTrue);

      await future;

      expect(provider.state, isA<CatalogLoaded>());
      final loadedState = provider.state as CatalogLoaded;
      expect(loadedState.items.length, 20);
      expect(loadedState.hasMore, isTrue);
      expect(loadedState.isLoadingMore, isFalse);

      expect(provider.isLoaded, isTrue);
      expect(provider.isLoading, isFalse);
      expect(provider.hasAttemptedLoad, isTrue);
      expect(provider.error, isNull);
    });

    test('loadMore() con error transita a CatalogError y previene estados contradictorios', () async {
      fakeRepo.shouldThrow = true;

      await provider.loadMore();

      expect(provider.state, isA<CatalogError>());
      final errorState = provider.state as CatalogError;
      expect(errorState.message, isNotEmpty);

      expect(provider.isLoading, isFalse);
      expect(provider.isLoaded, isFalse);
      expect(provider.items, isEmpty);
      expect(provider.error, isNotNull);
      expect(provider.hasAttemptedLoad, isTrue);
    });

    test('loadMore() adicional activa isLoadingMore dentro de CatalogLoaded', () async {
      await provider.loadMore();
      expect(provider.state, isA<CatalogLoaded>());

      fakeRepo.mockTobaccos = List.generate(
        10,
        (i) => Tobacco(
          id: 'tobacco-extra-$i',
          name: 'Extra $i',
          brand: 'Brand Extra',
          description: 'Desc',
          flavors: const ['berry'],
          rating: 4.0,
          reviews: 5,
        ),
      );

      final secondLoadFuture = provider.loadMore();
      final inProgressState = provider.state as CatalogLoaded;
      expect(inProgressState.isLoadingMore, isTrue);
      expect(provider.isLoadingMore, isTrue);

      await secondLoadFuture;

      final finishedState = provider.state as CatalogLoaded;
      expect(finishedState.isLoadingMore, isFalse);
      expect(provider.isLoadingMore, isFalse);
      expect(provider.items.length, 30);
      // 10 < 20 (pageSize) -> hasMore = false
      expect(finishedState.hasMore, isFalse);
      expect(provider.hasMore, isFalse);
    });

    test('updateItem() actualiza el item inmutablemente en CatalogLoaded', () async {
      await provider.loadMore();
      expect(provider.state, isA<CatalogLoaded>());

      final updated = Tobacco(
        id: 'tobacco-0',
        name: 'Tobacco Name 0 Modificado',
        brand: 'Brand 0',
        description: 'New Desc',
        flavors: const ['mint'],
        rating: 5.0,
        reviews: 25,
      );

      provider.updateItem(updated);

      final state = provider.state as CatalogLoaded;
      expect(state.items.first.name, 'Tobacco Name 0 Modificado');
      expect(provider.items.first.rating, 5.0);
    });

    test('refresh() recarga el catálogo desde offset 0', () async {
      await provider.loadMore();
      expect(provider.items.length, 20);

      await provider.refresh();

      expect(provider.state, isA<CatalogLoaded>());
      expect(provider.items.length, 20);
    });
  });
}
