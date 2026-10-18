import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants.dart';
import '../../domain/models/search_suggestion.dart';
import '../providers/search_suggestions_provider.dart';
import '../providers/search_suggestions_state.dart';
import 'recent_searches_section.dart';
import 'suggestion_tile.dart';

class SearchSuggestionsOverlay extends StatelessWidget {
  const SearchSuggestionsOverlay({
    super.key,
    required this.onTermSelected,
    required this.onSuggestionSelected,
    required this.onFillQuery,
  });

  final ValueChanged<String> onTermSelected;
  final ValueChanged<SearchSuggestion> onSuggestionSelected;
  final ValueChanged<String> onFillQuery;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = context.watch<SearchSuggestionsProvider>().state;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            // 1. Historial reciente (visible si no hay query o en estado inicial)
            if (state.recentSearches.isNotEmpty &&
                (state is SearchSuggestionsInitial ||
                    (state is SearchSuggestionsLoading &&
                        state.query.isEmpty))) ...[
              SliverToBoxAdapter(
                child: RecentSearchesSection(
                  searches: state.recentSearches,
                  onSelect: onTermSelected,
                  onRemove: (term) => context
                      .read<SearchSuggestionsProvider>()
                      .removeSearch(term),
                  onClearAll: () =>
                      context.read<SearchSuggestionsProvider>().clearHistory(),
                ),
              ),
            ],

            // 2. Indicador sutil de carga durante debouncing o petición remota
            if (state is SearchSuggestionsLoading && state.query.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: turquoiseDark,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            ],

            // 3. Sugerencias cargadas
            if (state is SearchSuggestionsLoaded) ...[
              if (state.hasNoMatches)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyMatchesState(context, state.query, isDark),
                )
              else ...[
                if (state.tobaccoSuggestions.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(context, 'TABACOS', isDark),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = state.tobaccoSuggestions[index];
                      return SuggestionTile(
                        suggestion: item,
                        query: state.query,
                        onTap: () => onSuggestionSelected(item),
                        onFillQuery: () => onFillQuery(item.title),
                      );
                    }, childCount: state.tobaccoSuggestions.length),
                  ),
                ],
                if (state.mixSuggestions.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(
                      context,
                      'MEZCLAS DE LA COMUNIDAD',
                      isDark,
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = state.mixSuggestions[index];
                      return SuggestionTile(
                        suggestion: item,
                        query: state.query,
                        onTap: () => onSuggestionSelected(item),
                        onFillQuery: () => onFillQuery(item.title),
                      );
                    }, childCount: state.mixSuggestions.length),
                  ),
                ],
              ],
            ],

            // 4. Historial vacío en estado inicial
            if (state is SearchSuggestionsInitial &&
                state.recentSearches.isEmpty) ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyHistoryPlaceholder(context, isDark),
              ),
            ],

            // 5. Estado de error
            if (state is SearchSuggestionsError) ...[
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildErrorPlaceholder(context, state.message, isDark),
              ),
            ],

            // Espaciado final para asegurar navegación sin obstrucción del teclado
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isDark ? darkNavy : navy,
        ),
      ),
    );
  }

  Widget _buildEmptyMatchesState(
    BuildContext context,
    String query,
    bool isDark,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: isDark ? darkNavy.withValues(alpha: 0.4) : Colors.black26,
            ),
            const SizedBox(height: 14),
            Text(
              'Sin sugerencias para "$query"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Presiona "Buscar" para rastrear en descripciones e ingredientes de todo el catálogo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? darkNavy.withValues(alpha: 0.6)
                    : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistoryPlaceholder(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 48,
              color: isDark ? darkNavy.withValues(alpha: 0.3) : Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              'Busca tabacos, marcas o mezclas',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tus búsquedas recientes se guardarán aquí automáticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? darkNavy.withValues(alpha: 0.5) : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder(
    BuildContext context,
    String message,
    bool isDark,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: isDark ? darkNavy.withValues(alpha: 0.4) : Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
