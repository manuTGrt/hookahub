import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../features/home/home_page.dart';
import '../features/catalog/catalog_page.dart';
import '../features/catalog/presentation/providers/catalog_provider.dart';
import '../features/catalog/domain/catalog_filters.dart';
import '../features/community/presentation/community_page.dart';
import '../features/community/presentation/community_provider.dart';
import '../features/community/domain/community_filters.dart';
import '../features/community/presentation/create_mix_page.dart';
import '../features/profile/profile_page.dart';
import '../features/profile/presentation/profile_provider.dart';
import '../core/providers/database_health_provider.dart';
import '../features/search/search_provider.dart';
import '../features/search/search_results_page.dart';
import 'notification_icon.dart';
import '../features/favorites/favorites_provider.dart';

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
          // En otras plataformas, pop estándar.
          MethodChannel('app_retain').invokeMethod('sendToBackground');
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
                              ).scaffoldBackgroundColor.withOpacity(0.95),
                              Theme.of(
                                context,
                              ).scaffoldBackgroundColor.withOpacity(0.95),
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
                            ? Theme.of(context).primaryColor.withOpacity(0.2)
                            : Theme.of(context).primaryColor.withOpacity(0.3),
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
                                      ).primaryColor.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.2),
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
                                        onSubmitted: (value) async {
                                          if (value.trim().isEmpty) return;

                                          // Cerrar teclado
                                          FocusScope.of(context).unfocus();

                                          // Navegar a la página de búsqueda
                                          final searchProvider = context
                                              .read<SearchProvider>();
                                          await searchProvider.search(value);

                                          if (!mounted) return;

                                          // Navegar a la página de resultados
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => SearchResultsPage(
                                                query: value,
                                                tobaccos: searchProvider
                                                    .tobaccoResults,
                                                mixes:
                                                    searchProvider.mixResults,
                                              ),
                                            ),
                                          );

                                          // Resetear el estado de búsqueda
                                          setState(() {
                                            _isSearching = false;
                                            _searchController.clear();
                                          });
                                        },
                                        decoration: InputDecoration(
                                          hintText:
                                              'Buscar tabacos, mezclas...',
                                          filled: true,
                                          fillColor: isDark
                                              ? Theme.of(context).cardColor
                                              : Colors.white.withOpacity(0.95),
                                          prefixIcon: Icon(
                                            Icons.search,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          suffixIcon:
                                              _searchController.text.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.close),
                                                  onPressed: () {
                                                    setState(() {
                                                      _searchController.clear();
                                                    });
                                                    _searchFocusNode
                                                        .requestFocus();
                                                  },
                                                )
                                              : null,
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
                                              color: Theme.of(
                                                context,
                                              ).dividerColor.withOpacity(0.3),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Theme.of(
                                                context,
                                              ).dividerColor.withOpacity(0.2),
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
                                                        .withOpacity(0.3),
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
                                          ? Theme.of(
                                              context,
                                            ).primaryColor.withOpacity(0.2)
                                          : Colors.white.withOpacity(0.2),
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
                                // Botón de búsqueda
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.2),
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
                                        // Enfocar tras el siguiente frame para asegurar que el widget exista
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              _searchFocusNode.requestFocus();
                                            });
                                      } else {
                                        _searchController.clear();
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
                                          ? Theme.of(
                                              context,
                                            ).primaryColor.withOpacity(0.2)
                                          : Colors.white.withOpacity(0.2),
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
          children: List.generate(_pageBuilders.length, (index) {
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
        ),

        // Barra de navegación inferior personalizada
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
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
    // Suscribirse a reconexión para refrescar la pestaña visible
    final health = context.read<DatabaseHealthProvider>();
    _reconnectedSub = health.onReconnected.listen((_) {
      if (!mounted) return;
      switch (_currentIndex) {
        case 1: // Catálogo
          unawaited(context.read<CatalogProvider>().refresh());
          break;
        case 2: // Comunidad
          unawaited(context.read<CommunityProvider>().refresh());
          break;
        case 3: // Perfil
          // Si hay un provider de perfil con load(), refrescar aquí
          final maybeProfile = context.read<ProfileProvider?>();
          if (maybeProfile != null) {
            unawaited(maybeProfile.load());
          }
          break;
        default:
          break;
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
        // Si el Navigator de la pestaña aún no existe, crearlo ahora (lazy)
        if (_navigatorCache[index] == null) {
          _navigatorCache[index] = _buildTabNavigator(index);
        }
        setState(() {
          _currentIndex = index;
        });
        // Actualizar el estado de back/título según el stack del nuevo tab
        _updateBackAndTitle();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).primaryColor.withOpacity(0.1)
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
                    ).textTheme.bodyMedium?.color?.withOpacity(0.6),
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
                      ).textTheme.bodyMedium?.color?.withOpacity(0.6),
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
          break;
        default:
          break;
      }
    });
  }

  Widget _buildTabNavigator(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      observers: [
        // Observer para detectar cambios en el stack de navegación
        _TabNavigatorObserver(
          onNavigationChanged: () {
            // Solo actualizar si este es el tab activo
            if (_currentIndex == index && mounted) {
              // Usar addPostFrameCallback para evitar llamar setState durante build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _updateBackAndTitle();
                }
              });
            }
          },
        ),
      ],
      onGenerateInitialRoutes: (_, __) {
        // Primera vez que se construye este Navigator: disparar first-load
        _onTabFirstEnter(index);
        return [MaterialPageRoute(builder: _pageBuilders[index])];
      },
    );
  }

  void _updateBackAndTitle() {
    final nav = _navigatorKeys[_currentIndex].currentState;
    final canPop = nav?.canPop() ?? false;

    // Detectar si estamos en una ruta que no debe mostrar la barra superior
    // TobaccoDetailPage se abre directamente desde CatalogPage (push normal)
    // por lo que no tendrá _overrideTitle establecido (solo lo usan pushInCurrentTab)
    bool hideBar = false;
    if (canPop && _overrideTitles[_currentIndex] == null) {
      hideBar = true;
    }

    setState(() {
      _showBack = canPop;
      _hideTopBar = hideBar;
      if (!canPop) {
        _overrideTitles[_currentIndex] = null;
      }
    });
  }

  /// Empuja una página en la pestaña actual mostrando back y título en la barra superior
  void pushInCurrentTab(String title, Widget page) {
    // Asegurar Navigator activo
    if (_navigatorCache[_currentIndex] == null) {
      _navigatorCache[_currentIndex] = _buildTabNavigator(_currentIndex);
    }
    final nav = _navigatorKeys[_currentIndex].currentState;
    setState(() {
      _overrideTitles[_currentIndex] = title;
      _showBack = true;
    });
    nav?.push(MaterialPageRoute(builder: (_) => page)).then((_) {
      // Al volver, actualizar estado
      _updateBackAndTitle();
    });
  }
}

/// Observer para detectar cambios en la navegación
class _TabNavigatorObserver extends NavigatorObserver {
  final VoidCallback onNavigationChanged;

  _TabNavigatorObserver({required this.onNavigationChanged});

  @override
  void didPush(Route route, Route? previousRoute) {
    onNavigationChanged();
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    onNavigationChanged();
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    onNavigationChanged();
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    onNavigationChanged();
  }
}
