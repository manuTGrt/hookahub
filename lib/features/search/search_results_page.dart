import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/tobacco.dart';
import '../../core/models/mix.dart';
import '../../widgets/tobacco_card.dart';
import '../../widgets/mix_card.dart';
import '../catalog/tobacco_detail_page.dart';
import '../community/presentation/mix_detail_page.dart';
import '../favorites/favorites_provider.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalResults = tobaccos.length + mixes.length;

    return Scaffold(
      // AppBar con gradiente similar al de main_navigation
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
                      Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95)
                    ]
                  : [
                      Theme.of(context).primaryColor,
                      Theme.of(context).colorScheme.secondary
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                        color: isDark
                            ? Theme.of(context).primaryColor
                            : Colors.white,
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
                        color: isDark
                            ? Theme.of(context).primaryColor
                            : Colors.white,
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Contador de resultados
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                const SizedBox(height: 24),

                // Sección: Tabacos
                if (tobaccos.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    icon: Icons.local_fire_department,
                    title: 'Tabacos',
                    count: tobaccos.length,
                  ),
                  const SizedBox(height: 12),
      ...tobaccos.map((tobacco) => TobaccoCard(
                        name: tobacco.name,
                        brand: tobacco.brand,
                        description: tobacco.description,
                        flavors: tobacco.flavors,
                        // Usar el mismo color que las mezclas para consistencia visual
                        color: const Color(0xFF72C8C1),
                        rating: tobacco.rating,
                        reviews: tobacco.reviews,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TobaccoDetailPage(tobacco: tobacco),
                            ),
                          );
                        },
                      )),
                  const SizedBox(height: 24),
                ],

                // Sección: Mezclas
                if (mixes.isNotEmpty) ...[
                  _buildSectionHeader(
                    context,
                    icon: Icons.people,
                    title: 'Mezclas de la Comunidad',
                    count: mixes.length,
                  ),
                  const SizedBox(height: 12),
                  ...mixes.map((mix) {
                    final favProvider = context.watch<FavoritesProvider>();
                    final isFavorite = favProvider.favorites.any((m) => m.id == mix.id);

                    // Forzar el mismo color que las tarjetas de tabaco para consistencia
                    final mixWithFixedColor = mix.copyWith(
                      color: const Color(0xFF72C8C1),
                    );

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
                  }),
                ],
              ],
            ),
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
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
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
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
