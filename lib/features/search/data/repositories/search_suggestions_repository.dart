import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants.dart';
import '../../../../core/data/supabase_service.dart';
import '../../../../core/models/mix.dart';
import '../../../../core/models/tobacco.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/models/search_suggestion.dart';

abstract class SearchSuggestionsRepository {
  Future<List<SearchSuggestion>> fetchSuggestions(String query);
}

class SearchSuggestionsRepositoryImpl implements SearchSuggestionsRepository {
  SearchSuggestionsRepositoryImpl(this._supabase);

  final SupabaseService _supabase;

  // Caché en memoria L1 (Query -> Lista de sugerencias)
  final Map<String, List<SearchSuggestion>> _memoryCache = {};
  static const int _maxCacheEntries = 40;

  @override
  Future<List<SearchSuggestion>> fetchSuggestions(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return const [];

    if (_memoryCache.containsKey(cleanQuery)) {
      return _memoryCache[cleanQuery]!;
    }

    try {
      // Consultas paralelas ligeras
      final results = await Future.wait([
        _fetchTobaccoSuggestions(cleanQuery),
        _fetchMixSuggestions(cleanQuery),
      ]);

      final combined = <SearchSuggestion>[
        ...results[0],
        ...results[1],
      ];

      // Gestión de tamaño de caché en memoria (LRU simple)
      if (_memoryCache.length >= _maxCacheEntries) {
        _memoryCache.remove(_memoryCache.keys.first);
      }
      _memoryCache[cleanQuery] = combined;

      return combined;
    } catch (e, stack) {
      AppLogger.warning(
        'Error obteniendo sugerencias predictivas',
        error: e,
        stackTrace: stack,
      );
      return const [];
    }
  }

  Future<List<SearchSuggestion>> _fetchTobaccoSuggestions(String query) async {
    try {
      final rows = await _supabase.client
          .from('tobaccos')
          .select('id, name, brand, description, image_url, rating, reviews')
          .or('name.ilike.%$query%,brand.ilike.%$query%')
          .order('reviews', ascending: false)
          .limit(4)
          .timeout(supabaseReadTimeout);

      return (rows as List).map<SearchSuggestion>((r) {
        final m = r as Map<String, dynamic>;
        final tobacco = Tobacco(
          id: m['id'] as String,
          name: m['name'] as String,
          brand: m['brand'] as String,
          description: m['description'] as String?,
          flavors: const <String>[],
          rating: (m['rating'] as num?)?.toDouble() ?? 0.0,
          reviews: (m['reviews'] as int?) ?? 0,
          imageUrl: m['image_url'] as String?,
        );

        return SearchSuggestion(
          id: tobacco.id,
          title: tobacco.name,
          subtitle: tobacco.brand,
          type: SearchSuggestionType.tobacco,
          rating: tobacco.rating,
          reviews: tobacco.reviews,
          imageUrl: tobacco.imageUrl,
          brand: tobacco.brand,
          tobacco: tobacco,
        );
      }).toList();
    } catch (e, stack) {
      AppLogger.warning(
        'Fallo en consulta predictiva de tabacos',
        error: e,
        stackTrace: stack,
      );
      return const [];
    }
  }

  Future<List<SearchSuggestion>> _fetchMixSuggestions(String query) async {
    try {
      final rows = await _supabase.client
          .from('mixes')
          .select('''
            id,
            name,
            rating,
            reviews,
            reviews_real:reviews(count),
            profiles!mixes_author_id_fkey(username),
            mix_components(tobacco_name, brand, percentage, color)
          ''')
          .ilike('name', '%$query%')
          .order('reviews', ascending: false)
          .limit(4)
          .timeout(supabaseReadTimeout);

      return (rows as List).map<SearchSuggestion>((r) {
        final m = r as Map<String, dynamic>;

        // Componentes e ingredientes
        final components = m['mix_components'] as List? ?? [];
        final ingredients = components
            .map((c) => c['tobacco_name'] as String)
            .toList();

        // Color
        Color mixColor = const Color(0xFF72C8C1);
        if (components.isNotEmpty && components[0]['color'] != null) {
          final colorStr = components[0]['color'] as String;
          if (colorStr.startsWith('#') && colorStr.length == 7) {
            mixColor = Color(
              int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
            );
          }
        }

        // Autor
        final profile = m['profiles'] as Map<String, dynamic>?;
        final authorName = profile != null
            ? (profile['username'] as String? ?? 'Comunidad')
            : 'Comunidad';

        final reviewsCount =
            (m['reviews_real'] as List?)?.firstOrNull?['count'] as int? ??
            (m['reviews'] as num?)?.toInt() ??
            0;

        final mix = Mix(
          id: m['id'] as String,
          name: m['name'] as String,
          author: authorName,
          rating: (m['rating'] as num?)?.toDouble() ?? 0.0,
          reviews: reviewsCount,
          ingredients: ingredients,
          color: mixColor,
        );

        return SearchSuggestion(
          id: mix.id,
          title: mix.name,
          subtitle: 'Por ${mix.author}',
          type: SearchSuggestionType.mix,
          rating: mix.rating,
          reviews: mix.reviews,
          author: mix.author,
          mix: mix,
        );
      }).toList();
    } catch (e, stack) {
      AppLogger.warning(
        'Fallo en consulta predictiva de mezclas',
        error: e,
        stackTrace: stack,
      );
      return const [];
    }
  }
}
