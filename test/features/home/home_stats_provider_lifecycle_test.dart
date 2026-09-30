import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/features/home/data/home_stats_repository.dart';
import 'package:hookahub/features/home/domain/home_stats.dart';
import 'package:hookahub/features/home/presentation/home_stats_provider.dart';

class FakeHomeStatsRepository implements HomeStatsRepository {
  final StreamController<HomeStats> controller =
      StreamController<HomeStats>.broadcast();

  @override
  Future<HomeStats> fetchStats() async {
    return const HomeStats(
      tobaccos: 20,
      mixes: 10,
      users: 30,
    );
  }

  @override
  Stream<HomeStats> streamStats() {
    return controller.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HomeStatsProvider cancelSubscription detiene la escucha del stream', () async {
    final fakeRepo = FakeHomeStatsRepository();
    final provider = HomeStatsProvider(fakeRepo);

    await provider.load();
    expect(fakeRepo.controller.hasListener, isTrue);

    // Cancelar suscripción en logout
    provider.cancelSubscription();
    expect(fakeRepo.controller.hasListener, isFalse);

    provider.dispose();
    fakeRepo.controller.close();
  });

  test('HomeStatsProvider transita por estados sellados (Initial -> Loading -> Loaded)', () async {
    final fakeRepo = FakeHomeStatsRepository();
    final provider = HomeStatsProvider(fakeRepo);

    expect(provider.state, isA<HomeStatsInitial>());
    expect(provider.isLoading, isFalse);

    final future = provider.load();
    expect(provider.state, isA<HomeStatsLoading>());
    expect(provider.isLoading, isTrue);

    await future;
    expect(provider.state, isA<HomeStatsLoaded>());
    expect((provider.state as HomeStatsLoaded).stats.tobaccos, equals(20));
    expect(provider.isLoading, isFalse);
    expect(provider.hasData, isTrue);

    provider.dispose();
    fakeRepo.controller.close();
  });
}
