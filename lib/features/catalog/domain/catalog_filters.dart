/// Opciones de ordenamiento para el catálogo de tabacos
enum SortOption {
  /// Más recientes primero (por created_at desc)
  newest('Más recientes', 'created_at', false),
  
  /// Más antiguos primero (por created_at asc)
  oldest('Más antiguos', 'created_at', true),
  
  /// Alfabético A-Z (por name asc)
  nameAsc('Alfabético A-Z', 'name', true),
  
  /// Alfabético Z-A (por name desc)
  nameDesc('Alfabético Z-A', 'name', false),
  
  /// Por marca A-Z (por brand asc, name asc)
  brandAsc('Marca A-Z', 'brand', true),
  
  /// Más populares (por reviews desc, rating desc)
  mostPopular('Populares', 'reviews', false),
  
  /// Mejor valorados (por rating desc, reviews desc)
  topRated('Mejor valorados', 'rating', false);

  const SortOption(this.label, this.field, this.ascending);
  
  final String label;
  final String field;
  final bool ascending;
}

/// Filtro de catálogo con marca y ordenamiento
class CatalogFilter {
  const CatalogFilter({
    this.brand,
    this.sortOption = SortOption.newest,
  });

  final String? brand;
  final SortOption sortOption;

  CatalogFilter copyWith({
    String? brand,
    SortOption? sortOption,
  }) {
    return CatalogFilter(
      brand: brand ?? this.brand,
      sortOption: sortOption ?? this.sortOption,
    );
  }

  CatalogFilter clearBrand() {
    return CatalogFilter(
      brand: null,
      sortOption: sortOption,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CatalogFilter &&
        other.brand == brand &&
        other.sortOption == sortOption;
  }

  @override
  int get hashCode => Object.hash(brand, sortOption);
}
