import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import '../../core/constants.dart';
import '../../core/models/tobacco.dart';
import '../../widgets/tobacco_image.dart';
import '../catalog/presentation/providers/catalog_provider.dart';
import '../catalog/domain/catalog_filters.dart';
import 'tobacco_detail_page.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final scaleFactor = textScaler.scale(1.0);

    final provider = context.watch<CatalogProvider>();
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: CustomScrollView(
          controller: provider.scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila de filtros con dropdowns
                    SizedBox(
                      height: scaleFactor > 1.5
                          ? 50
                          : (scaleFactor > 1.3 ? 44 : 40),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // Dropdown de ordenamiento
                          _buildSortDropdown(context, provider, scaleFactor),
                          const SizedBox(width: 8),

                          // Dropdown de marcas
                          _buildBrandDropdown(context, provider, scaleFactor),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text(
                      'Catálogo',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.headlineSmall?.color,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Grid de tabacos
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: scaleFactor > 1.5
                      ? 0.65
                      : (scaleFactor > 1.3 ? 0.7 : 0.8),
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index >= provider.items.length) {
                    return const SizedBox.shrink();
                  }
                  final t = provider.items[index];
                  return _buildTobaccoCard(
                    context,
                    t,
                    scaleFactor,
                    primaryColor,
                  );
                }, childCount: provider.items.length),
              ),
            ),

            // Estado vacío después del primer intento para sincronizarse con el banner
            if (provider.hasAttemptedLoad &&
                !provider.isLoading &&
                provider.error == null &&
                provider.items.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Center(
                    child: Text(
                      'Aún no hay tabacos',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              ),

            // Loader / fin de lista / error
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: () {
                    if (provider.error != null) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Error al cargar: ${provider.error}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: provider.loadMore,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      );
                    }
                    if (provider.isLoading) {
                      return const CircularProgressIndicator();
                    }
                    if (!provider.hasMore) {
                      return Text(
                        'No hay más resultados',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortDropdown(
    BuildContext context,
    CatalogProvider provider,
    double scaleFactor,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(
        // Animación suave para el popup
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).primaryColor.withOpacity(0.15),
              width: 1,
            ),
          ),
          elevation: 12,
          color: Theme.of(context).cardColor,
        ),
        // Animación de transición suave
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      child: PopupMenuButton<SortOption>(
        onSelected: (SortOption option) {
          provider.setSortOption(option);
        },
        tooltip: 'Ordenar catálogo',
        offset: const Offset(0, 10),
        position: PopupMenuPosition.under,
        splashRadius: 24,
        itemBuilder: (BuildContext context) {
          return [
            // Header del menú
            PopupMenuItem<SortOption>(
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
            // Opciones de ordenamiento
            ...SortOption.values.map((SortOption option) {
              final isSelected = provider.filter.sortOption == option;
              return PopupMenuItem<SortOption>(
                value: option,
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
                        ? Theme.of(context).primaryColor.withOpacity(0.08)
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
                              : Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color?.withOpacity(0.3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option.label,
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
                          _getSortIcon(option),
                          size: 16,
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.6),
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
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
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
                  provider.filter.sortOption.label,
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

  IconData _getSortIcon(SortOption option) {
    switch (option) {
      case SortOption.newest:
        return Icons.schedule;
      case SortOption.oldest:
        return Icons.history;
      case SortOption.nameAsc:
        return Icons.arrow_upward;
      case SortOption.nameDesc:
        return Icons.arrow_downward;
      case SortOption.brandAsc:
        return Icons.business;
      case SortOption.mostPopular:
        return Icons.trending_up;
      case SortOption.topRated:
        return Icons.star;
    }
  }

  Widget _buildBrandDropdown(
    BuildContext context,
    CatalogProvider provider,
    double scaleFactor,
  ) {
    return _BrandFilterDropdown(provider: provider, scaleFactor: scaleFactor);
  }

  Widget _buildTobaccoCard(
    BuildContext context,
    Tobacco tobacco,
    double scaleFactor,
    Color baseColor,
  ) {
    // Ajustar tamaños según el factor de escala del texto
    final iconSize = scaleFactor > 1.5
        ? 32.0
        : (scaleFactor > 1.3 ? 36.0 : 40.0);
    final cardPadding = scaleFactor > 1.3 ? 10.0 : 12.0;
    final bool tightSpacing = scaleFactor < 1.3;

    final Color color = baseColor; // mismo color para todos, como en Community

    return Semantics(
      label:
          '${tobacco.name} de ${tobacco.brand}, calificación ${tobacco.rating} con ${tobacco.reviews} reseñas',
      button: true,
      enabled: true,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TobaccoDetailPage(tobacco: tobacco),
            ),
          );
          // Al volver, refrescar la lista para actualizar ratings/reviews
          // Idealmente solo actualizaríamos el item específico, pero por simplicidad refrescamos
          // ya que los datos vienen del servidor.
          if (context.mounted) {
            context.read<CatalogProvider>().refresh();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.05), // igual que MixCard
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
            ), // igual que MixCard
          ),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Imagen placeholder - ocupa la mayor parte del espacio disponible
                Expanded(
                  flex: scaleFactor > 1.3 ? 4 : 5,
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

                // Contenedor para título y marca con espaciado condicional
                Expanded(
                  flex: scaleFactor > 1.3 ? 4 : 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        tobacco.name,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: tightSpacing ? 2 : 4),
                      Text(
                        tobacco.brand,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Rating y reseñas - siempre en la parte inferior
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ...(() {
                        final hasRating =
                            (tobacco.rating > 0) && (tobacco.reviews > 0);
                        if (hasRating) {
                          return [
                            Icon(
                              Icons.star,
                              size: scaleFactor > 1.3 ? 14 : 16,
                              color: color, // igual que MixCard
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tobacco.rating.toString(),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '(${tobacco.reviews})',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.5),
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ];
                        } else {
                          return [
                            Icon(
                              Icons.star_border,
                              size: scaleFactor > 1.3 ? 14 : 16,
                              color: color, // igual que MixCard
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Sin valoraciones',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.5),
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
}

// Widget dropdown con buscador para filtros de marca
class _BrandFilterDropdown extends StatefulWidget {
  const _BrandFilterDropdown({
    required this.provider,
    required this.scaleFactor,
  });

  final CatalogProvider provider;
  final double scaleFactor;

  @override
  State<_BrandFilterDropdown> createState() => _BrandFilterDropdownState();
}

class _BrandFilterDropdownState extends State<_BrandFilterDropdown> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getFilteredBrands() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      return widget.provider.availableBrands;
    }
    return widget.provider.availableBrands
        .where((brand) => brand.toLowerCase().contains(query))
        .toList();
  }

  void _showBrandFilterMenu() async {
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

    // Usar una constante especial para "Todas las marcas"
    const String allBrandsKey = '__ALL_BRANDS__';

    await showMenu<String?>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).primaryColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      elevation: 12,
      color: Theme.of(context).cardColor,
      items: [
        // Campo de búsqueda
        PopupMenuItem<String?>(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              final filteredBrands = _getFilteredBrands();
              // Leer el brand seleccionado dentro del StatefulBuilder para que se actualice
              final currentSelectedBrand = widget.provider.filter.brand;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (value) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar marca...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color?.withOpacity(0.5),
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.3),
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
                  // Lista de marcas filtradas
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Opción "Todas las marcas"
                          _buildBrandOption(
                            context,
                            allBrandsKey,
                            'Todas las marcas',
                            Icons.filter_list,
                            currentSelectedBrand: currentSelectedBrand,
                            isAllBrandsOption: true,
                          ),
                          // Marcas filtradas
                          ...filteredBrands.map(
                            (brand) => _buildBrandOption(
                              context,
                              brand,
                              brand,
                              Icons.business,
                              currentSelectedBrand: currentSelectedBrand,
                            ),
                          ),
                          // Mensaje cuando no hay resultados
                          if (filteredBrands.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'No se encontraron marcas',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.5),
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ).then((value) {
      // Si el usuario seleccionó algo
      if (value != null) {
        // Si seleccionó "Todas las marcas", pasar null al provider
        if (value == allBrandsKey) {
          widget.provider.setFilterByBrand(null);
        } else {
          widget.provider.setFilterByBrand(value);
        }
      }
      _searchController.clear();
    });
  }

  Widget _buildBrandOption(
    BuildContext context,
    String? brand,
    String displayText,
    IconData icon, {
    required String? currentSelectedBrand,
    bool isAllBrandsOption = false,
  }) {
    final isSelected = isAllBrandsOption
        ? currentSelectedBrand == null
        : currentSelectedBrand == brand;

    return InkWell(
      onTap: () {
        Navigator.of(context).pop(brand);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.08)
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
                    ).textTheme.bodyMedium?.color?.withOpacity(0.3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayText,
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
                color: Theme.of(context).primaryColor.withOpacity(0.6),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedBrand = widget.provider.filter.brand;
    final displayText = selectedBrand ?? 'Todas las marcas';

    return GestureDetector(
      onTap: _showBrandFilterMenu,
      child: Container(
        height: widget.scaleFactor > 1.5
            ? 50
            : (widget.scaleFactor > 1.3 ? 44 : 40),
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
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: 18,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
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
          ],
        ),
      ),
    );
  }
}
