import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/providers/database_health_provider.dart';
import 'package:hookahub/core/services/database_health_service.dart';
import 'package:hookahub/core/theme_provider.dart';
import 'package:hookahub/features/auth/auth_gate.dart';
import 'package:hookahub/features/auth/auth_provider.dart';
import 'package:hookahub/features/auth/login_page.dart';
import 'package:hookahub/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:hookahub/features/community/presentation/community_provider.dart';
import 'package:hookahub/features/favorites/presentation/favorites_provider.dart';
import 'package:hookahub/features/home/domain/home_stats.dart';
import 'package:hookahub/features/home/presentation/home_stats_provider.dart';
import 'package:hookahub/features/notifications/presentation/notifications_provider.dart';
import 'package:hookahub/features/onboarding/presentation/onboarding_provider.dart';
import 'package:hookahub/features/profile/presentation/profile_provider.dart';
import 'package:hookahub/features/search/presentation/search_provider.dart';
import 'package:hookahub/widgets/main_navigation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestableAuthProvider extends ChangeNotifier implements AuthProvider {
  bool _isAuth = false;
  final List<VoidCallback> _signOutListeners = [];

  @override
  bool get isAuthenticated => _isAuth;

  void setAuthenticated(bool value) {
    _isAuth = value;
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
  Future<void> signOut() async {
    for (final l in List<VoidCallback>.of(_signOutListeners)) {
      l();
    }
    setAuthenticated(false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestableOnboardingProvider extends ChangeNotifier
    implements OnboardingProvider {
  @override
  bool get isLoading => false;

  @override
  bool get hasCompleted => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDatabaseHealthService implements DatabaseHealthService {
  @override
  Future<bool> checkDatabaseConnection() async => true;
}

class MockProfileProvider extends ChangeNotifier implements ProfileProvider {
  @override
  bool get isLoaded => true;

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFavoritesProvider extends ChangeNotifier
    implements FavoritesProvider {
  @override
  bool get isLoaded => true;

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHomeStatsProvider extends ChangeNotifier implements HomeStatsProvider {
  @override
  HomeStats get stats => HomeStats.empty;

  @override
  bool get isLoading => false;

  @override
  bool get hasData => true;

  @override
  String? get error => null;

  @override
  Future<void> load({bool force = false}) async {}

  @override
  Future<void> refresh() async {}

  @override
  void cancelSubscription() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockNotificationsProvider extends ChangeNotifier
    implements NotificationsProvider {
  @override
  int get unreadCount => 0;

  @override
  Future<void> loadNotifications({bool refresh = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCatalogProvider extends ChangeNotifier implements CatalogProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCommunityProvider extends ChangeNotifier implements CommunityProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSearchProvider extends ChangeNotifier implements SearchProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthGate Declarative Navigation Tests', () {
    testWidgets(
      'muestra LoginPage cuando el usuario no está autenticado',
      (tester) async {
        final authProvider = TestableAuthProvider();
        final onboardingProvider = TestableOnboardingProvider();
        final themeProvider = ThemeProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<OnboardingProvider>.value(
                value: onboardingProvider,
              ),
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
            ],
            child: const MaterialApp(
              home: AuthGate(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(MainNavigationPage), findsNothing);
      },
    );

    testWidgets(
      'desmonta MainNavigationPage y muestra LoginPage limpiamente al cerrar sesión',
      (tester) async {
        final authProvider = TestableAuthProvider()..setAuthenticated(true);
        final onboardingProvider = TestableOnboardingProvider();
        final themeProvider = ThemeProvider();
        final healthProvider = DatabaseHealthProvider(
          healthService: FakeDatabaseHealthService(),
        );
        final profileProvider = MockProfileProvider();
        final favoritesProvider = MockFavoritesProvider();
        final homeStatsProvider = MockHomeStatsProvider();
        final notificationsProvider = MockNotificationsProvider();
        final catalogProvider = MockCatalogProvider();
        final communityProvider = MockCommunityProvider();
        final searchProvider = MockSearchProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<OnboardingProvider>.value(
                value: onboardingProvider,
              ),
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
              ChangeNotifierProvider<DatabaseHealthProvider>.value(
                value: healthProvider,
              ),
              ChangeNotifierProvider<ProfileProvider>.value(
                value: profileProvider,
              ),
              ChangeNotifierProvider<FavoritesProvider>.value(
                value: favoritesProvider,
              ),
              ChangeNotifierProvider<HomeStatsProvider>.value(
                value: homeStatsProvider,
              ),
              ChangeNotifierProvider<NotificationsProvider>.value(
                value: notificationsProvider,
              ),
              ChangeNotifierProvider<CatalogProvider>.value(
                value: catalogProvider,
              ),
              ChangeNotifierProvider<CommunityProvider>.value(
                value: communityProvider,
              ),
              ChangeNotifierProvider<SearchProvider>.value(
                value: searchProvider,
              ),
            ],
            child: const MaterialApp(
              home: AuthGate(),
            ),
          ),
        );
        // Bombear duración de transición
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Cuando auth.isAuthenticated es true, el AuthGate tiene como destino MainNavigationPage
        expect(authProvider.isAuthenticated, isTrue);
        expect(find.byType(MainNavigationPage), findsOneWidget);
        expect(find.byType(LoginPage), findsNothing);

        // Simulamos el cierre de sesión
        await authProvider.signOut();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Tras el cierre de sesión, debe renderizarse LoginPage sin rastros de barras
        expect(authProvider.isAuthenticated, isFalse);
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(MainNavigationPage), findsNothing);

        healthProvider.dispose();
      },
    );

    testWidgets(
      'cierra rutas modales y diálogos superpuestos en el rootNavigator automáticamente en signOut',
      (tester) async {
        final authProvider = TestableAuthProvider()..setAuthenticated(true);
        final onboardingProvider = TestableOnboardingProvider();
        final themeProvider = ThemeProvider();
        final healthProvider = DatabaseHealthProvider(
          healthService: FakeDatabaseHealthService(),
        );
        final profileProvider = MockProfileProvider();
        final favoritesProvider = MockFavoritesProvider();
        final homeStatsProvider = MockHomeStatsProvider();
        final notificationsProvider = MockNotificationsProvider();
        final catalogProvider = MockCatalogProvider();
        final communityProvider = MockCommunityProvider();
        final searchProvider = MockSearchProvider();
        final testNavKey = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<OnboardingProvider>.value(
                value: onboardingProvider,
              ),
              ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
              ChangeNotifierProvider<DatabaseHealthProvider>.value(
                value: healthProvider,
              ),
              ChangeNotifierProvider<ProfileProvider>.value(
                value: profileProvider,
              ),
              ChangeNotifierProvider<FavoritesProvider>.value(
                value: favoritesProvider,
              ),
              ChangeNotifierProvider<HomeStatsProvider>.value(
                value: homeStatsProvider,
              ),
              ChangeNotifierProvider<NotificationsProvider>.value(
                value: notificationsProvider,
              ),
              ChangeNotifierProvider<CatalogProvider>.value(
                value: catalogProvider,
              ),
              ChangeNotifierProvider<CommunityProvider>.value(
                value: communityProvider,
              ),
              ChangeNotifierProvider<SearchProvider>.value(
                value: searchProvider,
              ),
            ],
            child: MaterialApp(
              navigatorKey: testNavKey,
              home: AuthGate(navigatorKey: testNavKey),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(MainNavigationPage), findsOneWidget);

        // Simulamos abrir un diálogo modal en el rootNavigator
        showDialog<void>(
          context: testNavKey.currentContext!,
          builder: (_) => const AlertDialog(
            title: Text('Diálogo Modal Abierto'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Diálogo Modal Abierto'), findsOneWidget);

        // Al cerrar sesión, AuthGate debe limpiar el diálogo automáticamente
        await authProvider.signOut();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // El diálogo debe haberse cerrado y LoginPage debe ser visible
        expect(find.text('Diálogo Modal Abierto'), findsNothing);
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(MainNavigationPage), findsNothing);

        healthProvider.dispose();
      },
    );
  });
}
