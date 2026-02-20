import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/mix.dart';
import '../../favorites/favorites_provider.dart';
import '../../../widgets/mix_card.dart';
import '../../../widgets/tobacco_card.dart';
import '../../../core/models/tobacco.dart';
import '../../catalog/tobacco_detail_page.dart';
import '../../../core/models/review.dart';
import '../../../widgets/app_segmented_control.dart';
import 'community_provider.dart';
import 'create_mix_page.dart';
import '../../catalog/data/tobacco_repository.dart';
import '../../../core/data/supabase_service.dart';
import '../../history/presentation/history_provider.dart';
import '../../../core/providers/database_health_provider.dart';

/// Convierte una cadena a Title Case (primera letra de cada palabra en mayúscula).
String _toTitleCase(String text) {
  if (text.isEmpty) return text;
  return text
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

/// Convierte una cadena a Capital Case (solo la primera letra en mayúscula).
String _toCapitalCase(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}

/// Datos de un componente de la mezcla (tabaco concreto)
class MixComponent {
  final String tobacco; // nombre del tabaco (sabor)
  final String brand; // marca
  final double percentage; // 0..100
  final Color color; // color para leyenda y gráfico
  final String? description; // descripción del tabaco
  final Tobacco? catalog; // objeto real del catálogo si se resolvió

  const MixComponent({
    required this.tobacco,
    required this.brand,
    required this.percentage,
    required this.color,
    this.description,
    this.catalog,
  });
}

class MixDetailPage extends StatefulWidget {
  const MixDetailPage({super.key, required this.mix});

  final Mix mix;

  @override
  State<MixDetailPage> createState() => _MixDetailPageState();
}

class _MixDetailPageState extends State<MixDetailPage> {
  int _segment = 0; // 0 = Relacionadas, 1 = Reseñas

  // Estado de carga de detalles
  bool _isLoading = true;
  String _description = 'Sin descripción disponible.';
  List<MixComponent> _components = [];
  bool _isMyMix = false; // Propiedad del recurso

  // Estado de mezclas relacionadas
  bool _loadingRelated = true;
  List<Mix> _relatedMixes = [];

  // Estado de reseñas para la mezcla
  bool _loadingReviews = true;
  final List<Review> _reviews = [];
  final _reviewController = TextEditingController();
  double _newRating = 0;

  // Mix actualizado con rating/reviews en tiempo real
  late Mix _currentMix;
  StreamSubscription<void>? _reconnectedSub;

  @override
  void initState() {
    super.initState();
    _currentMix = widget.mix;
    _reconnectedSub = DatabaseHealthProvider.instance.onReconnected.listen((_) {
      if (!mounted) return;
      unawaited(_initializeData());
    });
    // Cargar mezcla completa primero si es necesario, luego cargar el resto
    _initializeData();
  }

  /// Inicializa todos los datos de la página
  Future<void> _initializeData() async {
    await _loadFullMixIfNeeded();
    _loadMixDetails();
    _loadRelatedMixes();
    _loadReviews();
    _checkOwnership();
    _recordVisit();
  }

  /// Recarga la mezcla completa si viene con datos incompletos (ej: desde notificaciones)
  Future<void> _loadFullMixIfNeeded() async {
    // Si el autor es "Cargando..." o los ingredientes están vacíos, recargar
    if (widget.mix.author == 'Cargando...' || widget.mix.ingredients.isEmpty) {
      try {
        final repository = context.read<CommunityProvider>().repository;
        final fullMix = await repository.fetchMixById(widget.mix.id);

        if (fullMix != null && mounted) {
          setState(() {
            _currentMix = fullMix;
          });
        }
      } catch (e) {
        debugPrint('Error al recargar mezcla completa: $e');
      }
    }
  }

  /// Registra la visita a esta mezcla en el historial del usuario
  void _recordVisit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final historyProvider = context.read<HistoryProvider>();
        historyProvider.recordView(widget.mix.id, silent: true);
      } catch (e) {
        // Ignorar si el provider no está disponible
        debugPrint('No se pudo registrar visita en historial: $e');
      }
    });
  }

  Future<void> _checkOwnership() async {
    try {
      final repository = context.read<CommunityProvider>().repository;
      final mine = await repository.isMyMix(widget.mix.id);
      if (mounted) {
        setState(() => _isMyMix = mine);
      }
    } catch (_) {
      // Ignorar fallos; por defecto no mostrar acciones
    }
  }

  Future<void> _loadMixDetails() async {
    try {
      final repository = context.read<CommunityProvider>().repository;
      final details = await repository.fetchMixDetails(widget.mix.id);

      if (details != null && mounted) {
        _description = details['description'] as String;
        final componentsData = details['components'] as List;
        final loaded = componentsData
            .map(
              (c) => MixComponent(
                tobacco: c['tobacco_name'] as String,
                brand: c['brand'] as String,
                percentage: c['percentage'] as double,
                color: c['color'] as Color,
                description: (c['description'] as String?)?.trim(),
              ),
            )
            .toList();
        final distinct = _assignDistinctColors(loaded);
        final enriched = await _resolveCatalogForComponents(distinct);
        if (!mounted) return;
        setState(() {
          _components = enriched;
          _isLoading = false;
        });
        // Cargar mezclas relacionadas ahora que tenemos componentes
        _loadRelatedMixes();
      } else if (mounted) {
        // Si no hay detalles, usar datos generados
        setState(() {
          _components = _buildComponentsFromIngredients(context, widget.mix);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _components = _buildComponentsFromIngredients(context, widget.mix);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRelatedMixes() async {
    if (_components.isEmpty) {
      // Esperar a que se carguen los componentes primero
      await Future.delayed(const Duration(milliseconds: 100));
      if (_components.isEmpty && mounted) {
        setState(() => _loadingRelated = false);
        return;
      }
    }

    try {
      final repository = context.read<CommunityProvider>().repository;
      final tobaccoNames = _components.map((c) => c.tobacco).toList();

      final related = await repository.fetchRelatedMixes(
        currentMixId: widget.mix.id,
        tobaccoNames: tobaccoNames,
        limit: 3,
      );

      if (mounted) {
        setState(() {
          _relatedMixes = related;
          _loadingRelated = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingRelated = false);
      }
    }
  }

  Future<void> _loadReviews() async {
    try {
      final repository = context.read<CommunityProvider>().repository;
      final reviews = await repository.fetchReviews(widget.mix.id);

      if (mounted) {
        setState(() {
          _reviews.clear();
          _reviews.addAll(
            reviews.map(
              (r) => Review(
                id: r['id'] as String,
                author: r['author'] as String,
                authorId: r['author_id'] as String?,
                rating: r['rating'] as double,
                comment: r['comment'] as String,
                createdAt: r['created_at'] as DateTime,
              ),
            ),
          );
          _loadingReviews = false;

          // Actualizar el mix local con los datos de las reseñas
          _updateLocalMixRating();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingReviews = false);
      }
    }
  }

  /// Actualiza el rating y conteo de reseñas del mix local basándose en las reseñas cargadas
  void _updateLocalMixRating() {
    if (_reviews.isEmpty) {
      _currentMix = _currentMix.copyWith(rating: 0.0, reviews: 0);
    } else {
      final avgRating =
          _reviews.map((r) => r.rating).reduce((a, b) => a + b) /
          _reviews.length;
      _currentMix = _currentMix.copyWith(
        rating: avgRating,
        reviews: _reviews.length,
      );
    }
  }

  @override
  void dispose() {
    _reconnectedSub?.cancel();
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final headerHeight = math.max(220.0, size.height * 0.25);
    final textColorOnHeader = Colors.white;

    // Mostrar indicador de carga mientras se obtienen los detalles
    if (_isLoading) {
      return Scaffold(body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            // Actualizar la mezcla en el provider antes de salir
            context.read<CommunityProvider>().updateMix(_currentMix);
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _HeaderArea(
                height: headerHeight,
                mix: _currentMix,
                textColor: textColorOnHeader,
                isMyMix: _isMyMix,
                onEdit: _handleEditMix,
                onDelete: _handleDeleteMix,
              ),
            ),

            // Descripción
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Descripción',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            // Proporciones
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proporciones',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Legend(components: _components),
                    const SizedBox(height: 16),
                    Center(
                      child: DonutChart(
                        slices: [
                          for (final c in _components)
                            DonutSlice(
                              value: c.percentage / 100.0,
                              color: c.color,
                            ),
                        ],
                        size: 220,
                        strokeWidth: 28,
                        backgroundColor: Theme.of(
                          context,
                        ).dividerColor.withOpacity(0.15),
                        center: _DonutCenter(mix: _currentMix),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Lista de tabacos usados (estilo similar a MixCard, mostrando sabores)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tabacos utilizados',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._components.map((c) {
                      final item = c.catalog;
                      final displayName = _toTitleCase(item?.name ?? c.tobacco);
                      final displayBrand = _toTitleCase(item?.brand ?? c.brand);
                      final rawDescription =
                          (item?.description?.trim().isNotEmpty ?? false)
                          ? item!.description
                          : (c.description?.trim().isNotEmpty ?? false)
                          ? c.description
                          : 'Sin descripción.';
                      final description = _toCapitalCase(
                        rawDescription ?? 'Sin descripción.',
                      );

                      return TobaccoCard(
                        name: displayName,
                        brand: displayBrand,
                        flavors: const [],
                        description: description,
                        color: c.color,
                        onTap: () {
                          final tobacco =
                              item ??
                              Tobacco(
                                id: 'tob-${c.tobacco.toLowerCase().replaceAll(' ', '-')}',
                                name: _toTitleCase(c.tobacco),
                                brand: _toTitleCase(c.brand),
                                flavors: const [],
                                rating: 0,
                                reviews: 0,
                                placeholderColor: c.color,
                              );
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  TobaccoDetailPage(tobacco: tobacco),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Selector dual + contenido
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSegmentedControl(
                      segments: const ['Relacionadas', 'Reseñas'],
                      currentIndex: _segment,
                      onChanged: (i) => setState(() => _segment = i),
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _segment == 0
                          ? _RelatedMixes(
                              mixes: _relatedMixes,
                              isLoading: _loadingRelated,
                            )
                          : _buildReviewsSection(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ), // Cierre de PopScope
    );
  }

  void _handleEditMix() async {
    // Navegar a la pantalla de creación/edición en modo edición
    final updated = await Navigator.of(context).push<Mix>(
      MaterialPageRoute(
        builder: (_) => CreateMixPage(
          currentUser: _currentMix.author,
          mixToEdit: _currentMix,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _currentMix = updated;
      });
      // Recargar detalles para reflejar cambios en descripción/componentes
      await _loadMixDetails();
      await _loadRelatedMixes();
    }
  }

  Future<void> _handleDeleteMix() async {
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

    if (confirmed != true) return;

    try {
      final provider = context.read<CommunityProvider>();
      final ok = await provider.deleteMix(widget.mix.id);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mezcla eliminada')));
        Navigator.of(context).maybePop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar la mezcla')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar la mezcla')),
        );
      }
    }
  }

  Widget _buildReviewsSection(BuildContext context) {
    if (_loadingReviews) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      key: const ValueKey('mix-reviews'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReviewForm(
          controller: _reviewController,
          rating: _newRating,
          onRatingChanged: (v) => setState(() => _newRating = v),
          onSubmit: _handleSubmitReview,
        ),
        const SizedBox(height: 16),
        if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Sé el primero en reseñar esta mezcla',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ),
          )
        else
          ..._reviews
              .map(
                (r) => _ReviewTile(
                  review: r,
                  onDelete: () => _handleDeleteReview(r.id),
                  onEdit: () => _handleEditReview(r),
                ),
              )
              .toList(),
      ],
    );
  }

  void _handleDeleteReview(String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar reseña'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta reseña?',
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

    if (confirmed != true) return;

    try {
      final repository = context.read<CommunityProvider>().repository;
      final success = await repository.deleteReview(reviewId, widget.mix.id);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reseña eliminada')));
        await _loadReviews();
        // Ya no necesitamos llamar a _updateMixRating aquí, el repositorio lo hace
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar reseña')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar reseña')),
        );
      }
    }
  }

  void _handleEditReview(Review review) {
    // Variables locales para el diálogo
    double dialogRating = review.rating;
    final dialogController = TextEditingController(text: review.comment);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar reseña'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StarInput(
                  value: dialogRating,
                  onChanged: (v) {
                    setDialogState(() {
                      dialogRating = v;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dialogController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Comparte tu experiencia...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                dialogController.dispose();
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                if (dialogController.text.trim().isEmpty || dialogRating <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Añade comentario y puntuación'),
                    ),
                  );
                  return;
                }

                try {
                  final repository = context
                      .read<CommunityProvider>()
                      .repository;
                  final success = await repository.updateReview(
                    reviewId: review.id,
                    mixId: widget.mix.id,
                    rating: dialogRating,
                    comment: dialogController.text.trim(),
                  );

                  if (!mounted) return;

                  dialogController.dispose();
                  Navigator.of(context).pop();

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reseña actualizada')),
                    );
                    await _loadReviews();
                    // Ya no necesitamos llamar a _updateMixRating aquí, el repositorio lo hace
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error al actualizar reseña'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    dialogController.dispose();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error al actualizar reseña'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmitReview() {
    if (_reviewController.text.trim().isEmpty || _newRating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade comentario y puntuación')),
      );
      return;
    }

    _submitReviewToDatabase();
  }

  Future<void> _submitReviewToDatabase() async {
    final comment = _reviewController.text.trim();
    final rating = _newRating;

    try {
      final repository = context.read<CommunityProvider>().repository;
      final success = await repository.createReview(
        mixId: widget.mix.id,
        rating: rating,
        comment: comment,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reseña publicada')));

        // Limpiar formulario
        setState(() {
          _reviewController.clear();
          _newRating = 0;
        });

        // Recargar reseñas (el repositorio ya actualizó el rating de la mezcla)
        await _loadReviews();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al publicar reseña')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al publicar reseña')),
        );
      }
    }
  }

  List<MixComponent> _buildComponentsFromIngredients(
    BuildContext context,
    Mix mix,
  ) {
    // Paleta turquesa basada en el color primario (desplazando el tono)
    final base = Theme.of(context).primaryColor;
    final palette = _turquoisePaletteFrom(
      base,
      count: math.max(3, mix.ingredients.length),
    );

    final parts = mix.ingredients.length;
    // Distribución simple: reparte 100 en partes decrecientes (p.e. 50/30/20 para 3)
    final defaults = <int, List<double>>{
      1: [100],
      2: [60, 40],
      3: [50, 30, 20],
      4: [40, 30, 20, 10],
    };
    final distribution = defaults[parts] ?? List.filled(parts, (100.0 / parts));

    return List.generate(parts, (i) {
      final ing = mix.ingredients[i];
      return MixComponent(
        tobacco: ing,
        brand: 'Marca ${String.fromCharCode(65 + i)}',
        percentage: distribution[i],
        color: palette[i % palette.length],
      );
    });
  }

  // Asegura que cada componente tenga un color distinto para el gráfico/leyenda
  List<MixComponent> _assignDistinctColors(List<MixComponent> comps) {
    if (comps.isEmpty) return comps;
    final palette = _turquoisePaletteFrom(
      Theme.of(context).primaryColor,
      count: comps.length,
    );
    return List.generate(comps.length, (i) {
      final c = comps[i];
      return MixComponent(
        tobacco: c.tobacco,
        brand: c.brand,
        percentage: c.percentage,
        color: palette[i % palette.length],
        description: c.description,
        catalog: c.catalog,
      );
    });
  }

  Future<List<MixComponent>> _resolveCatalogForComponents(
    List<MixComponent> comps,
  ) async {
    if (comps.isEmpty) return comps;
    final repo = TobaccoRepository(SupabaseService());
    final futures = comps.map((c) async {
      try {
        final item = await repo.findByNameAndBrand(
          name: c.tobacco,
          brand: c.brand,
        );
        return MixComponent(
          tobacco: c.tobacco,
          brand: c.brand,
          percentage: c.percentage,
          color: c.color,
          description: c.description,
          catalog: item,
        );
      } catch (_) {
        return c; // si falla, deja el existente
      }
    }).toList();
    return await Future.wait(futures);
  }
}

