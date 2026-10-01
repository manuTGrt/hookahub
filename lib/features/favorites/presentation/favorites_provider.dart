import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/mix.dart';
import '../../../core/providers/database_health_provider.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/favorites_repository.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class FavoritesState {
  const FavoritesState();
}

class FavoritesInitial extends FavoritesState {
  const FavoritesInitial();
}

class FavoritesLoading extends FavoritesState {
  const FavoritesLoading();
}

class FavoritesLoaded extends FavoritesState {
  const FavoritesLoaded({
    this.favorites = const [],
    this.top5Ids = const [],
  });

  final List<Mix> favorites;
  final List<String> top5Ids;

  List<Mix> get top5 {
    final map = {for (final m in favorites) m.id: m};
    return top5Ids.map((id) => map[id]).whereType<Mix>().toList();
  }

  FavoritesLoaded copyWith({
    List<Mix>? favorites,
    List<String>? top5Ids,
  }) {
    return FavoritesLoaded(
      favorites: favorites ?? this.favorites,
      top5Ids: top5Ids ?? this.top5Ids,
    );
  }
}

class FavoritesError extends FavoritesState {
  const FavoritesError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider(this._repo, {AuthProvider? auth}) : _auth = auth {
    _auth?.addSignOutListener(_onSignOut);
    _auth?.addSignInListener(_onSignIn);
  }

  final FavoritesRepository _repo;
  final AuthProvider? _auth;

  FavoritesState _state = const FavoritesInitial();
  FavoritesState get state => _state;

  String? get _currentUserId => _auth?.user?.id;

  // Getters derivados para compatibilidad y consumo simplificado
  bool get isLoading => _state is FavoritesLoading;
  bool get isLoaded => _state is FavoritesLoaded;
  String? get error => switch (_state) {
    FavoritesError(:final message) => message,
    _ => null,
  };

  List<Mix> get favorites => switch (_state) {
    FavoritesLoaded(:final favorites) => List.unmodifiable(favorites),
    _ => const [],
  };

  List<Mix> get top5 => switch (_state) {
    FavoritesLoaded(:final top5) => top5,
    _ => const [],
  };

  void _onSignOut() {
    _state = const FavoritesInitial();
    notifyListeners();
  }

  void _onSignIn() {
    unawaited(load());
  }

  /// Limpia manualmente el estado en memoria
  void clear() => _onSignOut();

  Future<void> load({bool force = false}) async {
    final userId = _currentUserId;
    if (_state is FavoritesLoading && !force) return;
    _state = const FavoritesLoading();
    notifyListeners();

    try {
      final favs = await _repo.loadFavorites(userId: userId);
      final rawTop5 = await _repo.loadTop5Ids(userId: userId);
      final favIds = favs.map((e) => e.id).toSet();
      final validTop5 = rawTop5.where(favIds.contains).toList();

      _state = FavoritesLoaded(
        favorites: favs,
        top5Ids: validTop5,
      );
      DatabaseHealthProvider.reportSuccess();
    } catch (e, stack) {
      _state = FavoritesError(AppErrorMapper.toSpanish(e));
      AppLogger.error('Error al cargar favoritos', error: e, stackTrace: stack);
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      notifyListeners();
    }
  }

  Future<void> addFavorite(Mix mix) async {
    final current = _state is FavoritesLoaded
        ? (_state as FavoritesLoaded)
        : const FavoritesLoaded();
    if (current.favorites.any((m) => m.id == mix.id)) return;

    final backup = current;
    _state = current.copyWith(
      favorites: [...current.favorites, mix],
    );
    notifyListeners();

    try {
      await _repo.addFavorite(mix, userId: _currentUserId);
    } catch (e, stack) {
      _state = backup;
      notifyListeners();
      AppLogger.error('Error al añadir favorito', error: e, stackTrace: stack);
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  Future<void> removeFavorite(String mixId) async {
    if (_state is! FavoritesLoaded) return;
    final current = _state as FavoritesLoaded;
    final backup = current;

    final updatedFavs = current.favorites.where((m) => m.id != mixId).toList();
    final hadTop5 = current.top5Ids.contains(mixId);
    final updatedTop5 = current.top5Ids.where((id) => id != mixId).toList();

    _state = current.copyWith(
      favorites: updatedFavs,
      top5Ids: updatedTop5,
    );
    notifyListeners();

    try {
      await _repo.removeFavorite(mixId, userId: _currentUserId);
      if (hadTop5) {
        await _repo.saveTop5Ids(updatedTop5, userId: _currentUserId);
      }
    } catch (e, stack) {
      _state = backup;
      notifyListeners();
      AppLogger.error('Error al eliminar favorito', error: e, stackTrace: stack);
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  bool isTop5(String mixId) {
    if (_state is FavoritesLoaded) {
      return (_state as FavoritesLoaded).top5Ids.contains(mixId);
    }
    return false;
  }

  Future<void> toggleTop5(String mixId) async {
    if (_state is! FavoritesLoaded) return;
    final current = _state as FavoritesLoaded;

    final isFavorite = current.favorites.any((m) => m.id == mixId);
    if (!isFavorite) return;

    final backup = current;
    List<String> newTop5;
    if (current.top5Ids.contains(mixId)) {
      newTop5 = current.top5Ids.where((id) => id != mixId).toList();
    } else {
      if (current.top5Ids.length >= 5) {
        newTop5 = [...current.top5Ids.take(4), mixId];
      } else {
        newTop5 = [...current.top5Ids, mixId];
      }
    }

    _state = current.copyWith(top5Ids: newTop5);
    notifyListeners();

    try {
      await _repo.saveTop5Ids(newTop5, userId: _currentUserId);
    } catch (e, stack) {
      _state = backup;
      notifyListeners();
      AppLogger.error('Error al actualizar Top 5', error: e, stackTrace: stack);
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  Future<void> reorderTop5(int oldIndex, int newIndex) async {
    if (_state is! FavoritesLoaded) return;
    final current = _state as FavoritesLoaded;

    if (oldIndex < 0 || oldIndex >= current.top5Ids.length) return;
    if (newIndex < 0 || newIndex >= current.top5Ids.length) return;

    final backup = current;
    final ids = [...current.top5Ids];
    final String item = ids.removeAt(oldIndex);
    ids.insert(newIndex, item);

    _state = current.copyWith(top5Ids: ids);
    notifyListeners();

    try {
      await _repo.saveTop5Ids(ids, userId: _currentUserId);
    } catch (e, stack) {
      _state = backup;
      notifyListeners();
      AppLogger.error('Error al reordenar Top 5', error: e, stackTrace: stack);
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  Future<void> updateFavorite(Mix updatedMix) async {
    if (_state is! FavoritesLoaded) return;
    final current = _state as FavoritesLoaded;

    final index = current.favorites.indexWhere((m) => m.id == updatedMix.id);
    if (index == -1) return;

    final backup = current;
    final updatedList = [
      ...current.favorites.take(index),
      updatedMix,
      ...current.favorites.skip(index + 1),
    ];

    _state = current.copyWith(favorites: updatedList);
    notifyListeners();

    try {
      await _repo.saveFavorites(updatedList, userId: _currentUserId);
    } catch (e, stack) {
      _state = backup;
      notifyListeners();
      AppLogger.error('Error al actualizar favorito', error: e, stackTrace: stack);
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  @override
  void dispose() {
    _auth?.removeSignOutListener(_onSignOut);
    _auth?.removeSignInListener(_onSignIn);
    super.dispose();
  }
}
