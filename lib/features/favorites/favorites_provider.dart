import 'package:flutter/foundation.dart';

import '../../core/models/mix.dart';
import 'favorites_repository.dart';

class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider(this._repo);

  final FavoritesRepository _repo;

  List<Mix> _favorites = [];
  List<String> _top5Ids = [];
  bool _loaded = false;
  bool get isLoaded => _loaded;

  List<Mix> get favorites => List.unmodifiable(_favorites);
  List<Mix> get top5 {
    final map = {for (final m in _favorites) m.id: m};
    return _top5Ids.map((id) => map[id]).whereType<Mix>().toList();
  }

  Future<void> load() async {
    _favorites = await _repo.loadFavorites();
    _top5Ids = await _repo.loadTop5Ids();
    // Limpiar ids no existentes
    final favIds = _favorites.map((e) => e.id).toSet();
    _top5Ids = _top5Ids.where(favIds.contains).toList();
    _loaded = true;
    notifyListeners();
  }

  Future<void> addFavorite(Mix mix) async {
    if (_favorites.any((m) => m.id == mix.id)) return;
    _favorites = [..._favorites, mix];
    await _repo.saveFavorites(_favorites);
    notifyListeners();
  }

  Future<void> removeFavorite(String mixId) async {
    _favorites = _favorites.where((m) => m.id != mixId).toList();
    _top5Ids = _top5Ids.where((id) => id != mixId).toList();
    await _repo.saveFavorites(_favorites);
    await _repo.saveTop5Ids(_top5Ids);
    notifyListeners();
  }

  bool isTop5(String mixId) => _top5Ids.contains(mixId);

  Future<void> toggleTop5(String mixId) async {
    // Solo se puede top5 si está en favoritos
    final isFavorite = _favorites.any((m) => m.id == mixId);
    if (!isFavorite) return;
    if (_top5Ids.contains(mixId)) {
      _top5Ids = _top5Ids.where((id) => id != mixId).toList();
    } else {
      if (_top5Ids.length >= 5) {
        // Reemplazar el último por el nuevo (o ignorar). Aquí desplazamos y añadimos.
        _top5Ids = [..._top5Ids.take(4), mixId];
      } else {
        _top5Ids = [..._top5Ids, mixId];
      }
    }
    await _repo.saveTop5Ids(_top5Ids);
    notifyListeners();
  }

  Future<void> reorderTop5(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _top5Ids.length) return;
    if (newIndex < 0 || newIndex >= _top5Ids.length) return;
    final ids = [..._top5Ids];
    final String item = ids.removeAt(oldIndex);
    ids.insert(newIndex, item);
    _top5Ids = ids;
    await _repo.saveTop5Ids(_top5Ids);
    notifyListeners();
  }

  /// Actualiza una mezcla existente en la lista de favoritos
  Future<void> updateFavorite(Mix updatedMix) async {
    final index = _favorites.indexWhere((m) => m.id == updatedMix.id);
    if (index == -1) return; // No está en favoritos

    _favorites = [
      ..._favorites.take(index),
      updatedMix,
      ..._favorites.skip(index + 1),
    ];
    await _repo.saveFavorites(_favorites);
    notifyListeners();
  }
}
