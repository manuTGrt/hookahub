import 'package:flutter/foundation.dart';
import '../../../core/models/mix.dart';
import '../../../core/providers/database_health_provider.dart';
import '../../auth/auth_provider.dart';
import '../domain/user_mixes_repository.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class UserMixesState {
  const UserMixesState();
}

/// Estado inicial previo a la carga o tras cerrar sesión.
class UserMixesInitial extends UserMixesState {
  const UserMixesInitial();
}

/// Primera carga en progreso.
class UserMixesLoading extends UserMixesState {
  const UserMixesLoading();
}

/// Mezclas cargadas con éxito.
class UserMixesLoaded extends UserMixesState {
  const UserMixesLoaded({
    required this.mixes,
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  final List<Mix> mixes;
  final bool isLoadingMore;
  final bool hasMore;

  UserMixesLoaded copyWith({
    List<Mix>? mixes,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return UserMixesLoaded(
      mixes: mixes ?? this.mixes,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Ocurrió un error al cargar o interactuar con las mezclas.
class UserMixesError extends UserMixesState {
  const UserMixesError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class UserMixesProvider extends ChangeNotifier {
  UserMixesProvider(this._repo, {AuthProvider? auth}) : _auth = auth {
    _auth?.addSignOutListener(clear);
  }

  final UserMixesRepository _repo;
  final AuthProvider? _auth;

  final int _pageSize = 20;
  int _offset = 0;

  // Estado sellado (única fuente de verdad)
  UserMixesState _state = const UserMixesInitial();

  UserMixesState get state => _state;

  /// Limpia los datos locales del usuario al cerrar sesión
  void clear() {
    _offset = 0;
    _state = const UserMixesInitial();
    notifyListeners();
  }

  // Getters derivados para compatibilidad y consumo simplificado
  bool get isLoading => _state is UserMixesLoading;
  bool get isLoadingMore =>
      _state is UserMixesLoaded && (_state as UserMixesLoaded).isLoadingMore;
  bool get isLoaded => _state is UserMixesLoaded;
  String? get error =>
      _state is UserMixesError ? (_state as UserMixesError).message : null;
  bool get hasMore =>
      _state is UserMixesLoaded ? (_state as UserMixesLoaded).hasMore : true;
  List<Mix> get mixes =>
      _state is UserMixesLoaded ? (_state as UserMixesLoaded).mixes : const [];

  Future<void> load() async {
    if (_state is UserMixesLoading) return;
    _state = const UserMixesLoading();
    notifyListeners();

    try {
      _offset = 0;
      final result = await _repo.fetchMyMixes(
        limit: _pageSize,
        offset: _offset,
      );
      _offset = result.length;
      _state = UserMixesLoaded(
        mixes: result,
        hasMore: result.length >= _pageSize,
        isLoadingMore: false,
      );
    } catch (e) {
      _state = const UserMixesError('No se pudieron cargar tus mezclas');
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await load();
  }

  Future<void> loadMore() async {
    final currentState = _state;
    if (currentState is! UserMixesLoaded) return;
    if (currentState.isLoadingMore || !currentState.hasMore) return;

    _state = currentState.copyWith(isLoadingMore: true);
    notifyListeners();

    try {
      final result = await _repo.fetchMyMixes(
        limit: _pageSize,
        offset: _offset,
      );
      if (result.isNotEmpty) {
        final updatedMixes = List<Mix>.from(currentState.mixes)..addAll(result);
        _offset += result.length;
        _state = currentState.copyWith(
          mixes: updatedMixes,
          hasMore: result.length >= _pageSize,
          isLoadingMore: false,
        );
      } else {
        _state = currentState.copyWith(
          hasMore: false,
          isLoadingMore: false,
        );
      }
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      _state = currentState.copyWith(isLoadingMore: false);
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _auth?.removeSignOutListener(clear);
    super.dispose();
  }
}
