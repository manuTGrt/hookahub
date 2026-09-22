import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hookahub/core/models/tobacco.dart';
import 'package:hookahub/features/catalog/catalog_page.dart';
import 'package:hookahub/features/catalog/data/tobacco_repository.dart';
import 'package:hookahub/features/catalog/domain/catalog_filters.dart';
import 'package:hookahub/features/catalog/presentation/providers/catalog_provider.dart';

class _FakeTobaccoRepo implements TobaccoRepository {
  List<Tobacco> mockTobaccos = [];
  List<String> mockBrands = ['Al Fakher', 'Starbuzz', 'Tangiers'];

  @override
  Future<List<Tobacco>> fetchTobaccos({
    required int offset,
    int limit = TobaccoRepository.defaultPageSize,
    String? query,
    CatalogFilter? filter,
  }) async {
    return mockTobaccos;
  }

  @override
  Future<List<String>> fetchAvailableBrands() async {
    return mockBrands;
  }

  @override
  Future<Tobacco?> fetchTobaccoById(String id) async {
    try {
      return mockTobaccos.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CatalogPage Granular Rebuild and Rendering Tests', () {
    late _FakeTobaccoRepo fakeRepo;
    late CatalogProvider provider;

    setUp(() {
      fakeRepo = _FakeTobaccoRepo();
      fakeRepo.mockTobaccos = List.generate(
        4,
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
      provider = CatalogProvider(fakeRepo);
    });

    tearDown(() {
      provider.dispose();
    });

    Widget createWidgetUnderTest() {
      return ChangeNotifierProvider<CatalogProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: CatalogPage(),
        ),
      );
    }

    testWidgets('renders CatalogPage with filters, items and no root watch rebuild issues', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Ensure sort dropdown and brand dropdown are rendered
      expect(find.text(SortOption.newest.label), findsOneWidget);
      expect(find.text('Todas las marcas'), findsOneWidget);

      // Trigger loadMore so items populate
      await provider.loadMore();
      await tester.pumpAndSettle();

      // Verify tobacco cards appear
      expect(find.text('Tobacco Name 0'), findsOneWidget);
      expect(find.text('Tobacco Name 1'), findsOneWidget);
    });

    testWidgets('changing sort option updates sort dropdown reactively', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text(SortOption.newest.label), findsOneWidget);

      // Change sort option
      provider.setSortOption(SortOption.topRated);
      await tester.pumpAndSettle();

      expect(find.text(SortOption.topRated.label), findsOneWidget);
      expect(find.text(SortOption.newest.label), findsNothing);
    });

    testWidgets('changing brand filter updates brand dropdown reactively', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Todas las marcas'), findsOneWidget);

      // Change brand filter
      provider.setFilterByBrand('Starbuzz');
      await tester.pumpAndSettle();

      expect(find.text('Starbuzz'), findsOneWidget);
      expect(find.text('Todas las marcas'), findsNothing);
    });

    testWidgets('displays empty state when attempted load finishes with empty list', (tester) async {
      fakeRepo.mockTobaccos = [];
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await provider.refresh();
      await tester.pumpAndSettle();

      expect(find.text('Aún no hay tabacos'), findsOneWidget);
    });

    testWidgets('item update updates the card in place', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      await provider.loadMore();
      await tester.pumpAndSettle();

      expect(find.text('Tobacco Name 0'), findsOneWidget);

      final updatedTobacco = Tobacco(
        id: 'tobacco-0',
        name: 'Tobacco Name 0 Updated',
        brand: 'Brand 0',
        description: 'Description 0',
        flavors: const ['mint'],
        rating: 5.0,
        reviews: 20,
      );

      provider.updateItem(updatedTobacco);
      await tester.pumpAndSettle();

      expect(find.text('Tobacco Name 0 Updated'), findsOneWidget);
    });
  });
}