class _HeaderArea extends StatelessWidget {
  const _HeaderArea({
    required this.height,
    required this.mix,
    required this.textColor,
    required this.isMyMix,
    required this.onEdit,
    required this.onDelete,
  });
  final double height;
  final Mix mix;
  final Color textColor;
  final bool isMyMix;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fav = context.watch<FavoritesProvider>();
    final isFav = fav.favorites.any((x) => x.id == mix.id);

    // Degradado equilibrado usando solo los dos primeros tonos.
    final gradient = const LinearGradient(
      colors: [
        Color(0xFF4E9891), // medio (swatch[4])
        Color(0xFF1AA6B8), // brillante azulado (swatch[9])
      ],
      stops: [0.0, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Stack(
        children: [
          // Botón atrás
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'Volver',
            ),
          ),
          // Acciones derecha
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: textColor,
                  ),
                  tooltip: isFav ? 'Quitar de favoritas' : 'Añadir a favoritas',
                  onPressed: () {
                    if (isFav) {
                      fav.removeFavorite(mix.id);
                    } else {
                      fav.addFavorite(mix);
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.share_outlined, color: textColor),
                  tooltip: 'Compartir',
                  onPressed: () {
                    final text = 'Mezcla: ${mix.name} por ${mix.author}';
                    Share.share(text);
                  },
                ),
                if (isMyMix)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: textColor),
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete),
                            SizedBox(width: 8),
                            Text('Eliminar'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Título y autor en esquina inferior izquierda
          Positioned(
            left: 16,
            bottom: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mix.author,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: textColor.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  mix.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.components});
  final List<MixComponent> components;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final c in components)
          _LegendItem(
            color: c.color,
            label:
                '${c.percentage.toStringAsFixed(0)}% • ${_toTitleCase(c.tobacco)} — ${_toTitleCase(c.brand)}',
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class DonutSlice {
  final double value; // 0..1
  final Color color;
  DonutSlice({required this.value, required this.color});
}

class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.size = 200,
    this.strokeWidth = 24,
    this.backgroundColor,
    this.center,
  });
  final List<DonutSlice> slices;
  final double size;
  final double strokeWidth;
  final Color? backgroundColor;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(
              slices: slices,
              strokeWidth: strokeWidth,
              backgroundColor: backgroundColor ?? Colors.transparent,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.strokeWidth,
    required this.backgroundColor,
  });
  final List<DonutSlice> slices;
  final double strokeWidth;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final startAngle = -math.pi / 2; // empieza arriba
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = strokeWidth;

    // fondo
    if (backgroundColor.opacity > 0) {
      paint.color = backgroundColor;
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        0,
        2 * math.pi,
        false,
        paint,
      );
    }

    double angle = startAngle;
    final total = slices
        .fold<double>(0, (a, b) => a + b.value)
        .clamp(0.0001, 1.0);
    for (final s in slices) {
      final sweep = 2 * math.pi * (s.value / total);
      paint.color = s.color;
      canvas.drawArc(rect.deflate(strokeWidth / 2), angle, sweep, false, paint);
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _DonutCenter extends StatelessWidget {
  const _DonutCenter({required this.mix});
  final Mix mix;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_fire_department,
          color: Theme.of(context).primaryColor,
          size: 24,
        ),
        const SizedBox(height: 6),
        Text(
          '${mix.rating > 0 ? mix.rating.toStringAsFixed(1) : '—'}',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          mix.reviews == 0
              ? 'Sin reseñas'
              : mix.reviews == 1
              ? '1 reseña'
              : '${mix.reviews} reseñas',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

// SegmentedControl antiguo sustituido por AppSegmentedControl reutilizable.

class _RelatedMixes extends StatelessWidget {
  const _RelatedMixes({required this.mixes, required this.isLoading});

  final List<Mix> mixes;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (mixes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No se encontraron mezclas relacionadas',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
        ),
      );
    }

    final fav = context.watch<FavoritesProvider>();
    return Column(
      children: [
        for (final m in mixes)
          MixCard(
            mix: m,
            isFavorite: fav.favorites.any((x) => x.id == m.id),
            onFavoriteTap: () {
              final isFav = fav.favorites.any((x) => x.id == m.id);
              if (isFav) {
                fav.removeFavorite(m.id);
              } else {
                fav.addFavorite(m);
              }
            },
            onShare: () => Share.share('Mezcla: ${m.name} por ${m.author}'),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => MixDetailPage(mix: m)));
            },
          ),
      ],
    );
  }
}

