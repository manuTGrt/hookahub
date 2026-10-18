import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/app_logger.dart';

abstract class SearchHistoryLocalDataSource {
  Future<List<String>> getRecentSearches();
  Future<void> saveSearch(String query);
  Future<void> removeSearch(String query);
  Future<void> clearAll();
}

class SearchHistoryLocalDataSourceImpl implements SearchHistoryLocalDataSource {
  static const String _historyKey = 'hookahub_recent_searches_v1';
  static const int _maxHistoryItems = 8;

  @override
  Future<List<String>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_historyKey) ?? const <String>[];
    } catch (e, stack) {
      AppLogger.warning(
        'Error al leer el historial de búsquedas de SharedPreferences',
        error: e,
        stackTrace: stack,
      );
      return const <String>[];
    }
  }

  @override
  Future<void> saveSearch(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = prefs.getStringList(_historyKey) ?? <String>[];

      // Eliminar ocurrencia previa sin distinción de mayúsculas/minúsculas
      final updatedList = currentList.where(
        (item) => item.toLowerCase() != cleanQuery.toLowerCase(),
      ).toList();

      // Insertar al inicio (LIFO)
      updatedList.insert(0, cleanQuery);

      // Limitar a los N más recientes
      if (updatedList.length > _maxHistoryItems) {
        updatedList.removeRange(_maxHistoryItems, updatedList.length);
      }

      await prefs.setStringList(_historyKey, updatedList);
    } catch (e, stack) {
      AppLogger.warning(
        'Error al guardar término de búsqueda en SharedPreferences',
        error: e,
        stackTrace: stack,
      );
    }
  }

  @override
  Future<void> removeSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = prefs.getStringList(_historyKey) ?? <String>[];
      currentList.removeWhere(
        (item) => item.toLowerCase() == query.trim().toLowerCase(),
      );
      await prefs.setStringList(_historyKey, currentList);
    } catch (e, stack) {
      AppLogger.warning(
        'Error al eliminar término de búsqueda de SharedPreferences',
        error: e,
        stackTrace: stack,
      );
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e, stack) {
      AppLogger.warning(
        'Error al vaciar historial de búsquedas de SharedPreferences',
        error: e,
        stackTrace: stack,
      );
    }
  }
}
