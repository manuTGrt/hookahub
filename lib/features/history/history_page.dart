import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/models/mix.dart';
import '../../widgets/mix_card.dart';
import '../community/presentation/mix_detail_page.dart';
import '../favorites/favorites_provider.dart';
import 'presentation/history_provider.dart';
import 'domain/visit_entry.dart';

/// Página que muestra el historial de mezclas visitadas en los últimos 2 días.
/// Las mezclas se agrupan por día (Hoy, Ayer, Hace 2 días) y se ordenan
/// de más reciente a más antigua.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  void initState() {
    super.initState();
    // Cargar historial al iniciar - SIEMPRE se recarga para mostrar cambios recientes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HistoryProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final historyProvider = context.watch<HistoryProvider>();
    final favoritesProvider = context.watch<FavoritesProvider>();

    return Scaffold(
      // AppBar removida: título y navegación manejados por barra superior global
      body: RefreshIndicator(
        onRefresh: historyProvider.refresh,
        child: _buildBody(context, historyProvider, favoritesProvider, isDark),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HistoryProvider historyProvider,
    FavoritesProvider favoritesProvider,
    bool isDark,
  ) {
    // Estado de carga
    if (historyProvider.isLoading && !historyProvider.isLoaded) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Error
    if (historyProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? darkNavy.withOpacity(0.5) : navy.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar el historial',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              historyProvider.error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? darkNavy.withOpacity(0.7)
                        : navy.withOpacity(0.6),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: historyProvider.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    // Sin entradas
    if (historyProvider.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: isDark ? darkNavy.withOpacity(0.5) : navy.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay historial reciente',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Las mezclas que visites aparecerán aquí',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? darkNavy.withOpacity(0.7)
                          : navy.withOpacity(0.6),
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Lista de historial agrupada por día
    final groupedEntries = historyProvider.groupedByDay;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Estadística de mezclas únicas visitadas
        _buildStatsCard(context, historyProvider, isDark),
        const SizedBox(height: 16),

        // Grupos por día
        ...groupedEntries.entries.map((group) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera del día
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _getDayIcon(group.key),
                      size: 20,
                      color: isDark ? darkTurquoise : turquoise,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      group.key,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? darkNavy : navy,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${group.value.length})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? darkNavy.withOpacity(0.6)
                                : navy.withOpacity(0.5),
                          ),
                    ),
                  ],
                ),
              ),

              // Lista de mezclas del día
              ...group.value.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildHistoryCard(
                    context,
                    entry,
                    favoritesProvider,
                    isDark,
                  ),
                );
              }),

              const SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildStatsCard(
    BuildContext context,
    HistoryProvider provider,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  darkTurquoise.withOpacity(0.2),
                  darkNavy.withOpacity(0.1),
                ]
              : [
                  turquoise.withOpacity(0.1),
                  turquoiseDark.withOpacity(0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? darkTurquoise.withOpacity(0.3)
              : turquoise.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.visibility_outlined,
            size: 40,
            color: isDark ? darkTurquoise : turquoise,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${provider.uniqueCount} ${provider.uniqueCount == 1 ? 'mezcla única' : 'mezclas únicas'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? darkNavy : navy,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Visitadas en los últimos 2 días',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? darkNavy.withOpacity(0.7)
                            : navy.withOpacity(0.6),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    VisitEntry entry,
    FavoritesProvider favoritesProvider,
    bool isDark,
  ) {
    // Convertir VisitEntry a Mix para usar MixCard
    final mix = Mix(
      id: entry.mixId,
      name: entry.mixName,
      author: entry.author,
      rating: entry.rating,
      reviews: entry.reviews,
      ingredients: entry.ingredients,
      color: entry.mixColor,
    );

    final isFavorite = favoritesProvider.favorites.any((f) => f.id == mix.id);
    final timeFormat = DateFormat('HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MixCard(
          mix: mix,
          isFavorite: isFavorite,
          onFavoriteTap: () {
            if (isFavorite) {
              favoritesProvider.removeFavorite(mix.id);
            } else {
              favoritesProvider.addFavorite(mix);
            }
          },
          time: timeFormat.format(entry.visitedAt),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MixDetailPage(mix: mix),
              ),
            );
          },
        ),
      ],
    );
  }

  IconData _getDayIcon(String day) {
    switch (day) {
      case 'Hoy':
        return Icons.today;
      case 'Ayer':
        return Icons.calendar_today;
      case 'Hace 2 días':
        return Icons.event;
      default:
        return Icons.calendar_month;
    }
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Borrar todo el historial?'),
        content: const Text(
          'Esta acción no se puede deshacer. Se eliminará todo tu historial de mezclas visitadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final provider = context.read<HistoryProvider>();
              final success = await provider.clearAll();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Historial borrado correctamente'
                          : 'Error al borrar el historial',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
  }

  void _clearOldEntries(BuildContext context) async {
    final provider = context.read<HistoryProvider>();
    final deletedCount = await provider.clearOld(days: 7);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedCount > 0
                ? 'Se eliminaron $deletedCount ${deletedCount == 1 ? 'entrada antigua' : 'entradas antiguas'}'
                : 'No hay entradas antiguas para eliminar',
          ),
          backgroundColor: deletedCount > 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }
}
