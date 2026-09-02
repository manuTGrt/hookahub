import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/providers/database_health_provider.dart';
import 'package:hookahub/core/services/database_health_service.dart';
import 'package:hookahub/features/history/data/history_repository.dart';
import 'package:hookahub/features/history/domain/visit_entry.dart';
import 'package:hookahub/features/history/presentation/history_provider.dart';

class FakeHistoryRepository implements HistoryRepository {
  int fetchCallCount = 0;

  @override
  Future<List<VisitEntry>> fetchRecentHistory({
    int days = 2,
    int limit = 100,
  }) async {
    fetchCallCount++;
    return [];
  }

  @override
  Future<int> getUniqueVisitedCount({int days = 2}) async {
    return 0;
  }

  @override
  Future<bool> recordMixView(String mixId) async {
    return true;
  }

  @override
  Future<bool> clearAllHistory() async {
    return true;
  }

  @override
  Future<int> clearOldHistory({int days = 7}) async {
    return 0;
  }
}

class FakeDatabaseHealthService implements DatabaseHealthService {
  @override
  Future<bool> checkDatabaseConnection() async => true;

  @override
  Future<bool> checkSupabaseService() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHealthProvider healthProvider;
  late FakeHistoryRepository fakeRepository;

  setUp(() {
    healthProvider = DatabaseHealthProvider(
      healthService: FakeDatabaseHealthService(),
    );
    fakeRepository = FakeHistoryRepository();
  });

  tearDown(() {
    healthProvider.dispose();
  });

  group('HistoryProvider lifecycle & memory leak prevention', () {
    test('dispose cancela la suscripción a onReconnected correctamente', () async {
      final historyProvider = HistoryProvider(fakeRepository);

      // Verificamos que el provider fue creado
      expect(historyProvider.isLoading, false);

      // Invocamos dispose de HistoryProvider
      historyProvider.dispose();

      // Disparamos un evento simulando reconexión a través del health provider
      // Si la suscripción no fue cancelada, se ejecutaría refresh() -> fetchRecentHistory
      await healthProvider.retryConnection();

      // Esperamos para asegurar que cualquier microtarea o timer asíncrono se procese
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Comprobamos que no se intentó recargar en el provider destruido
      expect(fakeRepository.fetchCallCount, 0);
    });

    test('clearOld ejecuta correctamente sin interferir con dispose', () async {
      final historyProvider = HistoryProvider(fakeRepository);

      final deleted = await historyProvider.clearOld(days: 7);
      expect(deleted, 0);

      // dispose debe poder llamarse limpiamente al nivel de clase
      expect(() => historyProvider.dispose(), returnsNormally);
    });
  });
}
