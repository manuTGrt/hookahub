import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hookahub/core/models/tobacco.dart';
import 'package:hookahub/features/catalog/presentation/catalog_page.dart';
import 'package:hookahub/features/catalog/data/tobacco_repository.dart';
import 'package:hookahub/features/catalog/domain/catalog_filters.dart';
import 'package:hookahub/features/catalog/presentation/providers/catalog_provider.dart';

class FakeTobaccoRepository implements TobaccoRepository {
  List<Tobacco> mockTobaccos = [];
  List<String> mockBrands = ['Al Fakher', 'Starbuzz'];

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

  group('CatalogProvider Scroll Decoupling Tests', () {
    test('CatalogProvider does not hold a ScrollController instance', () {
      final fakeRepo = FakeTobaccoRepository();
      final provider = CatalogProvider(fakeRepo);

      // Verify that scrollToTop invokes onScrollToTopRequested callback
      bool callbackInvoked = false;
      provider.onScrollToTopRequested = () {
        callbackInvoked = true;
      };

      provider.scrollToTop();
      expect(callbackInvoked, isTrue);

      provider.dispose();
      expect(provider.onScrollToTopRequested, isNull);
    });
  });

  group('CatalogPage ScrollController Lifecycle Tests', () {
    testWidgets('registers onScrollToTopRequested on mount and cleans up on unmount', (tester) async {
      final fakeRepo = FakeTobaccoRepository();
      fakeRepo.mockTobaccos = List.generate(
        10,
        (i) => Tobacco(
          id: 'tobacco-$i',
          name: 'Tobacco $i',
          brand: 'Brand $i',
          description: 'Description $i',
          flavors: const ['mint'],
          rating: 4.5,
          reviews: 10,
        ),
      );

      final provider = CatalogProvider(fakeRepo);

      Widget buildWidgetTree(bool showCatalog) {
        return ChangeNotifierProvider<CatalogProvider>.value(
          value: provider,
          child: MaterialApp(
            home: showCatalog ? const CatalogPage() : const SizedBox.shrink(),
          ),
        );
      }

      // 1. Mount CatalogPage
      await tester.pumpWidget(buildWidgetTree(true));
      await tester.pumpAndSettle();

      // Verify callback is registered
      expect(provider.onScrollToTopRequested, isNotNull);

      // Verify scrollToTop can be called safely without exceptions
      expect(() => provider.scrollToTop(), returnsNormally);
      await tester.pumpAndSettle();

      // 2. Unmount CatalogPage (simulating navigation away or tab rebuild)
      await tester.pumpWidget(buildWidgetTree(false));
      await tester.pumpAndSettle();

      // Verify callback is cleared on unmount, preventing memory leaks
      expect(provider.onScrollToTopRequested, isNull);

      // Clean up provider
      provider.dispose();
    });
  });
}