// Reutilización de componentes de reseñas similares a la página de tabaco.

class _ReviewForm extends StatelessWidget {
  const _ReviewForm({
    required this.controller,
    required this.rating,
    required this.onRatingChanged,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final double rating;
  final ValueChanged<double> onRatingChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Escribe una reseña',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _StarInput(value: rating, onChanged: onRatingChanged),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Comparte tu experiencia... ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.send),
              label: const Text('Publicar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarInput extends StatelessWidget {
  const _StarInput({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < value.round();
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            filled ? Icons.star : Icons.star_border,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () => onChanged((i + 1).toDouble()),
        );
      }),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.review,
    required this.onDelete,
    required this.onEdit,
  });

  final Review review;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    // Obtener el usuario actual para verificar si es el autor
    final supabase = SupabaseService();
    final currentUserId = supabase.client.auth.currentUser?.id;
    final isMyReview =
        currentUserId != null && currentUserId == review.authorId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  review.author.isNotEmpty
                      ? review.author[0].toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < review.rating.round()
                              ? Icons.star
                              : Icons.star_border,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isMyReview)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete),
                          SizedBox(width: 8),
                          Text('Eliminar'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(review.comment),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _timeAgo(review.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return '${diff.inDays}d';
    if (diff.inHours >= 1) return '${diff.inHours}h';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
    return 'ahora';
  }
}

