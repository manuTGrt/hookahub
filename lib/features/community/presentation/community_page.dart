import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../widgets/mix_card.dart';
import '../../../widgets/ad_banner_card.dart';
import '../../../core/models/mix.dart';
import '../../../core/services/deep_link_service.dart';
import '../../favorites/presentation/favorites_provider.dart';
import '../../profile/presentation/profile_provider.dart';
import '../../mixes/presentation/user_mixes_provider.dart';
import 'mix_detail_page.dart';
import 'community_provider.dart';
import '../domain/community_filters.dart';
import 'create_mix_page.dart';
import '../../../core/utils/app_toast.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Carga diferida: se ejecutará al entrar en la pestaña Comunidad

    // Listener para detectar cuando llegamos al final del scroll
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Cuando estamos a 200 píxeles del final, cargar más
      final provider = context.read<CommunityProvider>();
      if (!provider.isLoadingMore && provider.hasMoreData) {
        provider.loadMoreMixes();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInitialLoading = context.select<CommunityProvider, bool>(
      (p) => p.state is CommunityLoading || p.state is CommunityInitial,
    );
    if (isInitialLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final initialError = context.select<CommunityProvider, String?>(
      (p) => p.state is CommunityError
          ? (p.state as CommunityError).message
          : null,
    );
    if (initialError != null) {
      return Scaffold(
        body: Center(
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
                'Error al cargar las mezclas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                initialError,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context.read<CommunityProvider>().refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final textScaler = MediaQuery.textScalerOf(context);
    final scaleFactor = textScaler.scale(1.0);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => context.read<CommunityProvider>().refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barra de controles (orden, favoritas, tabaco)
                    SizedBox(
                      height: scaleFactor > 1.5
                          ? 50
                          : (scaleFactor > 1.3 ? 44 : 40),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildSortDropdown(context, scaleFactor),
                          const SizedBox(width: 8),
                          _buildFavoritesChip(context),
                          const SizedBox(width: 8),
                          _TobaccoFilterDropdown(scaleFactor: scaleFactor),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _CommunityMixesSliver(scaleFactor: scaleFactor),
            const _CommunityFooter(),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  // Chip de favoritas
  Widget _buildFavoritesChip(BuildContext context) {
    final isSelected = context.select<CommunityProvider, bool>(
      (p) => p.filterState.favoritesOnly,
    );
    return FilterChip(
      label: const Text('Mis favoritas'),
      selected: isSelected,
      onSelected: (selected) {
        final provider = context.read<CommunityProvider>();
        if (selected) {
          // Usar favoritas locales sin ir a red
          final favs = context.read<FavoritesProvider>().favorites;
          provider.setLocalFavorites(favs);
        } else {
          // Volver a la vista normal
          provider.toggleFavoritesOnly();
        }
      },
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).primaryColor
            : Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? Theme.of(context).primaryColor
            : Theme.of(context).dividerColor.withValues(alpha: 0.3),
      ),
    );
  }

  // Dropdown de ordenamiento (estética igual a catálogo)
  Widget _buildSortDropdown(BuildContext context, double scaleFactor) {
    final sort = context.select<CommunityProvider, CommunitySortOption>(
      (p) => p.filterState.sortOption,
    );
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          elevation: 12,
          color: Theme.of(context).cardColor,
        ),
      ),
      child: PopupMenuButton<CommunitySortOption>(
        onSelected: (CommunitySortOption option) =>
            context.read<CommunityProvider>().setSortOption(option),
        tooltip: 'Ordenar mezclas',
        offset: const Offset(0, 10),
        position: PopupMenuPosition.under,
        splashRadius: 24,
        itemBuilder: (BuildContext context) {
          return [
            PopupMenuItem<CommunitySortOption>(
              enabled: false,
              height: 40,
              child: Row(
                children: [
                  Icon(
                    Icons.sort,
                    size: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ordenar por',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuDivider(
              height: 1,
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            ...CommunitySortOption.values.map((opt) {
              final isSelected = sort == opt;
              return PopupMenuItem<CommunitySortOption>(
                value: opt,
                height: 52,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          opt.label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          _getSortIcon(opt),
                          size: 16,
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.6),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ];
        },
        child: Container(
          height: scaleFactor > 1.5 ? 50 : (scaleFactor > 1.3 ? 44 : 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withValues(alpha: 0.15),
                Theme.of(context).primaryColor.withValues(alpha: 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sort_rounded,
                size: 18,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  sort.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 22,
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getSortIcon(CommunitySortOption option) {
    switch (option) {
      case CommunitySortOption.newest:
        return Icons.schedule;
      case CommunitySortOption.oldest:
        return Icons.history;
      case CommunitySortOption.nameAsc:
        return Icons.arrow_upward;
      case CommunitySortOption.nameDesc:
        return Icons.arrow_downward;
      case CommunitySortOption.mostPopular:
        return Icons.trending_up;
      case CommunitySortOption.topRated:
        return Icons.star;
    }
  }
}

class _CommunityMixesSliver extends StatelessWidget {
  const _CommunityMixesSliver({required this.scaleFactor});

  final double scaleFactor;

  @override
  Widget build(BuildContext context) {
    final mixes = context.select<CommunityProvider, List<Mix>>((p) => p.mixes);

    final primaryColor = Theme.of(context).primaryColor;

    if (mixes.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 64,
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay mezclas disponibles',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sé el primero en crear una mezcla',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Generador pseudo-aleatorio con semilla basada en la lista para garantizar
    // estabilidad de posiciones durante el scroll y paginación
    final random = Random(mixes.firstOrNull?.id.hashCode ?? 42);
    final slivers = <Widget>[];
    int currentIndex = 0;

    while (currentIndex < mixes.length) {
      // Intervalo aleatorio entre 5 y 12 mezclas: 5 + (0..7) => [5, 12]
      final int chunkSize = 5 + random.nextInt(8);
      final int chunkEnd = (currentIndex + chunkSize < mixes.length)
          ? currentIndex + chunkSize
          : mixes.length;
      final chunk = mixes.sublist(currentIndex, chunkEnd);

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final mix = chunk[index];
              return _CommunityMixItem(
                key: ValueKey(mix.id),
                mix: mix,
                scaleFactor: scaleFactor,
              );
            }, childCount: chunk.length),
          ),
        ),
      );

      // Si aún quedan más elementos por mostrar tras este bloque, insertar tarjeta de banner
      if (chunkEnd < mixes.length) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AdBannerCard(
                color: primaryColor,
                margin: const EdgeInsets.only(bottom: 16.0),
              ),
            ),
          ),
        );
      }

      currentIndex = chunkEnd;
    }

    return SliverMainAxisGroup(slivers: slivers);
  }
}

class _CommunityFooter extends StatelessWidget {
  const _CommunityFooter();

  @override
  Widget build(BuildContext context) {
    final isLoadingMore = context.select<CommunityProvider, bool>(
      (p) => p.isLoadingMore,
    );
    final showNoMore = context.select<CommunityProvider, bool>(
      (p) => !p.hasMoreData && p.mixes.isNotEmpty,
    );

    if (isLoadingMore) {
      return SliverToBoxAdapter(
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
      );
    }

    if (showNoMore) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No hay más mezclas',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      );
    }

    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }
}

class _CommunityMixItem extends StatelessWidget {
  const _CommunityMixItem({
    super.key,
    required this.mix,
    required this.scaleFactor,
  });

  final Mix mix;
  final double scaleFactor;

  @override
  Widget build(BuildContext context) {
    final isFav = context.select<FavoritesProvider, bool>(
      (fav) => fav.favorites.any((x) => x.id == mix.id),
    );
    final isOwned = context.select<ProfileProvider, bool>(
      (p) => p.profile?.username != null && p.profile!.username == mix.author,
    );

    return MixCard(
      mix: mix,
      isFavorite: isFav,
      onFavoriteTap: () async {
        final fav = context.read<FavoritesProvider>();
        if (isFav) {
          await fav.removeFavorite(mix.id);
        } else {
          await fav.addFavorite(mix);
        }
        if (!context.mounted) return;
        final communityProvider = context.read<CommunityProvider>();
        if (communityProvider.filterState.favoritesOnly) {
          communityProvider.setLocalFavorites(fav.favorites);
        }
      },
      onShare: () => SharePlus.instance.share(
        ShareParams(
          text:
              '¡Descubre la mezcla "${mix.name}" por ${mix.author} en Hookahub!\n${DeepLinkService.buildMixShareUrl(mix.id)}',
        ),
      ),
      isOwned: isOwned,
      onEdit: isOwned
          ? () async {
              final updated = await Navigator.of(context).push<Mix>(
                MaterialPageRoute(
                  builder: (_) =>
                      CreateMixPage(currentUser: mix.author, mixToEdit: mix),
                ),
              );
              if (updated != null && context.mounted) {
                context.read<CommunityProvider>().updateMix(updated);
                AppToast.showInfo(context, 'Mezcla actualizada');
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
                final success = await context
                    .read<CommunityProvider>()
                    .deleteMix(mix.id);
                if (!context.mounted) return;
                if (success) {
                  final profileProvider = context.read<ProfileProvider>();
                  profileProvider.decrementMixesCount();
                  unawaited(profileProvider.refreshMixesCount());
                  context.read<UserMixesProvider>().refresh();
                  AppToast.showInfo(context, 'Mezcla eliminada');
                } else {
                  AppToast.showError(context, 'No se pudo eliminar la mezcla');
                }
              }
            }
          : null,
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => MixDetailPage(mix: mix)));
      },
    );
  }
}

