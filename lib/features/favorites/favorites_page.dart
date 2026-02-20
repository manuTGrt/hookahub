import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/models/mix.dart';
import '../../widgets/mix_card.dart';
import '../profile/presentation/profile_provider.dart';
import '../community/data/community_repository.dart';
import '../community/presentation/mix_detail_page.dart';
import '../community/presentation/create_mix_page.dart';
import '../../core/data/supabase_service.dart';
import 'favorites_provider.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    // Cargar estado si aún no está cargado
    Future.microtask(() {
      final provider = context.read<FavoritesProvider>();
      if (!provider.isLoaded) provider.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      // AppBar removida: título y navegación manejados por barra superior global
      body: Consumer<FavoritesProvider>(
        builder: (context, fav, child) {
          if (!fav.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final top5 = fav.top5;
          final rest = fav.favorites.where((m) => !fav.isTop5(m.id)).toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Top5Section(
                  mixes: top5,
                  onReorder: fav.reorderTop5,
                  onToggle: (id) => fav.toggleTop5(id),
                ),
                const SizedBox(height: 24),
                Text(
                  'Todas las favoritas',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (rest.isEmpty && top5.isEmpty)
                  _EmptyState(isDark: isDark)
                else ...[
                  const SizedBox(height: 8),
                  // Usamos MixCard para igualar estilo de Comunidad
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rest.length,
                    itemBuilder: (context, index) {
                      final mix = rest[index];
                      final profileProvider = context.watch<ProfileProvider>();
                      final currentUsername = profileProvider.profile?.username;
                      final isOwned =
                          currentUsername != null &&
                          mix.author == currentUsername;

                      return MixCard(
                        mix: mix,
                        isFavorite: true, // siempre true en esta lista
                        onFavoriteTap: () => fav.removeFavorite(mix.id),
                        trailingIcon: Icons.push_pin_outlined,
                        onTrailingTap: () => fav.toggleTop5(mix.id),
                        onShare: () => Share.share(
                          'Mezcla: ${mix.name} por ${mix.author}',
                        ),
                        isOwned: isOwned,
                        onEdit: isOwned
                            ? () async {
                                final updated = await Navigator.of(context)
                                    .push<Mix>(
                                      MaterialPageRoute(
                                        builder: (_) => CreateMixPage(
                                          currentUser: mix.author,
                                          mixToEdit: mix,
                                        ),
                                      ),
                                    );
                                if (updated != null && context.mounted) {
                                  fav.updateFavorite(updated);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Mezcla actualizada'),
                                    ),
                                  );
                                }
                              }
                            : null,
                        onDelete: isOwned
                            ? () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Eliminar mezcla'),
                                    content: const Text(
                                      '¿Seguro que quieres eliminar esta mezcla? Esta acción no se puede deshacer.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && context.mounted) {
                                  final repository = CommunityRepository(
                                    SupabaseService(),
                                  );
                                  final success = await repository.deleteMix(
                                    mix.id,
                                  );
                                  if (!context.mounted) return;
                                  if (success) {
                                    fav.removeFavorite(mix.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Mezcla eliminada'),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No se pudo eliminar la mezcla',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            : null,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MixDetailPage(mix: mix),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Top5Section extends StatelessWidget {
  const _Top5Section({
    required this.mixes,
    required this.onReorder,
    required this.onToggle,
  });

  final List<Mix> mixes;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(String mixId) onToggle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Top 5',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Fija hasta 5 mezclas favoritas arriba',
              child: Icon(
                Icons.info_outline,
                size: 18,
                color: isDark
                    ? darkNavy.withOpacity(0.7)
                    : navy.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          child: mixes.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No has fijado ninguna mezcla todavía.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: mixes.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    onReorder(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final mix = mixes[index];
                    final profileProvider = context.watch<ProfileProvider>();
                    final currentUsername = profileProvider.profile?.username;
                    final isOwned =
                        currentUsername != null &&
                        mix.author == currentUsername;

                    return Container(
                      key: ValueKey(mix.id),
                      child: MixCard(
                        mix: mix,
                        isFavorite: true,
                        onFavoriteTap: () => context
                            .read<FavoritesProvider>()
                            .removeFavorite(mix.id),
                        // En Top 5, el botón de pin quita del Top 5 (sigue en favoritos)
                        trailingIcon: Icons.push_pin,
                        onTrailingTap: () => onToggle(mix.id),
                        onShare: () => Share.share(
                          'Mezcla: ${mix.name} por ${mix.author}',
                        ),
                        isOwned: isOwned,
                        onEdit: isOwned
                            ? () async {
                                final updated = await Navigator.of(context)
                                    .push<Mix>(
                                      MaterialPageRoute(
                                        builder: (_) => CreateMixPage(
                                          currentUser: mix.author,
                                          mixToEdit: mix,
                                        ),
                                      ),
                                    );
                                if (updated != null && context.mounted) {
                                  context
                                      .read<FavoritesProvider>()
                                      .updateFavorite(updated);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Mezcla actualizada'),
                                    ),
                                  );
                                }
                              }
                            : null,
                        onDelete: isOwned
                            ? () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Eliminar mezcla'),
                                    content: const Text(
                                      '¿Seguro que quieres eliminar esta mezcla? Esta acción no se puede deshacer.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && context.mounted) {
                                  final repository = CommunityRepository(
                                    SupabaseService(),
                                  );
                                  final success = await repository.deleteMix(
                                    mix.id,
                                  );
                                  if (!context.mounted) return;
                                  if (success) {
                                    context
                                        .read<FavoritesProvider>()
                                        .removeFavorite(mix.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Mezcla eliminada'),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'No se pudo eliminar la mezcla',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            : null,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MixDetailPage(mix: mix),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// _MixTile eliminado; usamos MixCard para un estilo consistente con Comunidad

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? darkBg.withOpacity(0.3)
            : Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? darkTurquoise.withOpacity(0.2)
              : Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_outline, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Todavía no tienes favoritos. Puedes añadir mezclas desde la comunidad.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