// Paleta fija inspirada en la imagen adjunta (turquesas de claro a oscuro y
// algunas variantes más azules). Mantener el orden para buena separación.
const List<Color> _kTurquoiseSwatches = [
  Color(0xFF87DAD2), // turquesa claro
  Color(0xFF6FC2B9), // turquesa medio claro
  Color(0xFF5AA79E), // turquesa atenuado
  Color(0xFF4E9891), // verde-azulado medio
  Color(0xFF3A8780), // turquesa medio
  Color(0xFF2F7370), // turquesa oscuro 1
  Color(0xFF245F5C), // turquesa oscuro 2
  Color(0xFF1A4E4B), // turquesa muy oscuro
  Color(0xFF1AA6B8), // más azulado brillante
  Color(0xFF0F96A6), // azul turquesa
  Color(0xFF0A8EA0), // azul turquesa oscuro
];

List<Color> _turquoisePaletteFrom(Color base, {int count = 4}) {
  // Selecciona `count` colores espaciados dentro de la paleta fija.
  if (count <= 0) return const [];
  if (count == 1) return [_kTurquoiseSwatches[5]]; // tono central

  final last = _kTurquoiseSwatches.length - 1;
  final indices = List<int>.generate(
    count,
    (i) => ((i * last) / (count - 1)).round(),
  );
  final colors = indices.map((i) => _kTurquoiseSwatches[i]).toList();

  // Si piden más que la paleta, ciclar pero con desfase para mantener contraste.
  if (count > _kTurquoiseSwatches.length) {
    for (int i = _kTurquoiseSwatches.length; i < count; i++) {
      colors.add(_kTurquoiseSwatches[(i * 3) % _kTurquoiseSwatches.length]);
    }
  }
  return colors;
}
