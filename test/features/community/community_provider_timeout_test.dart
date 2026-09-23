import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/models/mix.dart';
import 'package:hookahub/core/providers/database_health_provider.dart';
import 'package:hookahub/core/services/database_health_service.dart';
import 'package:hookahub/features/community/data/community_repository.dart';
import 'package:hookahub/features/community/presentation/community_provider.dart';

class FakeDatabaseHealthService implements DatabaseHealthService {
  @override
  Future<bool> checkDatabaseConnection() async => true;
}

class FakeTimeoutCommunityRepository implements CommunityRepository {
  bool shouldTimeout = true;

  @override
  Future<List<Mix>> fetchMixes({
    String orderBy = 'recent',
    int limit = 20,
    int offset = 0,
    String? tobaccoName,
    String? tobaccoBrand,
  }) async {
    if (shouldTimeout) {
      throw TimeoutException('Supabase query timeout');
    }
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHealthProvider healthProvider;

  setUp(() {
    healthProvider = DatabaseHealthProvider(
      healthService: FakeDatabaseHealthService(),
    );
  });

  tearDown(() {
    healthProvider.dispose();
  });

  group('CommunityProvider Timeout Handling', () {
    test('loadMixes() ante TimeoutException concluye carga y desactiva isLoading', () async {
      final repo = FakeTimeoutCommunityRepository();
      final provider = CommunityProvider(repo);

      expect(provider.isLoading, isFalse);

      await provider.loadMixes();

      // No debe quedarse en spinner perpetuo
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.error, contains('TimeoutException'));
      expect(provider.isLoaded, isFalse);

      provider.dispose();
    });

    test('loadMoreMixes() ante TimeoutException restablece isLoadingMore a false', () async {
      final repo = FakeTimeoutCommunityRepository();
      repo.shouldTimeout = false;
      final provider = CommunityProvider(repo);

      // Carga inicial
      await provider.loadMixes();
      expect(provider.isLoading, isFalse);

      // Scroll con timeout
      repo.shouldTimeout = true;
      await provider.loadMoreMixes();

      expect(provider.isLoadingMore, isFalse);

      provider.dispose();
    });
  });
}
