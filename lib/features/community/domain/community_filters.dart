/// Opciones de ordenamiento para las mezclas de la comunidad
enum CommunitySortOption {
  /// Más recientes primero (created_at desc)
  newest('Más recientes', 'created_at', false),

  /// Más antiguos primero (created_at asc)
  oldest('Más antiguos', 'created_at', true),

  /// Alfabético A-Z (name asc)
  nameAsc('Alfabético A-Z', 'name', true),

  /// Alfabético Z-A (name desc)
  nameDesc('Alfabético Z-A', 'name', false),

  /// Populares (aprox: rating desc)
  mostPopular('Populares', 'rating', false),

  /// Mejor valoradas (rating desc, reviews desc)
  topRated('Mejor valoradas', 'rating', false);

  const CommunitySortOption(this.label, this.field, this.ascending);

  final String label;
  final String field;
  final bool ascending;
}

/// Filtros simples para comunidad (MVP)
class CommunityFilterState {
  const CommunityFilterState({
    this.tobaccoName,
    this.tobaccoBrand,
    this.sortOption = CommunitySortOption.newest,
    this.favoritesOnly = false,
  });

  final String? tobaccoName; // nombre del tabaco seleccionado
  final String? tobaccoBrand; // marca del tabaco seleccionado
  final CommunitySortOption sortOption;
  final bool favoritesOnly;

  CommunityFilterState copyWith({
    String? tobaccoName,
    String? tobaccoBrand,
    CommunitySortOption? sortOption,
    bool? favoritesOnly,
  }) {
    return CommunityFilterState(
      tobaccoName: tobaccoName ?? this.tobaccoName,
      tobaccoBrand: tobaccoBrand ?? this.tobaccoBrand,
      sortOption: sortOption ?? this.sortOption,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    );
  }

  CommunityFilterState clearTobacco() => CommunityFilterState(
        tobaccoName: null,
        tobaccoBrand: null,
        sortOption: sortOption,
        favoritesOnly: favoritesOnly,
      );
}
