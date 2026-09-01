import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../domain/onboarding_item.dart';
import 'onboarding_provider.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingPage({super.key, required this.onFinish});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage(OnboardingProvider provider) {
    if (provider.isLastPage) {
      _finishOnboarding(provider);
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _finishOnboarding(OnboardingProvider provider) async {
    await provider.completeOnboarding();
    if (mounted) {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final items = provider.items;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: MediaQuery.withClampedTextScaling(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.3,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      // ── Barra Superior: Indicador de marca y botón 'Saltar' ──
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Hookahub',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 250),
                              opacity: provider.isLastPage ? 0.0 : 1.0,
                              child: TextButton(
                                onPressed: provider.isLastPage
                                    ? null
                                    : () => _finishOnboarding(provider),
                                style: TextButton.styleFrom(
                                  foregroundColor: isDark ? darkNavy : navy,
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Saltar'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Carrusel Principal (PageView) ──
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: items.length,
                          onPageChanged: provider.setCurrentIndex,
                          itemBuilder: (context, index) {
                            return _buildPageSlide(
                              context: context,
                              item: items[index],
                              isDark: isDark,
                              primary: primary,
                              constraints: constraints,
                            );
                          },
                        ),
                      ),

                      // ── Barra Inferior: Indicadores de Página y Botones de Acción ──
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 16.0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Indicadores de Puntos (Dots)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                items.length,
                                (index) => _buildDot(
                                  index: index,
                                  currentIndex: provider.currentIndex,
                                  primary: primary,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Botón de Acción Principal (CTA)
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: () => _nextPage(provider),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Text(
                                    provider.isLastPage
                                        ? 'Comenzar experiencia'
                                        : 'Siguiente',
                                    key: ValueKey<bool>(provider.isLastPage),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Construye cada Slide individual del carrusel
  Widget _buildPageSlide({
    required BuildContext context,
    required OnboardingItem item,
    required bool isDark,
    required Color primary,
    required BoxConstraints constraints,
  }) {
    final isCompact = constraints.maxHeight < 700;
    final cardBg = isDark ? fieldDark : fieldLight;
    final titleColor = isDark ? Colors.white : navy;
    final descColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : navy.withValues(alpha: 0.75);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: isCompact ? 8 : 16),

          // ── Contenedor Heroico / Ilustración ──
          Container(
            width: isCompact ? 140 : 180,
            height: isCompact ? 140 : 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cardBg,
              border: Border.all(
                color: primary.withValues(alpha: 0.35),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: isDark ? 0.2 : 0.15),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                item.icon,
                size: isCompact ? 64 : 84,
                color: primary,
              ),
            ),
          ),
          SizedBox(height: isCompact ? 16 : 24),

          // ── Badge de Categoría ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              item.badgeText,
              style: TextStyle(
                color: primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Título Emocional ──
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCompact ? 22 : 26,
              fontWeight: FontWeight.w800,
              color: titleColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // ── Cuerpo de Texto (UX Copy) ──
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCompact ? 13 : 15,
              color: descColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),

          // ── Chips de Características Relevantes ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: item.highlights.map((tag) {
              return Container(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth - 48,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E282C) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? turquoiseSecondaryDark
                        : turquoise.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? darkNavy : navy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          SizedBox(height: isCompact ? 10 : 20),
        ],
      ),
    );
  }

  /// Construye el indicador animado de paginación
  Widget _buildDot({
    required int index,
    required int currentIndex,
    required Color primary,
    required bool isDark,
  }) {
    final isActive = index == currentIndex;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8,
      width: isActive ? 28 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? primary
            : (isDark ? fieldDark : Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