class _TobaccoFilterDropdown extends StatefulWidget {
  const _TobaccoFilterDropdown({required this.scaleFactor});
  final double scaleFactor;
  @override
  State<_TobaccoFilterDropdown> createState() => _TobaccoFilterDropdownState();
}

class _TobaccoFilterDropdownState extends State<_TobaccoFilterDropdown> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, String>> _available = [];
  bool _loading = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showTobaccoMenu() async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height), ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    const String allKey = '__ALL_TOBACCO__';
    final communityProvider = context.read<CommunityProvider>();
    setState(() => _loading = true);
    _available = await communityProvider.repository.fetchAvailableTobaccos(
      limit: 50,
    );
    if (!mounted || !context.mounted) return;
    setState(() => _loading = false);

    await showMenu<String?>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      elevation: 12,
      color: Theme.of(context).cardColor,
      items: [
        PopupMenuItem<String?>(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setMenuState) {
              final list = _available;
              final selectedName = communityProvider.filterState.tobaccoName;

              void triggerServerSearch(String queryText) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(
                  const Duration(milliseconds: 300),
                  () async {
                    if (!mounted || !context.mounted) return;
                    setMenuState(() => _loading = true);
                    final results = await communityProvider.repository
                        .fetchAvailableTobaccos(query: queryText, limit: 50);
                    if (!mounted || !context.mounted) return;
                    setMenuState(() {
                      _available = results;
                      _loading = false;
                    });
                  },
                );
              }

              return SizedBox(
                width: 280,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (value) {
                        setMenuState(() {});
                        triggerServerSearch(value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar tabaco...',
                        hintStyle: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.5),
                            ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20,
                          color: Theme.of(context).primaryColor,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setMenuState(() {});
                                  triggerServerSearch('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: _loading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: 1 + (list.isEmpty ? 1 : list.length),
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return _buildTobaccoOption(
                                    context,
                                    allKey,
                                    'Todos los tabacos',
                                    Icons.filter_list,
                                    selectedName: selectedName,
                                    isAllOption: true,
                                  );
                                }
                                if (list.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Text(
                                      'No se encontraron tabacos',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color
                                                ?.withValues(alpha: 0.5),
                                          ),
                                    ),
                                  );
                                }
                                final item = list[index - 1];
                                return _buildTobaccoOption(
                                  context,
                                  '${item['name']}::${item['brand']}',
                                  '${item['name']} • ${item['brand']}',
                                  Icons.local_fire_department,
                                  selectedName: selectedName,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ).then((value) {
      _searchDebounce?.cancel();
      if (!mounted) return;
      if (value != null) {
        if (value == allKey) {
          communityProvider.clearTobaccoFilter();
        } else {
          final parts = value.split('::');
          if (parts.length == 2) {
            communityProvider.setTobaccoFilter(name: parts[0], brand: parts[1]);
          }
        }
      }
      _searchController.clear();
    });
  }

  Widget _buildTobaccoOption(
    BuildContext context,
    String key,
    String display,
    IconData icon, {
    required String? selectedName,
    bool isAllOption = false,
  }) {
    final isSelected = isAllOption
        ? selectedName == null
        : selectedName != null && display.startsWith(selectedName);
    return InkWell(
      onTap: () => Navigator.of(context).pop(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                display,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedName = context.select<CommunityProvider, String?>(
      (p) => p.filterState.tobaccoName,
    );
    final displayText = selectedName ?? 'Todos los tabacos';
    return GestureDetector(
      onTap: _showTobaccoMenu,
      child: Container(
        height: widget.scaleFactor > 1.5
            ? 50
            : (widget.scaleFactor > 1.3 ? 44 : 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withValues(alpha: 0.15),
              Theme.of(context).primaryColor.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department,
              size: 18,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                displayText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 22,
              color: Theme.of(context).primaryColor,
            ),
            if (selectedName != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: InkWell(
                  onTap: () =>
                      context.read<CommunityProvider>().clearTobaccoFilter(),
                  child: Icon(
                    Icons.clear,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
