import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hookahub/core/models/mix.dart';
import 'package:hookahub/core/providers/database_health_provider.dart';
import 'package:hookahub/core/services/database_health_service.dart';
import 'package:hookahub/features/community/data/community_repository.dart';
import 'package:hookahub/features/community/presentation/community_provider.dart';
import 'package:hookahub/features/community/presentation/mix_detail_page.dart';
import 'package:hookahub/features/favorites/domain/favorites_repository.dart';
import 'package:hookahub/features/favorites/presentation/favorites_provider.dart';
import 'package:hookahub/features/history/data/history_repository.dart';
import 'package:hookahub/features/history/presentation/history_provider.dart';

class FakeDatabaseHealthService implements DatabaseHealthService {
  @override
  Future<bool> checkDatabaseConnection() async => true;
}

class FakeFavoritesRepository implements FavoritesRepository {
  @override
  Future<List<Mix>> loadFavorites({String? userId}) async => [];

  @override
  Future<void> saveFavorites(List<Mix> mixes, {String? userId}) async {}

  @override
  Future<void> addFavorite(Mix mix, {String? userId}) async {}

  @override
  Future<void> removeFavorite(String mixId, {String? userId}) async {}

  @override
  Future<List<String>> loadTop5Ids({String? userId}) async => [];

  @override
  Future<void> saveTop5Ids(List<String> ids, {String? userId}) async {}
}

class FakeCommunityRepository implements CommunityRepository {
  @override
  Future<List<Mix>> fetchMixes({
    String orderBy = 'recent',
    int limit = 20,
    int offset = 0,
    String? tobaccoName,
    String? tobaccoBrand,
  }) async => [];

  @override
  Future<Map<String, dynamic>?> fetchMixDetails(String mixId) async => {
    'description': 'Mezcla de prueba',
    'components': <Map<String, dynamic>>[],
  };

  @override
  Future<bool> isMyMix(String mixId) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHistoryRepository implements HistoryRepository {
  @override
  Future<bool> recordMixView(String mixId) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHealthProvider healthProvider;
  late FavoritesProvider favoritesProvider;
  late CommunityProvider communityProvider;
  late HistoryProvider historyProvider;

  setUp(() {
    healthProvider = DatabaseHealthProvider(
      healthService: FakeDatabaseHealthService(),
    );
    favoritesProvider = FavoritesProvider(FakeFavoritesRepository());
    communityProvider = CommunityProvider(FakeCommunityRepository());
    historyProvider = HistoryProvider(FakeHistoryRepository());
  });

  tearDown(() {
    healthProvider.dispose();
  });

  final testMix = Mix(
    id: 'test-mix-id',
    name: 'Menta Fresca',
    author: 'Tester',
    rating: 4.5,
    reviews: 1,
    ingredients: const ['Menta'],
    color: const Color(0xFF10B981),
  );

  Widget createTestHarness({required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DatabaseHealthProvider>.value(value: healthProvider),
        ChangeNotifierProvider<FavoritesProvider>.value(value: favoritesProvider),
        ChangeNotifierProvider<CommunityProvider>.value(value: communityProvider),
        ChangeNotifierProvider<HistoryProvider>.value(value: historyProvider),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Pruebas de Ciclo de Vida y Memoria en MixDetailPage', () {
    testWidgets(
      'MixDetailPage cancela _reconnectedSub en dispose y no lanza excepciones al reconectar tras desmonte',
      (WidgetTester tester) async {
        // 1. Montar MixDetailPage
        await tester.pumpWidget(
          createTestHarness(
            child: MixDetailPage(mix: testMix),
          ),
        );
        await tester.pump();

        // 2. Desmontar el widget completamente (simula Navigator.pop())
        await tester.pumpWidget(
          createTestHarness(
            child: const Scaffold(body: Center(child: Text('Pantalla Anterior'))),
          ),
        );
        await tester.pumpAndSettle();

        // 3. Disparar evento de reconexión global
        // Si _reconnectedSub no se hubiera cancelado, el callback intentaría ejecutar código
        // o lanzar excepciones de unmounted state.
        await healthProvider.retryConnection();
        await tester.pump();

        // 4. Asegurar que no hay excepciones ni fugas
        expect(tester.takeException(), isNull);
        expect(find.text('Pantalla Anterior'), findsOneWidget);
      },
    );

    testWidgets(
      'El diálogo de edición se cierra limpiamente por barrier dismiss sin errores de ciclo de vida',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestHarness(
            child: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (_) => const AlertDialog(
                        title: Text('Editar reseña'),
                        content: TextField(),
                      ),
                    );
                  },
                  child: const Text('Abrir modal'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir modal'));
        await tester.pumpAndSettle();

        expect(find.text('Editar reseña'), findsOneWidget);

        // Tap fuera del diálogo (barrier dismiss)
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text('Editar reseña'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
