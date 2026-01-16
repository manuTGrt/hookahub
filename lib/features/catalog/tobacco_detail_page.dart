import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/tobacco.dart';
import '../../core/models/review.dart';
import '../../widgets/mix_card.dart';
import '../../widgets/app_segmented_control.dart';
import '../../widgets/tobacco_image.dart';
import '../community/presentation/community_provider.dart'; // Import provider
import 'presentation/providers/tobacco_mixes_provider.dart';
import '../community/presentation/mix_detail_page.dart'; // Import necesario para navegar al detalle

class TobaccoDetailPage extends StatelessWidget {
  const TobaccoDetailPage({super.key, required this.tobacco});

  final Tobacco tobacco;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TobaccoMixesProvider(
        context
            .read<CommunityProvider>()
            .repository, // Acceder al repo a través del provider
      ),
      child: _TobaccoDetailView(tobacco: tobacco),
    );
  }
}

class _TobaccoDetailView extends StatefulWidget {
  const _TobaccoDetailView({required this.tobacco});

  final Tobacco tobacco;

  @override
  State<_TobaccoDetailView> createState() => _TobaccoDetailViewState();
}

class _TobaccoDetailViewState extends State<_TobaccoDetailView> {
  // 0 => Mezclas, 1 => Reseñas
  int _segment = 0;

  // Datos de ejemplo para reseñas (se mantienen hardcoded por ahora según plan,
  // el foco es arreglar mixes)
  late final List<Review> _reviews;

  // Controladores
  final _reviewController = TextEditingController();
  final _scrollController = ScrollController();
  double _newRating = 0;

  // Formatea la descripción: todo en minúsculas excepto la primera letra.
  String _prettyDescription(String? text) {
    if (text == null) return 'Sin descripción';
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Sin descripción';
    final lower = trimmed.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  @override
  void initState() {
    super.initState();
    // Cargar mezclas reales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TobaccoMixesProvider>().loadMixes(
        tobaccoName: widget.tobacco.name,
        tobaccoBrand: widget.tobacco.brand,
      );
    });

    // Listener para paginación
    _scrollController.addListener(_onScroll);

    _reviews = [
      Review(
        id: 'r1',
        author: 'SmokeWizard',
        rating: 4.0,
        comment: 'Sabor limpio y fresco, ideal para mezclar con cítricos.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Review(
        id: 'r2',
        author: 'MixMaster',
        rating: 5.0,
        comment: 'Mi básico de cabecera. En frío rinde de lujo.',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<TobaccoMixesProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final headerHeight = media.size.height / 3; // tercio de pantalla

    return Scaffold(
      // Sin AppBar: elimina completamente la barra de navegación superior
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              tobacco: widget.tobacco,
              height: headerHeight,
              onBack: () => Navigator.of(context).pop(),
              onShare: _handleShare,
            ),
          ),
          // Descripción (sección "Sabores")
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  // Igual que MixCard: fondo tintado y borde con el color base (corazón)
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Acento superior sutil para un acabado elegante
                    Container(
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          // Degradado partiendo del color del "corazón" (mismo que MixCard)
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sabores',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _prettyDescription(widget.tobacco.description),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Segmento Mezclas/Reseñas
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppSegmentedControl(
                segments: const ['Mezclas', 'Reseñas'],
                currentIndex: _segment,
                onChanged: (i) => setState(() => _segment = i),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (_segment == 0)
            _buildMixesSliver(context)
          else
            _buildReviewsSliver(context),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // Mezclas de la comunidad que usan este tabaco (Reales)
  Widget _buildMixesSliver(BuildContext context) {
    return Consumer<TobaccoMixesProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.mixes.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (provider.error != null && provider.mixes.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'Error al cargar mezclas',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          );
        }

        if (provider.mixes.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 48,
                      color: Theme.of(context).disabledColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay mezclas con este tabaco aún',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: provider.mixes.length + (provider.hasMoreData ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index >= provider.mixes.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                );
              }

              final m = provider.mixes[index];
              return MixCard(
                mix: m,
                isFavorite:
                    false, // TODO: Conectar con favoritos si es necesario
                onFavoriteTap: () {},
                onShare: () => Share.share('Mira esta mezcla: ${m.name}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MixDetailPage(mix: m)),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // Reseñas: estadísticas, formulario y lista
  Widget _buildReviewsSliver(BuildContext context) {
    final avg = _reviews.isEmpty
        ? widget.tobacco.rating
        : _reviews.map((e) => e.rating).reduce((a, b) => a + b) /
              _reviews.length;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _ReviewStats(average: avg, total: _reviews.length),
          const SizedBox(height: 16),
          _ReviewForm(
            controller: _reviewController,
            rating: _newRating,
            onRatingChanged: (v) => setState(() => _newRating = v),
            onSubmit: _handleSubmitReview,
          ),
          const SizedBox(height: 16),
          ..._reviews.map((r) => _ReviewTile(review: r)).toList(),
        ]),
      ),
    );
  }

  void _handleShare() {
    final t = widget.tobacco;
    final text = 'Echa un vistazo a ${t.brand} - ${t.name} en Hookahub';
    Share.share(text);
  }

  void _handleSubmitReview() {
    if (_reviewController.text.trim().isEmpty || _newRating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade comentario y puntuación')),
      );
      return;
    }
    final newReview = Review(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: 'Tú',
      rating: _newRating,
      comment: _reviewController.text.trim(),
      createdAt: DateTime.now(),
    );
    setState(() {
      _reviews.insert(0, newReview);
      _reviewController.clear();
      _newRating = 0;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reseña publicada')));
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.tobacco,
    required this.height,
    required this.onBack,
    required this.onShare,
  });

  final Tobacco tobacco;
  final double height;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final brandStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Colors.white.withOpacity(0.9),
      letterSpacing: 0.5,
    );
    final nameStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      shadows: const [Shadow(color: Colors.black26, blurRadius: 6)],
    );

    return Stack(
      children: [
        // Imagen de fondo con caché optimizado
        TobaccoImage(
          imageUrl: tobacco.imageUrl,
          width: double.infinity,
          height: height,
          borderRadius: 0,
          placeholderColor:
              tobacco.placeholderColor ?? Theme.of(context).primaryColor,
          fit: BoxFit.cover,
        ),
        // Gradiente para legibilidad
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.35),
                  Colors.transparent,
                  Colors.black.withOpacity(0.45),
                ],
              ),
            ),
          ),
        ),
        // Flecha atrás (arriba izquierda)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleButton(icon: Icons.arrow_back, onTap: onBack),
                _CircleButton(icon: Icons.share, onTap: onShare),
              ],
            ),
          ),
        ),
        // Marca y nombre (abajo izquierda)
        Positioned(
          left: 16,
          bottom: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tobacco.brand, style: brandStyle),
              const SizedBox(height: 4),
              Text(
                tobacco.name,
                style: nameStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

// Reemplazado _Segmented por AppSegmentedControl reutilizable.

class _ReviewStats extends StatelessWidget {
  const _ReviewStats({required this.average, required this.total});
  final double average;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            average.toStringAsFixed(1),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(
            '($total reseñas)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

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
  const _ReviewTile({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
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
              Text(
                _timeAgo(review.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(review.comment),
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
