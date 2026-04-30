import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/tobacco.dart';
import '../../core/models/mix.dart';
import '../../widgets/tobacco_card.dart';
import '../../widgets/tobacco_image.dart';
import '../../widgets/mix_card.dart';
import '../catalog/tobacco_detail_page.dart';
import '../community/presentation/mix_detail_page.dart';
import '../favorites/favorites_provider.dart';
import '../community/presentation/create_mix_page.dart';
import '../catalog/presentation/request_tobacco_page.dart';
import '../../core/data/supabase_service.dart';

/// Página de resultados de búsqueda que muestra tabacos y mezclas
/// que coincidan con el término de búsqueda.
class SearchResultsPage extends StatelessWidget {
  const SearchResultsPage({
    super.key,
    required this.query,
    required this.tobaccos,
    required this.mixes,
  });

  final String query;
  final List<Tobacco> tobaccos;
  final List<Mix> mixes;

  @override
  Widget build(BuildContext context) {
    final showTabs = tobaccos.isNotEmpty && mixes.isNotEmpty;
    return showTabs
        ? DefaultTabController(
            length: 2,
            child: _buildScaffold(context, showTabs: true),
          )
        : _buildScaffold(context, showTabs: false);
  }

  Widget _buildScaffold(BuildContext context, {required bool showTabs}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalResults = tobaccos.length + mixes.length;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
                      Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
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
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Theme.of(context).primaryColor.withOpacity(0.2)
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: isDark ? Theme.of(context).primaryColor : Colors.white,
                        size: 26,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Resultados',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Theme.of(context).primaryColor : Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: totalResults == 0
          ? _buildEmptyState(context)
          : Column(
              children: [
                _buildGlobalCounter(context, totalResults),
                if (showTabs) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).primaryColor,
                      ),
                      labelColor: isDark ? Colors.black : Colors.white,
                      unselectedLabelColor: Theme.of(context).textTheme.bodyLarge?.color,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(text: 'Tabacos (${tobaccos.length})'),
                        Tab(text: 'Mezclas (${mixes.length})'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (!showTabs) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildSectionHeader(
                      context,
                      icon: tobaccos.isNotEmpty ? Icons.local_fire_department : Icons.people,
                      title: tobaccos.isNotEmpty ? 'Tabacos' : 'Mezclas de la Comunidad',
                      count: tobaccos.isNotEmpty ? tobaccos.length : mixes.length,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: showTabs
                      ? TabBarView(
                          children: [
                            _buildTobaccoList(context),
                            _buildMixesList(context),
                          ],
                        )
                      : (tobaccos.isNotEmpty ? _buildTobaccoList(context) : _buildMixesList(context)),
                ),
              ],
            ),
    );
  }

  Widget _buildGlobalCounter(BuildContext context, int totalResults) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                  children: [
                    TextSpan(
                      text: totalResults == 1
                          ? '1 resultado encontrado'
                          : '$totalResults resultados encontrados',
                    ),
                    TextSpan(
                      text: ' para ',
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.7),
                      ),
                    ),
                    TextSpan(
                      text: '"$query"',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTobaccoList(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final scaleFactor = textScaler.scale(1.0);

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: scaleFactor > 1.5
            ? 0.65
            : (scaleFactor > 1.3 ? 0.7 : 0.8),
      ),
      itemCount: tobaccos.length,
      itemBuilder: (context, index) {
        final tobacco = tobaccos[index];
        return _buildGridTobaccoCard(
          context,
          tobacco,
          scaleFactor,
          const Color(0xFF72C8C1),
        );
      },
    );
  }

  Widget _buildGridTobaccoCard(
    BuildContext context,
    Tobacco tobacco,
    double scaleFactor,
    Color baseColor,
  ) {
    final cardPadding = scaleFactor > 1.3 ? 10.0 : 12.0;
    final bool tightSpacing = scaleFactor < 1.3;
    final Color color = baseColor;

    return Semantics(
      label: '${tobacco.name} de ${tobacco.brand}, calificación ${tobacco.rating} con ${tobacco.reviews} reseñas',
      button: true,
      enabled: true,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TobaccoDetailPage(tobacco: tobacco),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: scaleFactor > 1.3 ? 1 : 4,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TobaccoImage(
                      imageUrl: tobacco.imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 12,
                      placeholderColor: color,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Expanded(
                  flex: scaleFactor > 1.3 ? 1 : 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Flexible(
                        flex: 2,
                        child: Text(
                          tobacco.name,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: tightSpacing ? 2 : 4),
                      Flexible(
                        flex: 1,
                        child: Text(
                          tobacco.brand,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ...(() {
                        final hasRating = (tobacco.rating > 0) && (tobacco.reviews > 0);
                        if (hasRating) {
                          return [
                            Icon(Icons.star, size: scaleFactor > 1.3 ? 14 : 16, color: color),
                            const SizedBox(width: 4),
                            Text(
                              tobacco.rating.toString(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '(${tobacco.reviews})',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ];
                        } else {
                          return [
                            Icon(Icons.star_border, size: scaleFactor > 1.3 ? 14 : 16, color: color),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Sin valoraciones',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5),
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ];
                        }
                      })(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMixesList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: mixes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final mix = mixes[index];
        final favProvider = context.watch<FavoritesProvider>();
        final isFavorite = favProvider.favorites.any((m) => m.id == mix.id);
        final mixWithFixedColor = mix.copyWith(color: const Color(0xFF72C8C1));

        return MixCard(
          mix: mixWithFixedColor,
          isFavorite: isFavorite,
          onFavoriteTap: () async {
            if (isFavorite) {
              await favProvider.removeFavorite(mix.id);
            } else {
              await favProvider.addFavorite(mix);
            }
          },
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MixDetailPage(mix: mix),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(context).primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No se encontraron resultados',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Intenta buscar con otras palabras clave o verifica la ortografía',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final userId = SupabaseService().client.auth.currentUser?.id ?? '';
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateMixPage(currentUser: userId),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Crear una mezcla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RequestTobaccoPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Solicitar un tabaco', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
