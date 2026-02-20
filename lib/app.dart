import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'core/providers/database_health_provider.dart';
import 'core/services/database_health_service.dart';
import 'features/auth/auth_gate.dart';
import 'features/favorites/favorites_provider.dart';
import 'features/favorites/favorites_repository.dart';
import 'features/auth/auth_provider.dart';
import 'core/data/supabase_service.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/profile/presentation/profile_provider.dart';
import 'features/community/data/community_repository.dart';
import 'features/community/presentation/community_provider.dart';
import 'features/mixes/presentation/user_mixes_provider.dart';
import 'features/mixes/data/user_mixes_repository.dart';
import 'features/history/presentation/history_provider.dart';
import 'features/history/data/history_repository.dart';
import 'features/home/data/home_stats_repository.dart';
import 'features/home/presentation/home_stats_provider.dart';
import 'features/search/search_provider.dart';
import 'features/catalog/data/tobacco_repository.dart';
import 'features/catalog/presentation/providers/catalog_provider.dart';
import 'features/notifications/data/notifications_repository.dart';
import 'features/notifications/presentation/notifications_provider.dart';
import 'widgets/database_banner.dart';
import 'l10n/app_localizations.dart';

class HookahubApp extends StatelessWidget {
  const HookahubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => DatabaseHealthProvider(
            healthService: DatabaseHealthService(SupabaseService()),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              HomeStatsProvider(HomeStatsRepository(SupabaseService())),
        ),
        ChangeNotifierProvider(
          create: (_) => FavoritesProvider(FavoritesRepository()),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider(SupabaseService())),
        ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
          create: (context) => ProfileProvider(
            repository: ProfileRepository(SupabaseService()),
            auth: context.read<AuthProvider>(),
          ),
          update: (context, auth, previous) =>
              previous ??
              ProfileProvider(
                repository: ProfileRepository(SupabaseService()),
                auth: auth,
              ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              CommunityProvider(CommunityRepository(SupabaseService())),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              UserMixesProvider(UserMixesRepository(SupabaseService())),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryProvider(HistoryRepository(SupabaseService())),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchProvider(
            tobaccoRepository: TobaccoRepository(SupabaseService()),
            communityRepository: CommunityRepository(SupabaseService()),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => CatalogProvider(TobaccoRepository(SupabaseService())),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              NotificationsProvider(NotificationsRepository(SupabaseService())),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Hookahub',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AuthGate(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              return Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  const DatabaseConnectionBanner(),
                ],
              );
            },
            // Localizations
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('es', ''), // Set Spanish as default
          );
        },
      ),
    );
  }
}
