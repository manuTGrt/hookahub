import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/onboarding_item.dart';

/// Estado y lógica de negocio para la secuencia de Onboarding.
class OnboardingProvider extends ChangeNotifier {
  static const String _seenKey = 'has_completed_onboarding_v1';

  int _currentIndex = 0;
  bool _hasCompleted = false;
  bool _isLoading = true;

  int get currentIndex => _currentIndex;
  bool get hasCompleted => _hasCompleted;
  bool get isLoading => _isLoading;
  bool get isLastPage => _currentIndex == items.length - 1;

  final List<OnboardingItem> items = const [
    OnboardingItem(
      title: 'El mayor catálogo de tabacos',
      description:
          'Explora cientos de marcas, sabores y perfiles aromáticos. Encuentra siempre la base ideal para tu sesión.',
      icon: Icons.auto_stories_rounded,
      badgeText: 'CATÁLOGO COMPLETO',
      highlights: ['+500 Sabores', 'Opiniones reales', 'Filtros avanzados'],
    ),
    OnboardingItem(
      title: 'Crea mezclas con precisión',
      description:
          'Ajusta porcentajes exactos, balancea intensidades y documenta tus recetas secretas como un auténtico maestro.',
      icon: Icons.donut_small_outlined,
      badgeText: 'LABORATORIO',
      highlights: [
        'Proporciones exactas',
        'Recetas propias',
        'Cálculo automático',
      ],
    ),
    OnboardingItem(
      title: 'Inspiración de la comunidad',
      description:
          'Descubre las combinaciones más valoradas en tiempo real, califica recetas y comparte tus éxitos con el mundo.',
      icon: Icons.stars_rounded,
      badgeText: 'COMUNIDAD EN VIVO',
      highlights: ['Top Rankings', 'Reseñas reales', 'Estadísticas live'],
    ),
    OnboardingItem(
      title: 'Tu experiencia comienza hoy',
      description:
          'Únete a HookaHub y lleva tus sesiones al siguiente nivel. Personaliza tus preferencias y guarda tus mezclas.',
      icon: Icons.rocket_launch_rounded,
      badgeText: 'TODO LISTO',
      highlights: [
        '100% Gratuito',
        'Sincronizado en la nube',
        'Comunidad activa',
      ],
    ),
  ];

  OnboardingProvider() {
    _checkStatus();
  }

  /// Verifica si el usuario ya vio el onboarding con anterioridad
  Future<void> _checkStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasCompleted = prefs.getBool(_seenKey) ?? false;
    } catch (e) {
      AppLogger.warning('No se pudo leer el estado del onboarding: $e');
      _hasCompleted = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza el índice activo al deslizar
  void setCurrentIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  /// Marca el onboarding como completado y persiste la bandera
  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
      _hasCompleted = true;
      notifyListeners();
    } catch (e, stack) {
      AppLogger.error(
        'Error al guardar estado de onboarding',
        error: e,
        stackTrace: stack,
      );
    }
  }
}
