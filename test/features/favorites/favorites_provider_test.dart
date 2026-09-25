import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/models/mix.dart';
import 'package:hookahub/features/auth/auth_provider.dart';
import 'package:hookahub/features/favorites/domain/favorites_repository.dart';
import 'package:hookahub/features/favorites/presentation/favorites_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockFavoritesRepository implements FavoritesRepository {
  List<Mix> favorites = [];
  List<String> top5Ids = [];
  String? lastLoadedUserId;
  String? lastSavedUserId;

  @override
  Future<List<Mix>> loadFavorites({String? userId}) async {
    lastLoadedUserId = userId;
    return List.from(favorites);
  }

  @override
  Future<void> saveFavorites(List<Mix> mixes, {String? userId}) async {
    lastSavedUserId = userId;
    favorites = List.from(mixes);
  }

  @override
  Future<void> addFavorite(Mix mix, {String? userId}) async {
    lastSavedUserId = userId;
    if (!favorites.any((m) => m.id == mix.id)) {
      favorites.add(mix);
    }
  }

  @override
  Future<void> removeFavorite(String mixId, {String? userId}) async {
    lastSavedUserId = userId;
    favorites.removeWhere((m) => m.id == mixId);
    top5Ids.remove(mixId);
  }

  @override
  Future<List<String>> loadTop5Ids({String? userId}) async {
    lastLoadedUserId = userId;
    return List.from(top5Ids);
  }

  @override
  Future<void> saveTop5Ids(List<String> ids, {String? userId}) async {
    lastSavedUserId = userId;
    top5Ids = List.from(ids);
  }
}

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  final List<VoidCallback> _signOutListeners = [];
  final List<VoidCallback> _signInListeners = [];
  User? _user;

  @override
  User? get user => _user;

  void setMockUser(User? user) {
    _user = user;
    notifyListeners();
  }

  @override
  void addSignOutListener(VoidCallback listener) {
    _signOutListeners.add(listener);
  }

  @override
  void removeSignOutListener(VoidCallback listener) {
    _signOutListeners.remove(listener);
  }

  @override
  void addSignInListener(VoidCallback listener) {
    _signInListeners.add(listener);
  }

  @override
  void removeSignInListener(VoidCallback listener) {
    _signInListeners.remove(listener);
  }

  void triggerSignOut() {
    for (final l in List<VoidCallback>.from(_signOutListeners)) {
      l();
    }
  }

  void triggerSignIn() {
    for (final l in List<VoidCallback>.from(_signInListeners)) {
      l();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

    test('signOut() limpia la lista en memoria y resetea isLoaded evitando fuga de datos cruzada', () async {
      final fakeAuth = FakeAuthProvider();
      final authProviderInstance = FavoritesProvider(mockRepo, auth: fakeAuth);

      mockRepo.favorites = [testMix1, testMix2];
      mockRepo.top5Ids = ['mix-1'];
      await authProviderInstance.load();

      expect(authProviderInstance.favorites.length, 2);
      expect(authProviderInstance.top5.length, 1);
      expect(authProviderInstance.isLoaded, isTrue);

      // Simular que el usuario cierra sesión
      fakeAuth.triggerSignOut();

      // Debe haberse limpiado en memoria inmediatamente
      expect(authProviderInstance.favorites.isEmpty, isTrue);
      expect(authProviderInstance.top5.isEmpty, isTrue);
      expect(authProviderInstance.isLoaded, isFalse);

      authProviderInstance.dispose();
    });

    test('clear() vacía inmediatamente el estado en memoria', () async {
      mockRepo.favorites = [testMix1];
      await provider.load();
      expect(provider.favorites.isNotEmpty, isTrue);

      provider.clear();

      expect(provider.favorites.isEmpty, isTrue);
      expect(provider.top5.isEmpty, isTrue);
      expect(provider.isLoaded, isFalse);
    });
  });
}

