import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider para manejar el estado del tema de la aplicación
///
/// Este provider gestiona el cambio entre tema claro y oscuro,
/// persistiendo la preferencia del usuario usando SharedPreferences.
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;

  /// Getter para obtener el modo de tema actual
  ThemeMode get themeMode => _themeMode;

  /// Getter para verificar si está en modo oscuro
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Constructor que inicializa el tema desde las preferencias guardadas
  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  /// Cambia el tema y guarda la preferencia
  ///
  /// [isDark] - true para tema oscuro, false para tema claro
  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    await _saveThemeToPrefs();
  }

  /// Carga el tema guardado desde SharedPreferences
  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_themeKey) ?? false;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (e) {
      // En caso de error, usar tema claro por defecto
      debugPrint('Error al cargar tema: $e');
    }
  }

  /// Guarda el tema actual en SharedPreferences
  Future<void> _saveThemeToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, isDarkMode);
    } catch (e) {
      debugPrint('Error al guardar tema: $e');
    }
  }
}
