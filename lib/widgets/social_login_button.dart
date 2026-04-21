import 'package:flutter/material.dart';

/// A modern, branded social login button with press animation.
/// Supports Google out of the box via [SocialProvider].
enum SocialProvider { google }

class SocialLoginButton extends StatefulWidget {
  const SocialLoginButton({
    super.key,
    required this.provider,
    required this.onPressed,
    this.isLoading = false,
  });

  final SocialProvider provider;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<SocialLoginButton> createState() => _SocialLoginButtonState();
}

class _SocialLoginButtonState extends State<SocialLoginButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.04,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  // ── Provider metadata ──────────────────────────────────────────────────────
  String get _label {
    switch (widget.provider) {
      case SocialProvider.google:
        return 'Continuar con Google';
    }
  }

  String get _assetPath {
    switch (widget.provider) {
      case SocialProvider.google:
        return 'assets/logos/google_logo.png';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Surface colour adapting to theme
    final Color surfaceBg =
        isDark ? const Color(0xFF243038) : const Color(0xFFF5FFFE);

    // Border uses the app's primary turquoise (same as inputs/buttons)
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color borderColor = primaryColor.withOpacity(isDark ? 0.55 : 0.40);

    final Color textColor =
        isDark ? const Color(0xFFDFEFED) : const Color(0xFF1A2326);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.onPressed != null) _scaleController.forward();
        },
        onTapUp: (_) {
          _scaleController.reverse();
          widget.onPressed?.call();
        },
        onTapCancel: () => _scaleController.reverse(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: surfaceBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: widget.isLoading
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        _assetPath,
                        width: 24,
                        height: 24,
                        filterQuality: FilterQuality.high,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          // Clamp text scaling so the button never overflows
                          // when the user has a large system font size set.
                          textScaler: MediaQuery.textScalerOf(
                            context,
                          ).clamp(maxScaleFactor: 1.2),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            letterSpacing: 0.2,
                          ),
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
