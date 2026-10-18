import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/datasources/search_history_local_data_source.dart';
import '../../data/repositories/search_suggestions_repository.dart';
import 'search_suggestions_state.dart';

class SearchSuggestionsProvider extends ChangeNotifier {
  SearchSuggestionsProvider({
    required SearchHistoryLocalDataSource historyDataSource,
    required SearchSuggestionsRepository suggestionsRepository,
  })  : _historyDataSource = historyDataSource,
        _suggestionsRepository = suggestionsRepository {
    unawaited(loadRecentSearches());
  }

  final SearchHistoryLocalDataSource _historyDataSource;
  final SearchSuggestionsRepository _suggestionsRepository;

  Timer? _debounceTimer;
  int _latestRequestId = 0;
  List<String> _cachedHistory = const [];

  SearchSuggestionsState _state = const SearchSuggestionsInitial(
    recentSearches: [],
  );

  SearchSuggestionsState get state => _state;
  List<String> get recentSearches => _cachedHistory;

  /// Carga inicial del historial desde almacenamiento local
  Future<void> loadRecentSearches() async {
    _cachedHistory = await _historyDataSource.getRecentSearches();
    if (_state is SearchSuggestionsInitial) {
      _state = SearchSuggestionsInitial(recentSearches: _cachedHistory);
      notifyListeners();
    }
  }

  /// Maneja los cambios de texto con debouncing (280ms) y prevención de race conditions
  void onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      _latestRequestId++;
      _state = SearchSuggestionsInitial(recentSearches: _cachedHistory);
      notifyListeners();
      return;
    }

    // Activar estado de carga manteniendo el historial accesible
    _state = SearchSuggestionsLoading(
      recentSearches: _cachedHistory,
      query: trimmed,
    );
    notifyListeners();

    _debounceTimer = Timer(const Duration(milliseconds: 280), () async {
      final currentRequestId = ++_latestRequestId;
      try {
        final results = await _suggestionsRepository.fetchSuggestions(trimmed);

        // Validar que la respuesta corresponda a la última petición emitida
        if (currentRequestId != _latestRequestId) return;

        _state = SearchSuggestionsLoaded(
          recentSearches: _cachedHistory,
          query: trimmed,
          suggestions: results,
        );
      } catch (e, stack) {
        if (currentRequestId != _latestRequestId) return;
        AppLogger.warning(
          'Error obteniendo sugerencias de búsqueda predictiva',
          error: e,
          stackTrace: stack,
        );
        _state = SearchSuggestionsError(
          recentSearches: _cachedHistory,
          query: trimmed,
          message: 'No pudimos cargar sugerencias en vivo.',
        );
      } finally {
        if (currentRequestId == _latestRequestId) {
          notifyListeners();
        }
      }
    });
  }

  /// Persiste un término en el historial local
  Future<void> saveSearch(String query) async {
    await _historyDataSource.saveSearch(query);
    _cachedHistory = await _historyDataSource.getRecentSearches();
    _updateHistoryInCurrentState();
  }

  /// Elimina un término específico del historial
  Future<void> removeSearch(String query) async {
    await _historyDataSource.removeSearch(query);
    _cachedHistory = await _historyDataSource.getRecentSearches();
    _updateHistoryInCurrentState();
  }

  /// Limpia todo el historial local
  Future<void> clearHistory() async {
    await _historyDataSource.clearAll();
    _cachedHistory = const [];
    _updateHistoryInCurrentState();
  }

  /// Resetea el estado al inicial con el historial cargado
  void reset() {
    _debounceTimer?.cancel();
    _latestRequestId++;
    _state = SearchSuggestionsInitial(recentSearches: _cachedHistory);
    notifyListeners();
  }

  void _updateHistoryInCurrentState() {
    _state = switch (_state) {
      SearchSuggestionsInitial() =>
        SearchSuggestionsInitial(recentSearches: _cachedHistory),
      SearchSuggestionsLoading(:final query) =>
        SearchSuggestionsLoading(recentSearches: _cachedHistory, query: query),
      SearchSuggestionsLoaded(:final query, :final suggestions) =>
        SearchSuggestionsLoaded(
          recentSearches: _cachedHistory,
          query: query,
          suggestions: suggestions,
        ),
      SearchSuggestionsError(:final query, :final message) =>
        SearchSuggestionsError(
          recentSearches: _cachedHistory,
          query: query,
          message: message,
        ),
    };
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
