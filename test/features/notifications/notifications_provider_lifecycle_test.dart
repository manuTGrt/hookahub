import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/data/supabase_service.dart';
import 'package:hookahub/core/models/notification.dart';
import 'package:hookahub/core/providers/database_health_provider.dart';
import 'package:hookahub/core/services/database_health_service.dart';
import 'package:hookahub/features/notifications/data/notifications_repository.dart';
import 'package:hookahub/features/notifications/presentation/notifications_provider.dart';

class FakeNotificationsRepository implements NotificationsRepository {
  bool activeUser = true;
  bool shouldThrow = false;
  int fetchCallCount = 0;
  final StreamController<AppNotification> streamController =
      StreamController<AppNotification>.broadcast();

  @override
  bool get hasActiveUser => activeUser;

  @override
  Future<List<AppNotification>> fetchNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    if (shouldThrow) {
      throw Exception('Fallo simulado en fetchNotifications');
    }
    fetchCallCount++;
    return [
      AppNotification(
        id: 'notif-1',
        userId: 'user-1',
        type: NotificationType.reviewOnMyMix,
        data: {'mix_id': '123'},
        isRead: false,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<int> getUnreadCount() async => 1;

  @override
  Future<bool> markAsRead(String notificationId) async => true;

  @override
  Future<bool> markAllAsRead() async => true;

  @override
  Future<bool> deleteNotification(String notificationId) async => true;

  @override
  Future<bool> deleteAllRead() async => true;

  @override
  Stream<AppNotification> subscribeToNotifications() {
    return streamController.stream;
  }
}

class FakeDatabaseHealthService implements DatabaseHealthService {
  @override
  Future<bool> checkDatabaseConnection() async => true;
}

class FakeSupabaseService implements SupabaseService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNotificationsRepository fakeRepo;
  late DatabaseHealthProvider healthProvider;

  setUp(() {
    fakeRepo = FakeNotificationsRepository();
    healthProvider = DatabaseHealthProvider(
      healthService: FakeDatabaseHealthService(),
    );
  });

  tearDown(() {
    fakeRepo.streamController.close();
    healthProvider.dispose();
  });

  group('NotificationsProvider Realtime & Session Lifecycle', () {
    test('Inicializa y carga datos si hasActiveUser es true', () async {
      final provider = NotificationsProvider(fakeRepo);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(provider.notifications.length, 1);
      expect(provider.unreadCount, 1);
      expect(fakeRepo.streamController.hasListener, isTrue);

      provider.dispose();
    });

    test('cancelSubscriptionsAndClear cancela Realtime y purga memoria', () async {
      final provider = NotificationsProvider(fakeRepo);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(provider.notifications.isNotEmpty, isTrue);
      expect(fakeRepo.streamController.hasListener, isTrue);

      // Simular cierre de sesión
      provider.cancelSubscriptionsAndClear();

      expect(provider.notifications.isEmpty, isTrue);
      expect(provider.unreadCount, 0);
      expect(fakeRepo.streamController.hasListener, isFalse);

      provider.dispose();
    });

    test('onUserAuthenticated reactiva Realtime y recarga notificaciones', () async {
      final provider = NotificationsProvider(fakeRepo);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Logout
      provider.cancelSubscriptionsAndClear();
      expect(provider.notifications.isEmpty, isTrue);

      // Login nuevo
      await provider.onUserAuthenticated();
      expect(provider.notifications.isNotEmpty, isTrue);
      expect(fakeRepo.streamController.hasListener, isTrue);

      provider.dispose();
    });

    test('dispose cancela suscripciones y unregister de listeners sin fugas', () async {
      final provider = NotificationsProvider(fakeRepo);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      provider.dispose();

      expect(fakeRepo.streamController.hasListener, isFalse);
    });

    test('onReconnected no dispara recargas si hasActiveUser es false', () async {
      fakeRepo.activeUser = false;
      final provider = NotificationsProvider(fakeRepo);

      final initialFetchCalls = fakeRepo.fetchCallCount;

      // Disparar evento de reconexión
      await healthProvider.retryConnection();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // No debe haber aumentado fetchCallCount
      expect(fakeRepo.fetchCallCount, initialFetchCalls);

      provider.dispose();
    });
  });

  group('NotificationsProvider Sealed State Transitions', () {
    test('inicia en NotificationsInitial o Loaded según activeUser', () async {
      fakeRepo.activeUser = false;
      final provider = NotificationsProvider(fakeRepo);

      expect(provider.state, isA<NotificationsInitial>());
      expect(provider.isLoading, isFalse);

      await provider.loadNotifications();

      expect(provider.state, isA<NotificationsLoaded>());
      final loaded = provider.state as NotificationsLoaded;
      expect(loaded.notifications.length, 1);
      expect(loaded.unreadCount, 1);
      expect(provider.notifications.length, 1);
      expect(provider.unreadCount, 1);

      provider.cancelSubscriptionsAndClear();
      expect(provider.state, isA<NotificationsInitial>());
      expect(provider.notifications, isEmpty);

      provider.dispose();
    });

    test('transita a NotificationsError si falla fetchNotifications', () async {
      fakeRepo.shouldThrow = true;
      final provider = NotificationsProvider(fakeRepo);

      await provider.loadNotifications();

      expect(provider.state, isA<NotificationsError>());
      final errorState = provider.state as NotificationsError;
      expect(errorState.message, 'Error al cargar notificaciones');
      expect(provider.error, 'Error al cargar notificaciones');

      provider.dispose();
    });
  });
}
