import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hookahub/features/search/data/datasources/search_history_local_data_source.dart';
import 'package:hookahub/features/search/data/repositories/search_suggestions_repository.dart';
import 'package:hookahub/features/search/domain/models/search_suggestion.dart';
import 'package:hookahub/features/search/presentation/providers/search_suggestions_provider.dart';
import 'package:hookahub/features/search/presentation/providers/search_suggestions_state.dart';

class FakeSearchSuggestionsRepository implements SearchSuggestionsRepository {
  bool shouldThrow = false;
  final List<SearchSuggestion> suggestions = const [
    SearchSuggestion(
      id: 't-1',
      title: 'Love 66',
      subtitle: 'Adalya',
      type: SearchSuggestionType.tobacco,
      rating: 4.8,
    ),
    SearchSuggestion(
      id: 'm-1',
      title: 'Brisa de Verano',
      subtitle: 'Por Alex',
      type: SearchSuggestionType.mix,
      rating: 4.5,
    ),
  ];

  @override
  Future<List<SearchSuggestion>> fetchSuggestions(String query) async {
    if (shouldThrow) {
      throw Exception('Fallo simulado en sugerencias');
    }
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return const [];
    return suggestions
        .where(
          (s) =>
              s.title.toLowerCase().contains(clean) ||
              s.subtitle.toLowerCase().contains(clean),
        )
        .toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchHistoryLocalDataSource', () {
    late SearchHistoryLocalDataSource dataSource;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dataSource = SearchHistoryLocalDataSourceImpl();
    });

    test('getRecentSearches inicia vacío', () async {
      final list = await dataSource.getRecentSearches();
      expect(list, isEmpty);
    });

    test('saveSearch añade al inicio y elimina duplicados insensibles a mayúsculas', () async {
      await dataSource.saveSearch('Menta');
      await dataSource.saveSearch('Love 66');
      await dataSource.saveSearch('menta'); // Debe mover "menta" al inicio sin duplicar

      final list = await dataSource.getRecentSearches();
      expect(list.length, equals(2));
      expect(list.first, equals('menta'));
      expect(list[1], equals('Love 66'));
    });

    test('saveSearch limita el historial a un máximo de 8 elementos', () async {
      for (int i = 1; i <= 10; i++) {
        await dataSource.saveSearch('Término $i');
      }

      final list = await dataSource.getRecentSearches();
      expect(list.length, equals(8));
      expect(list.first, equals('Término 10'));
      expect(list.contains('Término 1'), isFalse);
      expect(list.contains('Término 2'), isFalse);
    });

    test('removeSearch elimina solo el término solicitado', () async {
      await dataSource.saveSearch('Término A');
      await dataSource.saveSearch('Término B');

      await dataSource.removeSearch('término a'); // Case-insensitive
      final list = await dataSource.getRecentSearches();

      expect(list.length, equals(1));
      expect(list.first, equals('Término B'));
    });

    test('clearAll vacía completamente el historial', () async {
      await dataSource.saveSearch('Uno');
      await dataSource.saveSearch('Dos');

      await dataSource.clearAll();
      final list = await dataSource.getRecentSearches();
      expect(list, isEmpty);
    });
  });

  group('SearchSuggestionsProvider', () {
    late SearchHistoryLocalDataSource historyDataSource;
    late FakeSearchSuggestionsRepository fakeRepo;
    late SearchSuggestionsProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'hookahub_recent_searches_v1': ['Love 66', 'Menta'],
      });
      historyDataSource = SearchHistoryLocalDataSourceImpl();
      fakeRepo = FakeSearchSuggestionsRepository();
      provider = SearchSuggestionsProvider(
        historyDataSource: historyDataSource,
        suggestionsRepository: fakeRepo,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('Inicia con SearchSuggestionsInitial conteniendo el historial previo', () async {
      await provider.loadRecentSearches();
      expect(provider.state, isA<SearchSuggestionsInitial>());
      expect(provider.state.recentSearches, equals(['Love 66', 'Menta']));
    });

    test('onQueryChanged con texto vacío regresa de inmediato a SearchSuggestionsInitial', () async {
      await provider.loadRecentSearches();
      provider.onQueryChanged('   ');

      expect(provider.state, isA<SearchSuggestionsInitial>());
      expect(provider.state.recentSearches.length, equals(2));
    });

    test('onQueryChanged pasa a SearchSuggestionsLoading y tras debounce a SearchSuggestionsLoaded', () async {
      await provider.loadRecentSearches();
      provider.onQueryChanged('Love');

      // Estado inmediato: Loading
      expect(provider.state, isA<SearchSuggestionsLoading>());
      expect((provider.state as SearchSuggestionsLoading).query, equals('Love'));

      // Esperar que transcurra el debounce (280ms)
      await Future.delayed(const Duration(milliseconds: 320));

      expect(provider.state, isA<SearchSuggestionsLoaded>());
      final loadedState = provider.state as SearchSuggestionsLoaded;
      expect(loadedState.suggestions.length, equals(1));
      expect(loadedState.tobaccoSuggestions.length, equals(1));
      expect(loadedState.tobaccoSuggestions.first.title, equals('Love 66'));
      expect(loadedState.mixSuggestions, isEmpty);
    });

    test('onQueryChanged maneja errores transicionando a SearchSuggestionsError sin perder historial', () async {
      fakeRepo.shouldThrow = true;
      await provider.loadRecentSearches();
      provider.onQueryChanged('Fallo');

      await Future.delayed(const Duration(milliseconds: 320));

      expect(provider.state, isA<SearchSuggestionsError>());
      expect(provider.state.recentSearches, equals(['Love 66', 'Menta']));
    });

    test('saveSearch, removeSearch y clearHistory actualizan el historial reactivamente', () async {
      await provider.loadRecentSearches();

      await provider.saveSearch('Uva');
      expect(provider.recentSearches.first, equals('Uva'));
      expect(provider.state.recentSearches.contains('Uva'), isTrue);

      await provider.removeSearch('Love 66');
      expect(provider.recentSearches.contains('Love 66'), isFalse);
      expect(provider.state.recentSearches.contains('Love 66'), isFalse);

      await provider.clearHistory();
      expect(provider.recentSearches, isEmpty);
      expect(provider.state.recentSearches, isEmpty);
    });
  });
}
