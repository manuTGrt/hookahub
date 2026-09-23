import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/models/mix.dart';
import 'package:hookahub/features/mixes/domain/user_mixes_repository.dart';
import 'package:hookahub/features/mixes/presentation/user_mixes_provider.dart';

class TimeoutUserMixesRepository implements UserMixesRepository {
  bool shouldTimeout = true;

  @override
  Future<List<Mix>> fetchMyMixes({int limit = 20, int offset = 0}) async {
    if (shouldTimeout) {
      throw TimeoutException('Supabase query timeout');
    }
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserMixesProvider Timeout Handling', () {
    test('load() ante TimeoutException desactiva isLoading y registra error', () async {
      final repo = TimeoutUserMixesRepository();
      final provider = UserMixesProvider(repo);

      expect(provider.isLoading, isFalse);

      await provider.load();

      // No debe quedarse en spinner perpetuo
      expect(provider.isLoading, isFalse);
      expect(provider.error, equals('No se pudieron cargar tus mezclas'));
      expect(provider.isLoaded, isFalse);
      expect(provider.mixes, isEmpty);

      provider.dispose();
    });

    test('loadMore() ante TimeoutException desactiva isLoadingMore', () async {
      final repo = TimeoutUserMixesRepository();
      repo.shouldTimeout = false;
      final provider = UserMixesProvider(repo);

      // Carga inicial exitosa
      await provider.load();
      expect(provider.isLoading, isFalse);

      // Siguiente carga con timeout
      repo.shouldTimeout = true;
      await provider.loadMore();

      expect(provider.isLoadingMore, isFalse);

      provider.dispose();
    });
  });
}
