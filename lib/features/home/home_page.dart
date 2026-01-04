import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../favorites/favorites_page.dart';
import '../catalog/domain/catalog_filters.dart';
import '../community/domain/community_filters.dart';
import '../../widgets/main_navigation.dart';
import 'presentation/home_stats_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final NumberFormat _numberFormat = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeStatsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final scaleFactor = textScaler.scale(1.0);
    
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección de bienvenida
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.1), 
                    Theme.of(context).primaryColor.withOpacity(0.05)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Bienvenido a Hookahub! 💨',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Descubre, comparte y califica las mejores mezclas de tabaco',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Accesos rápidos
            Text(
              'Accesos rápidos',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.headlineSmall?.color,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Carrusel horizontal de accesos rápidos con fades laterales
            _QuickAccessCarousel(scaleFactor: scaleFactor, buildCard: (context) {
              return [
                _buildQuickAccessCard(
                  context,
                  scaleFactor: scaleFactor,
                  icon: Icons.local_fire_department,
                  title: 'Tabacos Populares',
                  subtitle: 'Los más valorados',
                  color: pastelBlue,
                  onTap: () {
                    final mainNav = MainNavigationPage.of(context);
                    if (mainNav != null) {
                      mainNav.navigateToCatalogWithFilter(SortOption.mostPopular);
                    }
                  },
                ),
                _buildQuickAccessCard(
                  context,
                  scaleFactor: scaleFactor,
                  icon: Icons.star,
                  title: 'Mezclas Top',
                  subtitle: 'Mejor calificadas',
                  color: pastelYellow,
                  onTap: () {
                    final mainNav = MainNavigationPage.of(context);
                    if (mainNav != null) {
                      mainNav.navigateToCommunityWithFilter(CommunitySortOption.topRated);
                    }
                  },
                ),
                _buildQuickAccessCard(
                  context,
                  scaleFactor: scaleFactor,
                  icon: Icons.new_releases,
                  title: 'Novedades',
                  subtitle: 'Recién agregados',
                  color: pastelPink,
                  onTap: () {
                    final mainNav = MainNavigationPage.of(context);
                    if (mainNav != null) {
                      mainNav.navigateToCatalogWithFilter(SortOption.newest);
                    }
                  },
                ),
                _buildQuickAccessCard(
                  context,
                  scaleFactor: scaleFactor,
                  icon: Icons.favorite,
                  title: 'Favoritas',
                  subtitle: 'Mezclas guardadas',
                  color: pastelGreen,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FavoritesPage(),
                      ),
                    );
                  },
                ),
              ];
            }),
            
            const SizedBox(height: 24),
            
            // Estadísticas rápidas
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
              ),
              child: Consumer<HomeStatsProvider>(
                builder: (context, statsProvider, _) {
                  if (statsProvider.isLoading && !statsProvider.hasData) {
                    return const SizedBox(
                      height: 64,
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator.adaptive(strokeWidth: 2.5),
                        ),
                      ),
                    );
                  }

                  final stats = statsProvider.stats;
                  final showPlaceholder = statsProvider.error != null && !statsProvider.hasData;

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(
                            context,
                            showPlaceholder ? '--' : _formatCount(stats.tobaccos),
                            'Tabacos',
                          ),
                          _buildStatColumn(
                            context,
                            showPlaceholder ? '--' : _formatCount(stats.mixes),
                            'Mezclas',
                          ),
                          _buildStatColumn(
                            context,
                            showPlaceholder ? '--' : _formatCount(stats.users),
                            'Usuarios',
                          ),
                        ],
                      ),
                      if (statsProvider.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'No se pudieron cargar las estadísticas',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.error.withOpacity(0.8),
                                ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int value) => _numberFormat.format(value);

  Widget _buildQuickAccessCard(
    BuildContext context, {
    required double scaleFactor,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Ajustar tamaños según el factor de escala del texto
    final iconSize = scaleFactor > 1.5 ? 28.0 : (scaleFactor > 1.3 ? 32.0 : (scaleFactor > 1.1 ? 34.0 : 36.0));
    final containerPadding = scaleFactor > 1.3 ? 10.0 : (scaleFactor > 1.1 ? 12.0 : 14.0);
    final cardPadding = scaleFactor > 1.3 ? 12.0 : (scaleFactor > 1.1 ? 14.0 : 16.0);
    
    // Espacios fijos para mejor control
    final iconBottomSpacing = scaleFactor > 1.3 ? 8.0 : 12.0;
    final titleBottomSpacing = scaleFactor > 1.3 ? 6.0 : 8.0;
    
    return Semantics(
      label: '$title: $subtitle',
      button: true,
      enabled: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      color.withOpacity(0.1),
                      color.withOpacity(0.05),
                    ]
                  : [
                      color.withOpacity(0.08),
                      color.withOpacity(0.15),
                      color.withOpacity(0.08),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark 
                  ? color.withOpacity(0.3)
                  : color.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: isDark 
                ? null
                : [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                      spreadRadius: 0,
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              splashColor: color.withOpacity(0.2),
              highlightColor: color.withOpacity(0.1),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icono con padding fijo
                    Container(
                      padding: EdgeInsets.all(containerPadding),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? color.withOpacity(0.2)
                            : color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isDark 
                            ? null
                            : [
                                BoxShadow(
                                  color: color.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Icon(
                        icon,
                        size: iconSize,
                        color: isDark 
                            ? color.withOpacity(0.9)
                            : color,
                      ),
                    ),
                    SizedBox(height: iconBottomSpacing),
                    // Título
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        letterSpacing: 0.5,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: titleBottomSpacing),
                    // Subtítulo
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: scaleFactor > 1.3 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, String number, String label) {
    return Semantics(
      label: '$number $label',
      child: Column(
        children: [
          Text(
            number,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessCarousel extends StatefulWidget {
  const _QuickAccessCarousel({
    required this.scaleFactor,
    required this.buildCard,
  });

  final double scaleFactor;
  final List<Widget> Function(BuildContext) buildCard;

  @override
  State<_QuickAccessCarousel> createState() => _QuickAccessCarouselState();
}

class _QuickAccessCarouselState extends State<_QuickAccessCarousel> {
  final _controller = ScrollController();
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _offset = _controller.offset);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double crossAxisSpacing = 12;
        final double cardWidth = (constraints.maxWidth - crossAxisSpacing) / 2;
        // Ajustar aspect ratio para dar más altura cuando hay texto grande
        final double aspect = widget.scaleFactor > 1.5 ? 0.48 : (widget.scaleFactor > 1.3 ? 0.58 : (widget.scaleFactor > 1.1 ? 0.72 : 0.88));
        final double cardHeight = cardWidth / aspect;

        final children = widget.buildCard(context);

        // Fades (izquierda/derecha) basados en desplazamiento
        final bool showLeft = _offset > 2;
        final bool showRight = _controller.hasClients && _controller.position.maxScrollExtent - _offset > 2;

        return Stack(
          children: [
            SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    SizedBox(width: i == 0 ? 0 : 12),
                    SizedBox(width: cardWidth, height: cardHeight, child: children[i]),
                  ],
                ],
              ),
            ),
            // Fade izquierdo
            if (showLeft)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Theme.of(context).scaffoldBackgroundColor,
                          Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Fade derecho
            if (showRight)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Theme.of(context).scaffoldBackgroundColor,
                          Theme.of(context).scaffoldBackgroundColor.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}