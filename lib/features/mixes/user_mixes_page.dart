import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/mix_card.dart';
import '../favorites/favorites_provider.dart';
import '../community/presentation/mix_detail_page.dart';
import '../community/presentation/create_mix_page.dart';
import '../community/data/community_repository.dart';
import 'presentation/user_mixes_provider.dart';
import '../../core/data/supabase_service.dart';
import '../../core/models/mix.dart';

class UserMixesPage extends StatefulWidget {
  const UserMixesPage({super.key});

  @override
  State<UserMixesPage> createState() => _UserMixesPageState();
}

class _UserMixesPageState extends State<UserMixesPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<UserMixesProvider>();
      // Siempre recargar al entrar a la página
      provider.refresh();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final provider = context.read<UserMixesProvider>();
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !provider.isLoadingMore &&
        provider.hasMore) {
      provider.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<UserMixesProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && !provider.isLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar tus mezclas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.error!,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => provider.refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => provider.refresh(),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16.0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Barra de navegación superior (atrás + título)
                          Row(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () => Navigator.of(context).maybePop(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.arrow_back,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tus mezclas',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.headlineSmall?.color,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  if (provider.mixes.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyMyMixesState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final mix = provider.mixes[index];
                          final fav = context.watch<FavoritesProvider>();
                          final isFav = fav.favorites.any(
                            (m) => m.id == mix.id,
                          );
                          return MixCard(
                            mix: mix,
                            isFavorite: isFav,
                            onFavoriteTap: () => isFav
                                ? fav.removeFavorite(mix.id)
                                : fav.addFavorite(mix),
                            onShare: () => Share.share(
                              'Mezcla: ${mix.name} por ${mix.author}',
                            ),
                            isOwned:
                                true, // En "Mis Mezclas" todas son del usuario
                            onEdit: () async {
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
                                provider.refresh();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Mezcla actualizada'),
                                  ),
                                );
                              }
                            },
                            onDelete: () async {
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
                                  provider.refresh();
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
                            },
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MixDetailPage(mix: mix),
                                ),
                              );
                            },
                          );
                        }, childCount: provider.mixes.length),
                      ),
                    ),

                  if (provider.isLoadingMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyMyMixesState extends StatelessWidget {
  const _EmptyMyMixesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.science_outlined,
              size: 64,
              color: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no has creado mezclas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando crees tus mezclas, aparecerán aquí.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
