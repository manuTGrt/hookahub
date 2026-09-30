import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../widgets/mix_card.dart';
import '../../favorites/presentation/favorites_provider.dart';
import '../../community/presentation/mix_detail_page.dart';
import '../../community/presentation/create_mix_page.dart';
import '../../community/data/community_repository.dart';
import 'user_mixes_provider.dart';
import '../../../core/data/supabase_service.dart';
import '../../../core/models/mix.dart';
import '../../../core/utils/app_toast.dart';

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
    if (!mounted) return;
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
            if (provider.state is UserMixesLoading ||
                provider.state is UserMixesInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.state is UserMixesError) {
              final errorMsg = (provider.state as UserMixesError).message;
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
                      errorMsg,
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
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
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
                          return _UserMixItem(
                            key: ValueKey(provider.mixes[index].id),
                            mix: provider.mixes[index],
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
              color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
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

class _UserMixItem extends StatelessWidget {
  const _UserMixItem({super.key, required this.mix});

  final Mix mix;

  @override
  Widget build(BuildContext context) {
    final isFav = context.select<FavoritesProvider, bool>(
      (fav) => fav.favorites.any((m) => m.id == mix.id),
    );

    return MixCard(
      mix: mix,
      isFavorite: isFav,
      onFavoriteTap: () {
        final fav = context.read<FavoritesProvider>();
        if (isFav) {
          fav.removeFavorite(mix.id);
        } else {
          fav.addFavorite(mix);
        }
      },
      onShare: () => SharePlus.instance.share(
        ShareParams(text: 'Mezcla: ${mix.name} por ${mix.author}'),
      ),
      isOwned: true, // En "Mis Mezclas" todas son del usuario
      onEdit: () async {
        final updated = await Navigator.of(context).push<Mix>(
          MaterialPageRoute(
            builder: (_) =>
                CreateMixPage(currentUser: mix.author, mixToEdit: mix),
          ),
        );
        if (updated != null && context.mounted) {
          context.read<UserMixesProvider>().refresh();
          AppToast.showInfo(context, 'Mezcla actualizada');
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
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          final repository = CommunityRepository(SupabaseService());
          final success = await repository.deleteMix(mix.id);
          if (!context.mounted) return;
          if (success) {
            context.read<UserMixesProvider>().refresh();
            AppToast.showInfo(context, 'Mezcla eliminada');
          } else {
            AppToast.showInfo(context, 'No se pudo eliminar la mezcla');
          }
        }
      },
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => MixDetailPage(mix: mix)));
      },
    );
  }
}
