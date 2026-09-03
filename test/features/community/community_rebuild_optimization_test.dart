import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hookahub/core/models/mix.dart';
import 'package:hookahub/features/favorites/favorites_provider.dart';
import 'package:hookahub/features/favorites/favorites_repository.dart';
import 'package:hookahub/features/profile/presentation/profile_provider.dart';
import 'package:hookahub/features/profile/domain/profile.dart';

class FakeFavoritesRepository implements FavoritesRepository {
  List<Mix> _storedFavorites = [];
  List<String> _storedTop5 = [];

  @override
  Future<List<Mix>> loadFavorites() async => _storedFavorites;

  @override
  Future<void> saveFavorites(List<Mix> mixes) async {
    _storedFavorites = List.from(mixes);
  }

  @override
  Future<List<String>> loadTop5Ids() async => _storedTop5;

  @override
  Future<void> saveTop5Ids(List<String> ids) async {
    _storedTop5 = List.from(ids);
  }
}

class FakeProfileProvider extends ChangeNotifier implements ProfileProvider {
  Profile? _profile = Profile(
    id: 'user-1',
    username: 'test_user',
    email: 'user1@example.com',
    displayName: 'Test User',
  );

  @override
  Profile? get profile => _profile;

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  void setProfile(Profile profile) {
    _profile = profile;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mix1 = Mix(
    id: 'mix-1',
    name: 'Mix Alfa',
    author: 'author1',
    ingredients: const ['Menta', 'Uva'],
    rating: 4.5,
    reviews: 10,
    color: const Color(0xFF10B981),
  );

  final mix2 = Mix(
    id: 'mix-2',
    name: 'Mix Beta',
    author: 'author2',
    ingredients: const ['Melocotón'],
    rating: 4.0,
    reviews: 5,
    color: const Color(0xFF3B82F6),
  );

  final mix3 = Mix(
    id: 'mix-3',
    name: 'Mix Gamma',
    author: 'author3',
    ingredients: const ['Limón', 'Vainilla'],
    rating: 5.0,
    reviews: 20,
    color: const Color(0xFFEC4899),
  );

  testWidgets(
    'context.select solo reconstruye la tarjeta cuyo estado de favorito cambia',
    (WidgetTester tester) async {
      final favRepo = FakeFavoritesRepository();
      final favProvider = FavoritesProvider(favRepo);
      final profileProvider = FakeProfileProvider();

      final buildCounts = <String, int>{
        'mix-1': 0,
        'mix-2': 0,
        'mix-3': 0,
      };

      Widget buildCard(Mix mix) {
        return Builder(
          builder: (context) {
            final isFav = context.select<FavoritesProvider, bool>(
              (fav) => fav.favorites.any((m) => m.id == mix.id),
            );
            buildCounts[mix.id] = (buildCounts[mix.id] ?? 0) + 1;

            return Text('${mix.name}: isFav=$isFav');
          },
        );
      }

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FavoritesProvider>.value(value: favProvider),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  buildCard(mix1),
                  buildCard(mix2),
                  buildCard(mix3),
                ],
              ),
            ),
          ),
        ),
      );

      // Verificación inicial: cada tarjeta se ha construido exactamente 1 vez
      expect(buildCounts['mix-1'], 1);
      expect(buildCounts['mix-2'], 1);
      expect(buildCounts['mix-3'], 1);

      // Acción: Añadir mix1 a favoritos
      await favProvider.addFavorite(mix1);
      await tester.pump();

      // Comprobación granular: SOLO mix1 debe haberse reconstruido (+1 = 2)
      // mix2 y mix3 NO deben haberse reconstruido (se mantienen en 1)
      expect(buildCounts['mix-1'], 2, reason: 'mix-1 debió reconstruirse');
      expect(buildCounts['mix-2'], 1, reason: 'mix-2 NO debió reconstruirse');
      expect(buildCounts['mix-3'], 1, reason: 'mix-3 NO debió reconstruirse');

      // Acción: Quitar mix1 de favoritos
      await favProvider.removeFavorite(mix1.id);
      await tester.pump();

      // Comprobación granular: SOLO mix1 se reconstruye de nuevo (+1 = 3)
      // mix2 y mix3 continúan sin reconstruirse (se mantienen en 1)
      expect(buildCounts['mix-1'], 3, reason: 'mix-1 debió reconstruirse de nuevo');
      expect(buildCounts['mix-2'], 1, reason: 'mix-2 sigue sin reconstruirse');
      expect(buildCounts['mix-3'], 1, reason: 'mix-3 sigue sin reconstruirse');
    },
  );

  testWidgets(
    'context.select con ProfileProvider solo reconstruye si cambia la autoría',
    (WidgetTester tester) async {
      final favRepo = FakeFavoritesRepository();
      final favProvider = FavoritesProvider(favRepo);
      final profileProvider = FakeProfileProvider();

      int mix1OwnershipBuildCount = 0;
      int mix2OwnershipBuildCount = 0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FavoritesProvider>.value(value: favProvider),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Builder(
                    builder: (context) {
                      final isOwned = context.select<ProfileProvider, bool>(
                        (p) => p.profile?.username != null && p.profile!.username == mix1.author,
                      );
                      mix1OwnershipBuildCount++;
                      return Text('Mix1 Owned: $isOwned');
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final isOwned = context.select<ProfileProvider, bool>(
                        (p) => p.profile?.username != null && p.profile!.username == mix2.author,
                      );
                      mix2OwnershipBuildCount++;
                      return Text('Mix2 Owned: $isOwned');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(mix1OwnershipBuildCount, 1);
      expect(mix2OwnershipBuildCount, 1);

      // Cambiamos el perfil a author1
      profileProvider.setProfile(Profile(
        id: 'user-author-1',
        username: 'author1',
        email: 'author1@example.com',
        displayName: 'Author One',
      ));
      await tester.pump();

      // mix1 ahora es owned (pasa de false a true) -> se reconstruye (count = 2)
      // mix2 sigue siendo no owned (false a false) -> NO se reconstruye (count = 1)
      expect(mix1OwnershipBuildCount, 2);
      expect(mix2OwnershipBuildCount, 1);
    },
  );
}
