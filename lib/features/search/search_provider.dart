import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../core/models/tobacco.dart';
import '../../core/models/mix.dart';
import '../../core/providers/database_health_provider.dart';
import '../catalog/data/tobacco_repository.dart';
import '../community/data/community_repository.dart';

/// Provider para gestionar búsquedas globales en tabacos y mezclas.
class SearchProvider extends ChangeNotifier {
  SearchProvider({
    required TobaccoRepository tobaccoRepository,
    required CommunityRepository communityRepository,
  }) : _tobaccoRepository = tobaccoRepository,
       _communityRepository = communityRepository {
    _reconnectedSub = DatabaseHealthProvider.instance.onReconnected.listen((_) {
      if (_lastQuery.isNotEmpty && !_isSearching) {
        unawaited(search(_lastQuery));
      }
    });
  }

  final TobaccoRepository _tobaccoRepository;
  final CommunityRepository _communityRepository;
  StreamSubscription<void>? _reconnectedSub;

  List<Tobacco> _tobaccoResults = [];
  List<Mix> _mixResults = [];
  bool _isSearching = false;
  String _lastQuery = '';

  List<Tobacco> get tobaccoResults => List.unmodifiable(_tobaccoResults);
  List<Mix> get mixResults => List.unmodifiable(_mixResults);
  bool get isSearching => _isSearching;
  String get lastQuery => _lastQuery;
  int get totalResults => _tobaccoResults.length + _mixResults.length;

  /// Busca en ambos catálogos (tabacos y mezclas) por el término especificado.
  /// Busca en nombre, descripción y marca (para tabacos).
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _tobaccoResults = [];
      _mixResults = [];
      _lastQuery = '';
      notifyListeners();
      return;
    }

    _isSearching = true;
    _lastQuery = query;
    notifyListeners();

    try {
      // Búsqueda paralela en ambos repositorios
      final results = await Future.wait([
        _searchTobaccos(query),
        _searchMixes(query),
      ]);

      _tobaccoResults = results[0] as List<Tobacco>;
      _mixResults = results[1] as List<Mix>;
    } catch (e) {
      debugPrint('Error en búsqueda: $e');
      _tobaccoResults = [];
      _mixResults = [];
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Busca tabacos por nombre, marca o descripción.
  Future<List<Tobacco>> _searchTobaccos(String query) async {
    try {
      // Usar el método existente del repositorio que ya soporta búsqueda
      return await _tobaccoRepository.fetchTobaccos(
        offset: 0,
        limit: 50, // Límite razonable para resultados de búsqueda
        query: query,
      );
    } catch (e) {
      debugPrint('Error buscando tabacos: $e');
      DatabaseHealthProvider.reportFailure(e);
      return [];
    }
  }

  /// Busca mezclas por nombre o ingredientes.
  /// Nota: Como el repositorio actual no tiene búsqueda, obtenemos todas
  /// y filtramos en cliente. Ideal: agregar búsqueda en el repositorio.
  Future<List<Mix>> _searchMixes(String query) async {
    try {
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
    } catch (e) {
      debugPrint('Error buscando mezclas: $e');
      DatabaseHealthProvider.reportFailure(e);
      return [];
    }
  }

  /// Limpia los resultados de búsqueda.
  void clear() {
    _tobaccoResults = [];
    _mixResults = [];
    _lastQuery = '';
    _isSearching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectedSub?.cancel();
    super.dispose();
  }
}
