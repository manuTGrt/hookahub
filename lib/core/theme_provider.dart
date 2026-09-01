import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hookahub/core/utils/app_logger.dart';

/// Provider para manejar el estado y la preferencia del tema de la aplicación.
///
/// Gestiona la selección entre Modo Claro, Modo Oscuro y Automático (Sistema),
/// persistiendo la selección del usuario mediante [SharedPreferences].
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  /// Getter para obtener el [ThemeMode] actual
  ThemeMode get themeMode => _themeMode;

  /// Getter auxiliar para consultar si el modo configurado es estrictamente oscuro.
  /// Para evaluar el brillo efectivo en pantalla considerando el modo sistema,
  /// se recomienda usar `Theme.of(context).brightness == Brightness.dark`.
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Constructor que carga la preferencia persistida al inicializarse
  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  /// Establece un nuevo [ThemeMode] y guarda la preferencia en disco
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _saveThemeToPrefs();
  }

  /// Método de conveniencia para alternar entre claro y oscuro directamente
  Future<void> toggleTheme(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  /// Carga la preferencia guardada desde [SharedPreferences]
  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.get(_themeKey);

      if (savedTheme is String) {
        switch (savedTheme) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'system':
          default:
            _themeMode = ThemeMode.system;
            break;
        }
      } else if (savedTheme is bool) {
        // Retrocompatibilidad con versiones previas que guardaban bool
        _themeMode = savedTheme ? ThemeMode.dark : ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (e, stack) {
      AppLogger.error(
        'Error al cargar tema desde preferencias',
        error: e,
        stackTrace: stack,
      );
      _themeMode = ThemeMode.system;
    }
  }

  /// Guarda el tema actual en [SharedPreferences]
  Future<void> _saveThemeToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, _themeMode.name);
    } catch (e, stack) {
      AppLogger.error(
        'Error al guardar preferencia de tema',
        error: e,
        stackTrace: stack,
      );
    }
  }
}

