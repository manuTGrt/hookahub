import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../features/home/presentation/home_page.dart';
import '../features/catalog/presentation/catalog_page.dart';
import '../features/catalog/presentation/providers/catalog_provider.dart';
import '../features/catalog/domain/catalog_filters.dart';
import '../features/community/presentation/community_page.dart';
import '../features/community/presentation/community_provider.dart';
import '../features/community/domain/community_filters.dart';
import '../features/community/presentation/create_mix_page.dart';
import '../features/catalog/presentation/request_tobacco_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/profile/presentation/profile_provider.dart';
import '../core/providers/database_health_provider.dart';
import '../features/search/presentation/search_provider.dart';
import '../features/search/presentation/search_results_page.dart';
import '../features/search/domain/models/search_suggestion.dart';
import '../features/search/presentation/providers/search_suggestions_provider.dart';
import '../features/search/presentation/widgets/search_suggestions_overlay.dart';
import '../features/catalog/presentation/tobacco_detail_page.dart';
import '../features/community/presentation/mix_detail_page.dart';
import 'notification_icon.dart';
import '../features/favorites/presentation/favorites_provider.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => MainNavigationPageState();

  /// Helper estático para obtener el estado desde cualquier parte del árbol
  static MainNavigationPageState? of(BuildContext context) {
    return context.findAncestorStateOfType<MainNavigationPageState>();
  }
}

class MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 0;
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );
  late final List<_TabNavigatorObserver> _tabObservers = List.generate(
    4,
    (index) => _TabNavigatorObserver(
      onNavigationChanged: () {
        if (_currentIndex == index && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _updateBackAndTitle();
            }
          });
        }
      },
    ),
  );
  final Expando<String> _routeOverrideTitles = Expando<String>(
    'routeOverrideTitles',
  );
  final List<Widget?> _navigatorCache = List<Widget?>.filled(4, null);
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  StreamSubscription<void>? _reconnectedSub;
  bool _showBack = false;
  // Título anulado por pestaña para subpáginas dentro del mismo tab
  final List<String?> _overrideTitles = List<String?>.filled(4, null);
  bool _hideTopBar = false;

  /// Navega al catálogo (tab 1) y aplica un filtro de ordenamiento
  void navigateToCatalogWithFilter(SortOption sortOption) {
    // Asegurar que el Navigator de Catálogo existe
    if (_navigatorCache[1] == null) {
      _navigatorCache[1] = _buildTabNavigator(1);
    }
    setState(() {
      _currentIndex = 1; // Índice del catálogo
    });
    // Aplicar el filtro después de que se renderice la página
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final catalogProvider = context.read<CatalogProvider>();
        catalogProvider.setSortOption(sortOption);
        if (!catalogProvider.hasAttemptedLoad) {
          // Si aún no hay datos cargados, forzar la primera carga
          unawaited(catalogProvider.refresh());
        }
      }
    });
  }

  /// Navega a la comunidad (tab 2) y aplica un filtro de ordenamiento
  void navigateToCommunityWithFilter(CommunitySortOption sortOption) {
    // Asegurar que el Navigator de Comunidad existe
    if (_navigatorCache[2] == null) {
      _navigatorCache[2] = _buildTabNavigator(2);
    }
    setState(() {
      _currentIndex = 2; // Índice de comunidad
    });
    // Aplicar el filtro después de que se renderice la página
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final communityProvider = context.read<CommunityProvider>();
        communityProvider.setSortOption(sortOption);
        if (!communityProvider.isLoaded) {
          // Si aún no hay datos cargados, forzar la primera carga
          unawaited(communityProvider.loadMixes());
        }
      }
    });
  }

  Future<void> _executeSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    // Cerrar teclado
    FocusScope.of(context).unfocus();

    // Capturar providers antes del gap asíncrono
    final suggestionsProvider = context.read<SearchSuggestionsProvider>();
    final searchProvider = context.read<SearchProvider>();

    // Guardar en historial local
    await suggestionsProvider.saveSearch(cleanQuery);

    // Ejecutar búsqueda global completa
    await searchProvider.search(cleanQuery);

    if (!mounted || !context.mounted) return;

    // Resetear modo de búsqueda y limpiar input
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    suggestionsProvider.reset();

    // Navegar a la página de resultados
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchResultsPage(
          query: cleanQuery,
          tobaccos: searchProvider.tobaccoResults,
          mixes: searchProvider.mixResults,
        ),
      ),
    );
  }

  Future<void> _handleSuggestionSelected(SearchSuggestion suggestion) async {
    FocusScope.of(context).unfocus();

    final suggestionsProvider = context.read<SearchSuggestionsProvider>();
    await suggestionsProvider.saveSearch(suggestion.title);

    if (!mounted || !context.mounted) return;

    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    suggestionsProvider.reset();

    if (suggestion.isTobacco) {
      if (suggestion.tobacco != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TobaccoDetailPage(tobacco: suggestion.tobacco!),
          ),
        );
      } else {
        await _executeSearch(suggestion.title);
      }
    } else if (suggestion.isMix) {
      if (suggestion.mix != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MixDetailPage(mix: suggestion.mix!),
          ),
        );
      } else {
        await _executeSearch(suggestion.title);
      }
    }
  }

  final List<WidgetBuilder> _pageBuilders = [
    (_) => const HomePage(), // Index 0: Home
    (_) => const CatalogPage(), // Index 1: Catálogo
    (_) => const CommunityPage(), // Index 2: Comunidad
    (_) => const ProfilePage(), // Index 3: Perfil
  ];

  final List<String> _pageTitles = [
    'Hookahub',
    'Catálogo',
    'Comunidad',
    'Perfil',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Siempre a false para que el Navigator principal NO haga pop de la ruta de la aplicación.
    // En lugar de SystemNavigator.pop(), minimizaremos la aplicación para que Android no la destruya.
    final bool canSystemPop = false;

    return PopScope(
      canPop: canSystemPop,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        if (_isSearching) {
          setState(() {
            _isSearching = false;
            _searchController.clear();
          });
          context.read<SearchSuggestionsProvider>().reset();
          FocusScope.of(context).unfocus();
          return;
        }

        final nav = _navigatorKeys[_currentIndex].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          // Actualizamos titulo y flecha para la pestaña a la que volvemos
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _updateBackAndTitle();
          });
        } else {
          // Estamos en Home y no hay atrás posible.
          // En Android, enviar la app a segundo plano manteniendo el motor.
          if (Platform.isAndroid) {
            MethodChannel('app_retain').invokeMethod('sendToBackground');
          }
        }
      },
      child: Scaffold(
        // Header superior personalizado - ocultarlo cuando sea necesario
        appBar: _hideTopBar
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(70),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              Theme.of(
                                context,
                              ).scaffoldBackgroundColor.withValues(alpha: 0.95),
                              Theme.of(
                                context,
                              ).scaffoldBackgroundColor.withValues(alpha: 0.95),
                            ]
                          : [
                              Theme.of(context).primaryColor,
                              Theme.of(context).colorScheme.secondary,
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.2)
                            : Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        children: [
                          if (_showBack) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Theme.of(
                                        context,
                                      ).primaryColor.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: isDark
                                      ? Theme.of(context).primaryColor
                                      : Colors.white,
                                  size: 24,
                                ),
                                onPressed: () {
                                  if (_isSearching) {
                                    setState(() {
                                      _isSearching = false;
                                      _searchController.clear();
                                    });
                                    context
                                        .read<SearchSuggestionsProvider>()
                                        .reset();
                                    FocusScope.of(context).unfocus();
                                    return;
                                  }
                                  final nav = _navigatorKeys[_currentIndex]
                                      .currentState;
                                  if (nav != null && nav.canPop()) {
                                    nav.pop();
                                  }
                                  // Actualizar estado del back según el stack
                                  _updateBackAndTitle();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          // Área izquierda: título o campo de búsqueda (animado)
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final fade = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut,
                                );
                                final slide = Tween<Offset>(
                                  begin: const Offset(0.05, 0),
                                  end: Offset.zero,
                                ).animate(animation);
                                return FadeTransition(
                                  opacity: fade,
                                  child: SlideTransition(
                                    position: slide,
                                    child: child,
                                  ),
                                );
                              },
                              child: _isSearching
                                  ? SizedBox(
                                      key: const ValueKey('search-field'),
                                      height: 44,
                                      child: TextField(
                                        focusNode: _searchFocusNode,
                                        controller: _searchController,
                                        textInputAction: TextInputAction.search,
                                        onChanged: (value) {
                                          context
                                              .read<SearchSuggestionsProvider>()
                                              .onQueryChanged(value);
                                        },
                                        onSubmitted: (value) {
                                          _executeSearch(value);
                                        },
                                        decoration: InputDecoration(
                                          hintText:
                                              'Buscar tabacos, mezclas...',
                                          filled: true,
                                          fillColor: isDark
                                              ? Theme.of(context).cardColor
                                              : Colors.white.withValues(
                                                  alpha: 0.95,
                                                ),
                                          prefixIcon: Icon(
                                            Icons.search,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          suffixIcon:
                                              ValueListenableBuilder<
                                                TextEditingValue
                                              >(
                                                valueListenable:
                                                    _searchController,
                                                builder: (context, value, _) {
                                                  if (value.text.isEmpty) {
                                                    return const SizedBox.shrink();
                                                  }
                                                  return IconButton(
                                                    icon: const Icon(
                                                      Icons.close,
                                                    ),
                                                    onPressed: () {
                                                      _searchController.clear();
                                                      context
                                                          .read<
                                                            SearchSuggestionsProvider
                                                          >()
                                                          .onQueryChanged('');
                                                      _searchFocusNode
                                                          .requestFocus();
                                                    },
                                                  );
                                                },
                                              ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .dividerColor
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .dividerColor
                                                  .withValues(alpha: 0.2),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              width: 1.2,
                                            ),
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                    )
                                  : Align(
                                      key: const ValueKey('title'),
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _overrideTitles[_currentIndex] ??
                                            _pageTitles[_currentIndex],
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Theme.of(context).primaryColor
                                              : Colors.white,
                                          letterSpacing: 1.2,
                                          shadows: isDark
                                              ? [
                                                  Shadow(
                                                    color: Theme.of(context)
                                                        .primaryColor
                                                        .withValues(alpha: 0.3),
                                                    blurRadius: 2,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Iconos de la derecha (ocultos cuando hay botón de volver)
                          if (!_showBack)
                            Row(
                              children: [
                                // Botón de crear mezcla (solo en página de comunidad)
                                if (_currentIndex == 2 && !_isSearching) ...[
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Theme.of(context).primaryColor
                                                .withValues(alpha: 0.2)
                                          : Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.add,
                                        color: isDark
                                            ? Theme.of(context).primaryColor
                                            : Colors.white,
                                        size: 26,
                                      ),
                                      onPressed: () {
                                        // Navegar a la página de crear mezcla
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => CreateMixPage(
                                              currentUser: 'Yo',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                // Botón de solicitar tabaco (solo en pestaña Catálogo)
                                if (_currentIndex == 1 && !_isSearching) ...[
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Theme.of(context).primaryColor
                                                .withValues(alpha: 0.2)
                                          : Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      tooltip: 'Solicitar un tabaco',
                                      icon: Icon(
                                        Icons.playlist_add_rounded,
                                        color: isDark
                                            ? Theme.of(context).primaryColor
                                            : Colors.white,
                                        size: 26,
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const RequestTobaccoPage(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                // Botón de búsqueda
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Theme.of(
                                            context,
                                          ).primaryColor.withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      transitionBuilder: (child, animation) =>
                                          RotationTransition(
                                            turns: Tween<double>(
                                              begin: 0.85,
                                              end: 1,
                                            ).animate(animation),
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          ),
                                      child: Icon(
                                        _isSearching
                                            ? Icons.close
                                            : Icons.search,
                                        key: ValueKey(_isSearching),
                                        color: isDark
                                            ? Theme.of(context).primaryColor
                                            : Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isSearching = !_isSearching;
                                      });
                                      if (_isSearching) {
                                        context
                                            .read<SearchSuggestionsProvider>()
                                            .loadRecentSearches();
                                        // Enfocar tras el siguiente frame para asegurar que el widget exista
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              _searchFocusNode.requestFocus();
                                            });
                                      } else {
                                        _searchController.clear();
                                        context
                                            .read<SearchSuggestionsProvider>()
                                            .reset();
                                        FocusScope.of(context).unfocus();
                                      }
                                    },
                                  ),
                                ),

                                if (!_isSearching) const SizedBox(width: 8),

                                // Botón de notificaciones
                                if (!_isSearching)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Theme.of(context).primaryColor
                                                .withValues(alpha: 0.2)
                                          : Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: NotificationIcon(isDark: isDark),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

        // Contenido con Navigator por pestaña y montaje bajo demanda
        body: Stack(
          children: [
            ...List.generate(_pageBuilders.length, (index) {
              final bool isActive = _currentIndex == index;
              // Construir Navigator solo cuando el tab se activa por primera vez
              _navigatorCache[index] ??= index == 0
                  ? _buildTabNavigator(index)
                  : null;
              final Widget child =
                  _navigatorCache[index] ?? const SizedBox.shrink();
              return Offstage(
                offstage: !isActive,
                child: TickerMode(enabled: isActive, child: child),
              );
            }),
            if (_isSearching)
              Positioned.fill(
                child: SearchSuggestionsOverlay(
                  onTermSelected: (term) {
                    _searchController.text = term;
                    _executeSearch(term);
                  },
                  onSuggestionSelected: (suggestion) {
                    _handleSuggestionSelected(suggestion);
                  },
                  onFillQuery: (fill) {
                    _searchController.text = fill;
                    _searchController.selection = TextSelection.fromPosition(
                      TextPosition(offset: fill.length),
                    );
                    context
                        .read<SearchSuggestionsProvider>()
                        .onQueryChanged(fill);
                  },
                ),
              ),
          ],
        ),

        // Barra de navegación inferior personalizada
        bottomNavigationBar: _isSearching
            ? null
            : Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _buildNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      label: 'Home',
                      index: 0,
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      icon: Icons.local_fire_department_outlined,
                      activeIcon: Icons.local_fire_department,
                      label: 'Catálogo',
                      index: 1,
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      icon: Icons.people_outline,
                      activeIcon: Icons.people,
                      label: 'Comunidad',
                      index: 2,
                    ),
                  ),
                  Expanded(
                    child: _buildNavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: 'Perfil',
                      index: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Suscribirse a reconexión para refrescar la pestaña visible sin duplicar listeners propios
    final health = context.read<DatabaseHealthProvider>();
    _reconnectedSub = health.onReconnected.listen((_) {
      if (!mounted) return;
      switch (_currentIndex) {
        case 1: // Catálogo (no tiene listener propio a onReconnected)
          unawaited(context.read<CatalogProvider>().refresh());
          break;
        case 2: // Comunidad (solo si aún estaba en estado inicial al reconectar)
          final community = context.read<CommunityProvider>();
          if (community.state is CommunityInitial) {
            unawaited(community.refresh());
          }
          break;
        case 3: // Perfil (ProfileProvider ya gestiona su propia reconexión)
          final maybeProfile = context.read<ProfileProvider?>();
          if (maybeProfile != null &&
              !maybeProfile.isLoaded &&
              !maybeProfile.isLoading) {
            unawaited(maybeProfile.load());
          }
          break;
        default:
          break;
      }
    });

    // Cargar dependencias globales críticas al iniciar la app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final profileProvider = context.read<ProfileProvider>();
      if (!profileProvider.isLoaded) {
        unawaited(profileProvider.load());
      }

      final favProvider = context.read<FavoritesProvider>();
      if (!favProvider.isLoaded) {
        unawaited(favProvider.load());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _reconnectedSub?.cancel();
    super.dispose();
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final bool isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (_currentIndex == index) {
          if (index == 1) {
            context.read<CatalogProvider>().scrollToTop();
          }
          return;
        }

        // Si el Navigator de la pestaña aún no existe, crearlo ahora (lazy)
        if (_navigatorCache[index] == null) {
          _navigatorCache[index] = _buildTabNavigator(index);
        }
        setState(() {
          _currentIndex = index;
        });
        if (index == 3) {
          unawaited(context.read<ProfileProvider>().refreshMixesCount());
        }
        // Actualizar el estado de back/título según el stack del nuevo tab
        _updateBackAndTitle();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive
                  ? Theme.of(context).primaryColor
                  : Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive
                    ? Theme.of(context).primaryColor
                    : Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTabFirstEnter(int index) {
    // Difere las cargas a después del frame actual para evitar notificar durante build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (index) {
        case 1: // Catálogo
          final catalogProvider = context.read<CatalogProvider>();
          if (!catalogProvider.hasAttemptedLoad) {
            // Primera carga explícita aunque el sort ya sea 'newest'
            unawaited(catalogProvider.refresh());
          }
          break;
        case 2: // Comunidad
          final communityProvider = context.read<CommunityProvider>();
          if (!communityProvider.isLoaded) {
            // Primera carga explícita aunque el sort ya sea 'newest'
            unawaited(communityProvider.loadMixes());
          }
          break;
        case 3: // Perfil
          final profileProvider = context.read<ProfileProvider>();
          if (!profileProvider.isLoaded) {
            unawaited(profileProvider.load());
            final fav = context.read<FavoritesProvider>();
            if (!fav.isLoaded) {
              unawaited(fav.load());
            }
          }
          unawaited(profileProvider.refreshMixesCount());
          break;
        default:
          break;
      }
    });
  }

  Widget _buildTabNavigator(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      observers: [_tabObservers[index]],
      onGenerateInitialRoutes: (_, _) {
        // Primera vez que se construye este Navigator: disparar first-load
        _onTabFirstEnter(index);
        return [MaterialPageRoute(builder: _pageBuilders[index])];
      },
    );
  }

  void _updateBackAndTitle() {
    final nav = _navigatorKeys[_currentIndex].currentState;
    final canPop = nav?.canPop() ?? false;
    final topPageRoute = _tabObservers[_currentIndex].topPageRoute;
    final activeOverrideTitle =
        (canPop && topPageRoute != null) ? _routeOverrideTitles[topPageRoute] : null;

    // Si estamos en una subruta que NO fue abierta mediante pushInCurrentTab
    // (ej. MixDetailPage, TobaccoDetailPage o CreateMixPage abierta desde
    // Favoritas, Mis Mezclas, Historial, Comunidad o Catálogo), ocultamos la
    // barra superior global porque esa pantalla ya renderiza su propia cabecera
    // y su propio botón de retroceso, evitando dobles flechas hacia atrás.
    final bool hideBar = canPop && activeOverrideTitle == null;

    setState(() {
      _showBack = canPop;
      _hideTopBar = hideBar;
      _overrideTitles[_currentIndex] = activeOverrideTitle;
    });
  }

  /// Empuja una página en la pestaña actual mostrando back y título en la barra superior
  void pushInCurrentTab(String title, Widget page) {
    // Asegurar Navigator activo
    if (_navigatorCache[_currentIndex] == null) {
      _navigatorCache[_currentIndex] = _buildTabNavigator(_currentIndex);
    }
    final nav = _navigatorKeys[_currentIndex].currentState;
    final route = MaterialPageRoute<void>(
      settings: RouteSettings(name: title),
      builder: (_) => page,
    );
    _routeOverrideTitles[route] = title;

    setState(() {
      _overrideTitles[_currentIndex] = title;
      _showBack = true;
      _hideTopBar = false;
    });

    nav?.push(route).then((_) {
      if (mounted) {
        _updateBackAndTitle();
      }
    });
  }
}

/// Observer para detectar cambios en la pila de páginas (`PageRoute`) de cada pestaña
class _TabNavigatorObserver extends NavigatorObserver {
  _TabNavigatorObserver({required this.onNavigationChanged});

  final VoidCallback onNavigationChanged;
  final List<PageRoute<dynamic>> _pageRoutes = <PageRoute<dynamic>>[];

  PageRoute<dynamic>? get topPageRoute =>
      _pageRoutes.isNotEmpty ? _pageRoutes.last : null;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic>) {
      _pageRoutes.add(route);
    }
    onNavigationChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic>) {
      _pageRoutes.remove(route);
    }
    onNavigationChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic>) {
      _pageRoutes.remove(route);
    }
    onNavigationChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute is PageRoute<dynamic>) {
      final idx = _pageRoutes.indexOf(oldRoute);
      if (idx != -1) {
        if (newRoute is PageRoute<dynamic>) {
          _pageRoutes[idx] = newRoute;
        } else {
          _pageRoutes.removeAt(idx);
        }
      } else if (newRoute is PageRoute<dynamic>) {
        _pageRoutes.add(newRoute);
      }
    } else if (newRoute is PageRoute<dynamic>) {
      _pageRoutes.add(newRoute);
    }
    onNavigationChanged();
  }
}
