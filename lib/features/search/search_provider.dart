import 'package:hookahub/core/utils/app_logger.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../core/models/tobacco.dart';
import '../../core/models/mix.dart';
import '../../core/providers/database_health_provider.dart';
import '../catalog/data/tobacco_repository.dart';
import '../community/data/community_repository.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class SearchState {
  const SearchState();
}

/// Estado inicial: sin búsqueda activa.
class SearchInitial extends SearchState {
  const SearchInitial();
}

/// Búsqueda en progreso.
class SearchLoading extends SearchState {
  const SearchLoading(this.query);
  final String query;
}

/// Búsqueda completada con éxito.
class SearchSuccess extends SearchState {
  const SearchSuccess({
    required this.query,
    required this.tobaccos,
    required this.mixes,
  });

  final String query;
  final List<Tobacco> tobaccos;
  final List<Mix> mixes;

  int get totalResults => tobaccos.length + mixes.length;
  bool get isEmpty => totalResults == 0;
}

/// Error ocurrido durante la búsqueda.
class SearchError extends SearchState {
  const SearchError({
    required this.query,
    required this.message,
  });

  final String query;
  final String message;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Provider para gestionar búsquedas globales en tabacos y mezclas.
class SearchProvider extends ChangeNotifier {
  SearchProvider({
    required TobaccoRepository tobaccoRepository,
    required CommunityRepository communityRepository,
  }) : _tobaccoRepository = tobaccoRepository,
       _communityRepository = communityRepository {
    _reconnectedSub = DatabaseHealthProvider.instance.onReconnected.listen((_) {
      if (lastQuery.isNotEmpty && !isSearching) {
        unawaited(search(lastQuery));
      }
    });
  }

  final TobaccoRepository _tobaccoRepository;
  final CommunityRepository _communityRepository;
  StreamSubscription<void>? _reconnectedSub;

  SearchState _state = const SearchInitial();

  SearchState get state => _state;
  List<Tobacco> get tobaccoResults =>
      _state is SearchSuccess ? (_state as SearchSuccess).tobaccos : const [];
  List<Mix> get mixResults =>
      _state is SearchSuccess ? (_state as SearchSuccess).mixes : const [];
  bool get isSearching => _state is SearchLoading;
  String get lastQuery => switch (_state) {
        SearchLoading(:final query) => query,
        SearchSuccess(:final query) => query,
        SearchError(:final query) => query,
        SearchInitial() => '',
      };
  int get totalResults =>
      _state is SearchSuccess ? (_state as SearchSuccess).totalResults : 0;
  String? get error =>
      _state is SearchError ? (_state as SearchError).message : null;

  /// Busca en ambos catálogos (tabacos y mezclas) por el término especificado.
  /// Busca en nombre, descripción y marca (para tabacos).
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _state = const SearchInitial();
      notifyListeners();
      return;
    }

    _state = SearchLoading(query);
    notifyListeners();

    try {
      // Búsqueda paralela en ambos repositorios
      final results = await Future.wait([
        _searchTobaccos(query),
        _searchMixes(query),
      ]);

      _state = SearchSuccess(
        query: query,
        tobaccos: results[0] as List<Tobacco>,
        mixes: results[1] as List<Mix>,
      );
    } catch (e) {
      final errorMessage = 'Error en búsqueda: $e';
      AppLogger.error(errorMessage);
      _state = SearchError(query: query, message: errorMessage);
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      notifyListeners();
    }
  }

  /// Busca tabacos por nombre, marca o descripción.
  Future<List<Tobacco>> _searchTobaccos(String query) async {
    return await _tobaccoRepository.fetchTobaccos(
      offset: 0,
      limit: 50, // Límite razonable para resultados de búsqueda
      query: query,
    );
  }

  /// Busca mezclas por nombre o ingredientes.
  /// Nota: Como el repositorio actual no tiene búsqueda, obtenemos todas
  /// y filtramos en cliente. Ideal: agregar búsqueda en el repositorio.
  Future<List<Mix>> _searchMixes(String query) async {
    // Obtener un lote grande de mezclas recientes
    final allMixes = await _communityRepository.fetchMixes(
      orderBy: 'recent',
      limit: 100, // Ajustar según necesidad
      offset: 0,
    );

    // Filtrar localmente por nombre o ingredientes
    final lowerQuery = query.toLowerCase().trim();
    return allMixes.where((mix) {
      // Buscar en el nombre
      if (mix.name.toLowerCase().contains(lowerQuery)) {
        return true;
      }
      // Buscar en ingredientes
      if (mix.ingredients.any(
        (ing) => ing.toLowerCase().contains(lowerQuery),
      )) {
        return true;
      }
      // Buscar en autor
      if (mix.author.toLowerCase().contains(lowerQuery)) {
        return true;
      }
      return false;
    }).toList();
  }

  /// Limpia los resultados de búsqueda.
  void clear() {
    _state = const SearchInitial();
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectedSub?.cancel();
    super.dispose();
  }
}
