import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../constants.dart';

/// Utilidad centralizada de toasts. Sustituye a ScaffoldMessenger.showSnackBar.
///
/// Uso:
///   AppToast.showSuccess(context, 'Mezcla guardada');
///   AppToast.showError(context, 'Error al guardar');
///   AppToast.showInfo(context, 'Cambios aplicados');
class AppToast {
  // ─── API pública ────────────────────────────────────────────────────────────

  static void showSuccess(BuildContext context, String message) =>
      _show(context: context, message: message, config: _ToastConfig.success());

  static void showError(BuildContext context, String message) =>
      _show(context: context, message: message, config: _ToastConfig.error());

  static void showInfo(BuildContext context, String message) =>
      _show(context: context, message: message, config: _ToastConfig.info());

  // ─── Lógica interna ─────────────────────────────────────────────────────────

  static void _show({
    required BuildContext context,
    required String message,
    required _ToastConfig config,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    toastification.showCustom(
      context: context,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 4),
      animationBuilder: (ctx, animation, alignment, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
            child: child,
          ),
        );
      },
      builder: (ctx, holder) => _AppToastWidget(
        message: message,
        config: config,
        isDark: isDark,
        holder: holder,
      ),
    );
  }
}

// ─── Configuración por tipo ────────────────────────────────────────────────────

class _ToastConfig {
  final IconData icon;
  final Color accentColor;
  final Color darkSurface;
  final Color lightSurface;
  final String label;

  const _ToastConfig({
    required this.icon,
    required this.accentColor,
    required this.darkSurface,
    required this.lightSurface,
    required this.label,
  });

  factory _ToastConfig.success() => const _ToastConfig(
    icon: Icons.check_circle_rounded,
    accentColor: turquoiseDark,
    darkSurface: Color(0xFF172A28),
    lightSurface: Color(0xFFE8FAF8),
    label: 'Éxito',
  );

  factory _ToastConfig.error() => const _ToastConfig(
    icon: Icons.cancel_rounded,
    accentColor: warningRed,
    darkSurface: warningSurfaceDark,
    lightSurface: warningSurfaceLight,
    label: 'Error',
  );

  factory _ToastConfig.info() => const _ToastConfig(
    icon: Icons.info_rounded,
    accentColor: pastelBlue,
    darkSurface: Color(0xFF192230),
    lightSurface: Color(0xFFEBF3FC),
    label: 'Info',
  );
}

// ─── Widget del toast ─────────────────────────────────────────────────────────

class _AppToastWidget extends StatelessWidget {
  const _AppToastWidget({
    required this.message,
    required this.config,
    required this.isDark,
    required this.holder,
  });

  final String message;
  final _ToastConfig config;
  final bool isDark;
  final ToastificationItem holder;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? config.darkSurface : config.lightSurface;
    final textColor = isDark ? Colors.white : navy;
    final accentColor = config.accentColor;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity!.abs() > 200) {
          toastification.dismiss(holder);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accentColor,
            width: 1.0,
          ),

        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ── Contenido principal ───────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Icono circular con fondo tintado
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.15),
                          ),
                          child: Icon(
                            config.icon,
                            color: accentColor,
                            size: 22,
                          ),
                        ),

                        const SizedBox(width: 14),

                        // Textos
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                config.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                message,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                       ],
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
