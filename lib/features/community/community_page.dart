import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/mix_card.dart';
import '../../core/models/mix.dart';
import '../favorites/favorites_provider.dart';
import 'presentation/mix_detail_page.dart';
import 'presentation/community_provider.dart';
import 'domain/community_filters.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  @override
  void initState() {
    super.initState();
    // Cargar mezclas al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<CommunityProvider>();
      if (!provider.isLoaded) {
        provider.loadMixes();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final scaleFactor = textScaler.scale(1.0);
    
    return Scaffold(
      body: Consumer<CommunityProvider>(
        builder: (context, provider, child) {
          // Mostrar indicador de carga inicial
          if (provider.isLoading && !provider.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          // Mostrar error si ocurrió
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
                    'Error al cargar las mezclas',
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

          // Mostrar contenido
          return RefreshIndicator(
            onRefresh: () => provider.refresh(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filtros de mezclas
                  SizedBox(
                    height: scaleFactor > 1.5 ? 50 : (scaleFactor > 1.3 ? 44 : 40),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildSortDropdown(context, provider, scaleFactor),
                        const SizedBox(width: 8),
                        _buildFavoritesChip(context, provider),
                        const SizedBox(width: 8),
                        _buildTobaccoFilterDropdown(context, provider, scaleFactor),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Lista de mezclas
                  Text(
                    'Mezclas de la comunidad',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.headlineSmall?.color,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Mostrar mensaje si no hay mezclas
                  if (provider.mixes.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.science_outlined,
                              size: 64,
                              color: Theme.of(context).primaryColor.withOpacity(0.5),
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
                    )
                  else
                    // Cards de mezclas desde la base de datos
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.mixes.length,
                      itemBuilder: (context, index) {
                        return _buildMixCard(context, provider.mixes[index], scaleFactor);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  

  Widget _buildFavoritesChip(BuildContext context, CommunityProvider provider) {
    final isSelected = provider.filterState.favoritesOnly;
    final fav = context.watch<FavoritesProvider>();
    return FilterChip(
      label: const Text('Mis favoritas'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          provider.setLocalFavorites(fav.favorites);
        } else {
            provider.toggleFavoritesOnly();
        }
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).primaryColor
            : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? Theme.of(context).primaryColor
            : Theme.of(context).dividerColor.withOpacity(0.3),
      ),
    );
  }

  Widget _buildSortDropdown(BuildContext context, CommunityProvider provider, double scaleFactor) {
    final sort = provider.filterState.sortOption;
    return PopupMenuButton<CommunitySortOption>(
      tooltip: 'Ordenar mezclas',
      onSelected: provider.setSortOption,
      itemBuilder: (_) => [
        const PopupMenuItem<CommunitySortOption>(
          enabled: false,
          child: Text('Ordenar por', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...CommunitySortOption.values.map((opt) {
          return PopupMenuItem<CommunitySortOption>(
            value: opt,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(opt.label, overflow: TextOverflow.ellipsis)),
                if (sort == opt)
                  Icon(Icons.check, size: 18, color: Theme.of(context).primaryColor),
              ],
            ),
          );
        }),
      ],
      child: Container(
        height: scaleFactor > 1.5 ? 50 : (scaleFactor > 1.3 ? 44 : 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.15),
              Theme.of(context).primaryColor.withOpacity(0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 18, color: Theme.of(context).primaryColor),
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
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 22, color: Theme.of(context).primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTobaccoFilterDropdown(BuildContext context, CommunityProvider provider, double scaleFactor) {
    final display = provider.filterState.tobaccoName == null
        ? 'Todos los tabacos'
        : provider.filterState.tobaccoName!;

    return GestureDetector(
      onTap: () => _showTobaccoPicker(context, provider),
      child: Container(
        height: scaleFactor > 1.5 ? 50 : (scaleFactor > 1.3 ? 44 : 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.15),
              Theme.of(context).primaryColor.withOpacity(0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department, size: 18, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                display,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 22, color: Theme.of(context).primaryColor),
            if (provider.filterState.tobaccoName != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: InkWell(
                  onTap: provider.clearTobaccoFilter,
                  child: Icon(Icons.clear, size: 16, color: Theme.of(context).primaryColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTobaccoPicker(BuildContext context, CommunityProvider provider) async {
    final controller = TextEditingController();
    List<Map<String, String>> results = [];
    bool isLoading = true;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        void fetch(String? q) async {
          isLoading = true;
          (ctx as Element).markNeedsBuild();
          // Reutilizamos el repositorio de comunidad para obtener tabacos
          results = await provider.repository.fetchAvailableTobaccos(query: q, limit: 80);
          isLoading = false;
          (ctx).markNeedsBuild();
        }
        fetch(null);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              Future<void> doSearch(String value) async {
                setState(() => isLoading = true);
                results = await provider.repository.fetchAvailableTobaccos(query: value, limit: 80);
                setState(() => isLoading = false);
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Text('Filtrar por tabaco', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    onChanged: (v) => doSearch(v),
                    decoration: InputDecoration(
                      hintText: 'Buscar nombre o marca...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                controller.clear();
                                doSearch('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 320,
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : results.isEmpty
                            ? Center(
                                child: Text(
                                  'No se encontraron tabacos',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              )
                            : ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (context, index) {
                                  final item = results[index];
                                  return ListTile(
                                    dense: true,
                                    title: Text(item['name'] ?? ''),
                                    subtitle: Text(item['brand'] ?? ''),
                                    onTap: () {
                                      provider.setTobaccoFilter(
                                        name: item['name']!,
                                        brand: item['brand']!,
                                      );
                                      Navigator.of(context).pop();
                                    },
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            provider.clearTobaccoFilter();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Limpiar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.check),
                          label: const Text('Cerrar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMixCard(BuildContext context, Mix mix, double scaleFactor) {
  final fav = context.watch<FavoritesProvider>();
  final communityProvider = context.read<CommunityProvider>();
  final isFav = fav.favorites.any((x) => x.id == mix.id);
    
    return MixCard(
      mix: mix,
      isFavorite: isFav,
      onFavoriteTap: () async {
        if (isFav) {
          await fav.removeFavorite(mix.id);
        } else {
          await fav.addFavorite(mix);
        }
        if (communityProvider.filterState.favoritesOnly) {
          communityProvider.setLocalFavorites(fav.favorites);
        }
      },
      onShare: () {},
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MixDetailPage(mix: mix),
          ),
        );
      },
    );
  }
}
