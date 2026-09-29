import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/models/mix.dart';
import 'package:hookahub/features/mixes/domain/user_mixes_repository.dart';
import 'package:hookahub/features/mixes/presentation/user_mixes_provider.dart';

class MockSealedUserMixesRepository implements UserMixesRepository {
  bool shouldThrow = false;
  List<Mix> returnMixes = const [
    Mix(
      id: 'mix-1',
      name: 'Menta Fresa',
      author: 'Usuario Test',
      rating: 4.5,
      ingredients: ['Menta', 'Fresa'],
      color: Colors.red,
    ),
  ];

  @override
  Future<List<Mix>> fetchMyMixes({int limit = 20, int offset = 0}) async {
    if (shouldThrow) {
      throw Exception('Database query failed');
    }
    return returnMixes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserMixesProvider Sealed State Transitions', () {
    late MockSealedUserMixesRepository repo;
    late UserMixesProvider provider;

    setUp(() {
      repo = MockSealedUserMixesRepository();
      provider = UserMixesProvider(repo);
    });

    tearDown(() {
      provider.dispose();
    });

    test('Inicia en UserMixesInitial y estado inicial es consistente', () {
      expect(provider.state, isA<UserMixesInitial>());
      expect(provider.isLoading, isFalse);
      expect(provider.isLoaded, isFalse);
      expect(provider.error, isNull);
      expect(provider.mixes, isEmpty);
    });

    test('load() exitoso transita a UserMixesLoaded con datos', () async {
      final future = provider.load();
      // Durante el load debe ser UserMixesLoading
      expect(provider.state, isA<UserMixesLoading>());
      expect(provider.isLoading, isTrue);

      await future;

      expect(provider.state, isA<UserMixesLoaded>());
      expect(provider.isLoaded, isTrue);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.mixes.length, 1);
      expect(provider.mixes.first.id, 'mix-1');
    });

    test('load() con fallo transita a UserMixesError y no permite estados contradictorios', () async {
      repo.shouldThrow = true;

      await provider.load();

      expect(provider.state, isA<UserMixesError>());
      final errorState = provider.state as UserMixesError;
      expect(errorState.message, 'No se pudieron cargar tus mezclas');
      // Garantizar que no se encuentre en loading a la vez que error
      expect(provider.isLoading, isFalse);
      expect(provider.isLoaded, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.mixes, isEmpty);
    });

    test('loadMore() actualiza isLoadingMore dentro de UserMixesLoaded', () async {
      repo.returnMixes = List.generate(
        20,
        (i) => Mix(
          id: 'mix-$i',
          name: 'Mix $i',
          author: 'Usuario Test',
          rating: 4.5,
          ingredients: ['Menta'],
          color: Colors.red,
        ),
      );

      await provider.load();
      expect(provider.state, isA<UserMixesLoaded>());
      expect((provider.state as UserMixesLoaded).hasMore, isTrue);

      final loadMoreFuture = provider.loadMore();
      final inProgressState = provider.state as UserMixesLoaded;
      expect(inProgressState.isLoadingMore, isTrue);
      expect(provider.isLoadingMore, isTrue);

      await loadMoreFuture;

      final finishedState = provider.state as UserMixesLoaded;
      expect(finishedState.isLoadingMore, isFalse);
      expect(provider.isLoadingMore, isFalse);
      expect(provider.mixes.length, 40);
    });

    test('clear() restablece el estado a UserMixesInitial', () async {
      await provider.load();
      expect(provider.state, isA<UserMixesLoaded>());

      provider.clear();

      expect(provider.state, isA<UserMixesInitial>());
      expect(provider.mixes, isEmpty);
      expect(provider.isLoaded, isFalse);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
    });
  });
}
