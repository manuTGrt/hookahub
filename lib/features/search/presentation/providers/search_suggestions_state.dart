import '../../domain/models/search_suggestion.dart';

/// Clase sellada para representar los estados estrictos de sugerencias y autocompletado
sealed class SearchSuggestionsState {
  const SearchSuggestionsState({required this.recentSearches});

  /// Lista de búsquedas recientes persistidas, siempre disponible para evitar saltos visuales
  final List<String> recentSearches;
}

/// Estado inicial: campo de búsqueda vacío o recién enfocado
class SearchSuggestionsInitial extends SearchSuggestionsState {
  const SearchSuggestionsInitial({required super.recentSearches});
}

/// Estado de carga mientras se ejecuta el debounce o la respuesta del servidor
class SearchSuggestionsLoading extends SearchSuggestionsState {
  const SearchSuggestionsLoading({
    required super.recentSearches,
    required this.query,
  });

  final String query;
}

/// Estado con sugerencias recuperadas del servidor o caché
class SearchSuggestionsLoaded extends SearchSuggestionsState {
  const SearchSuggestionsLoaded({
    required super.recentSearches,
    required this.query,
    required this.suggestions,
  });

  final String query;
  final List<SearchSuggestion> suggestions;

  List<SearchSuggestion> get tobaccoSuggestions =>
      suggestions.where((s) => s.type == SearchSuggestionType.tobacco).toList();

  List<SearchSuggestion> get mixSuggestions =>
      suggestions.where((s) => s.type == SearchSuggestionType.mix).toList();

  bool get hasNoMatches => suggestions.isEmpty;
}

/// Estado de fallo al obtener predicciones remotas (permite continuar usando el historial)
class SearchSuggestionsError extends SearchSuggestionsState {
  const SearchSuggestionsError({
    required super.recentSearches,
    required this.query,
    required this.message,
  });

  final String query;
  final String message;
}
