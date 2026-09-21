import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/models/mix.dart';
import 'package:hookahub/features/mixes/domain/user_mixes_repository.dart';
import 'package:hookahub/features/mixes/presentation/user_mixes_provider.dart';

class FakeUserMixesRepository implements UserMixesRepository {
  @override
  Future<List<Mix>> fetchMyMixes({int limit = 20, int offset = 0}) async {
    return const [
      Mix(
        id: 'mix-1',
        name: 'Menta Fresa',
        author: 'Usuario Test',
        rating: 4.5,
        ingredients: ['Menta', 'Fresa'],
        color: Colors.red,
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UserMixesProvider clear() limpia la memoria al cerrar sesión', () async {
    final fakeRepo = FakeUserMixesRepository();
    final provider = UserMixesProvider(fakeRepo);

    await provider.load();
    expect(provider.mixes.length, 1);
    expect(provider.isLoaded, isTrue);

    provider.clear();

    expect(provider.mixes.isEmpty, isTrue);
    expect(provider.isLoaded, isFalse);
    expect(provider.isLoading, isFalse);

    provider.dispose();
  });
}
