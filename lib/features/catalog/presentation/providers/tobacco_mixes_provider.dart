import 'package:hookahub/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/models/mix.dart';
import '../../../../core/providers/database_health_provider.dart';
import '../../../community/data/community_repository.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class TobaccoMixesState {
  const TobaccoMixesState();
}

/// Estado inicial previo a cargar las mezclas asociadas a un tabaco.
class TobaccoMixesInitial extends TobaccoMixesState {
  const TobaccoMixesInitial();
}

/// Carga inicial en progreso.
class TobaccoMixesLoading extends TobaccoMixesState {
  const TobaccoMixesLoading();
}

/// Mezclas cargadas con éxito (soporta paginación incremental).
class TobaccoMixesLoaded extends TobaccoMixesState {
  const TobaccoMixesLoaded({
    required this.mixes,
    this.isLoadingMore = false,
    this.hasMoreData = true,
  });

  final List<Mix> mixes;
  final bool isLoadingMore;
  final bool hasMoreData;

  TobaccoMixesLoaded copyWith({
    List<Mix>? mixes,
    bool? isLoadingMore,
    bool? hasMoreData,
  }) {
    return TobaccoMixesLoaded(
      mixes: mixes ?? this.mixes,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreData: hasMoreData ?? this.hasMoreData,
    );
  }
}

/// Ocurrió un error al cargar las mezclas del tabaco.
class TobaccoMixesError extends TobaccoMixesState {
  const TobaccoMixesError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class TobaccoMixesProvider extends ChangeNotifier {
  TobaccoMixesProvider(this._repository);

  final CommunityRepository _repository;

  TobaccoMixesState _state = const TobaccoMixesInitial();
  TobaccoMixesState get state => _state;

  static const int _pageSize = 10;
  int _currentOffset = 0;
  String? _tobaccoName;
  String? _tobaccoBrand;

  List<Mix> get mixes => switch (_state) {
    TobaccoMixesLoaded(mixes: final list) => List.unmodifiable(list),
    _ => const <Mix>[],
  };

  bool get isLoading => _state is TobaccoMixesLoading;

  bool get isLoadingMore => switch (_state) {
    TobaccoMixesLoaded(isLoadingMore: final loadingMore) => loadingMore,
    _ => false,
  };

  bool get hasMoreData => switch (_state) {
    TobaccoMixesLoaded(hasMoreData: final more) => more,
    TobaccoMixesError() => false,
    _ => true,
  };

  String? get error => switch (_state) {
    TobaccoMixesError(message: final msg) => msg,
    _ => null,
  };

  Future<void> loadMixes({
    required String tobaccoName,
    String? tobaccoBrand,
  }) async {
    _tobaccoName = tobaccoName;
    _tobaccoBrand = tobaccoBrand;

    _currentOffset = 0;
    _state = const TobaccoMixesLoading();
    notifyListeners();

    try {
      final fetched = await _repository.fetchMixes(
        orderBy: 'recent',
        limit: _pageSize,
        offset: 0,
        tobaccoName: tobaccoName,
        tobaccoBrand: tobaccoBrand,
      );

      _currentOffset = fetched.length;
      _state = TobaccoMixesLoaded(
        mixes: fetched,
        isLoadingMore: false,
        hasMoreData: fetched.length >= _pageSize,
      );
    } catch (e, stackTrace) {
      _state = const TobaccoMixesError('Error al cargar las mezclas');
      AppLogger.error(
        'Error loading tobacco mixes',
        error: e,
        stackTrace: stackTrace,
      );
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    final currentLoaded = _state is TobaccoMixesLoaded
        ? (_state as TobaccoMixesLoaded)
        : null;
    if (currentLoaded == null ||
        currentLoaded.isLoadingMore ||
        !currentLoaded.hasMoreData ||
        _tobaccoName == null) {
      return;
    }

    _state = currentLoaded.copyWith(isLoadingMore: true);
    notifyListeners();

    try {
      final newMixes = await _repository.fetchMixes(
        orderBy: 'recent',
        limit: _pageSize,
        offset: _currentOffset,
        tobaccoName: _tobaccoName,
        tobaccoBrand: _tobaccoBrand,
      );

      if (newMixes.isNotEmpty) {
        final updatedList = <Mix>[...currentLoaded.mixes, ...newMixes];
        _currentOffset += newMixes.length;
        _state = TobaccoMixesLoaded(
          mixes: updatedList,
          isLoadingMore: false,
          hasMoreData: newMixes.length >= _pageSize,
        );
      } else {
        _state = currentLoaded.copyWith(
          isLoadingMore: false,
          hasMoreData: false,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error loading more tobacco mixes',
        error: e,
        stackTrace: stackTrace,
      );
      // No seteamos error principal para no bloquear la UI ya cargada
      DatabaseHealthProvider.reportFailure(e);
      _state = currentLoaded.copyWith(isLoadingMore: false);
    } finally {
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_tobaccoName != null) {
      await loadMixes(tobaccoName: _tobaccoName!, tobaccoBrand: _tobaccoBrand);
    }
  }
}
