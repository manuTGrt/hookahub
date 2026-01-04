import '../../../core/data/supabase_service.dart';
import '../../../core/models/tobacco.dart';
import '../domain/catalog_filters.dart';

class TobaccoRepository {
  TobaccoRepository(this._supabase);

  final SupabaseService _supabase;

  static const int defaultPageSize = 20;

  Future<List<Tobacco>> fetchTobaccos({
    required int offset,
    int limit = defaultPageSize,
    String? query,
    CatalogFilter? filter,
  }) async {
    final client = _supabase.client;

    dynamic request = client
        .from('tobaccos')
        .select('id, name, brand, description, image_url, created_at');

    // Filtro por búsqueda de texto
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      // Buscar por nombre, descripción o marca (case-insensitive)
      request = request.or('name.ilike.%$q%,description.ilike.%$q%,brand.ilike.%$q%');
    }

    // Filtro por marca
    if (filter?.brand != null && filter!.brand!.isNotEmpty) {
      request = request.eq('brand', filter.brand!);
    }

    // Ordenamiento
    final sort = filter?.sortOption ?? SortOption.newest;
    
    // Validar que el campo existe en la tabla
    // TODO: Descomentar cuando se ejecute la migración SQL que añade rating/reviews
    if (sort == SortOption.mostPopular || sort == SortOption.topRated) {
      // Temporal: usar created_at mientras no existan rating/reviews
      request = request.order('created_at', ascending: false);
      // Cuando se añadan los campos, usar:
      // if (sort == SortOption.mostPopular) {
      //   request = request.order('reviews', ascending: false);
      //   request = request.order('rating', ascending: false);
      // } else {
      //   request = request.order('rating', ascending: false);
      //   request = request.order('reviews', ascending: false);
      // }
    } else {
      request = request.order(sort.field, ascending: sort.ascending);
      
      // Ordenamiento secundario
      if (sort == SortOption.brandAsc) {
        request = request.order('name', ascending: true);
      }
    }

    final List<dynamic> rows = await request
        .range(offset, offset + limit - 1)
        .timeout(const Duration(seconds: 4));

    return rows.map<Tobacco>((r) {
      final map = r as Map<String, dynamic>;
      return Tobacco(
        id: map['id'] as String,
        name: map['name'] as String,
        brand: map['brand'] as String,
        description: map['description'] as String?,
        flavors: const <String>[],
        // TODO: Actualizar cuando se ejecute la migración SQL
        rating: 0.0, // (map['rating'] as num?)?.toDouble() ?? 0.0,
        reviews: 0, // (map['reviews'] as int?) ?? 0,
        imageUrl: map['image_url'] as String?,
      );
    }).toList();
  }

  /// Busca un tabaco por nombre y marca (case-insensitive). Devuelve el primero o null.
  Future<Tobacco?> findByNameAndBrand({
    required String name,
    required String brand,
  }) async {
    final client = _supabase.client;
    final List<dynamic> rows = await client
        .from('tobaccos')
        .select('id, name, brand, description, image_url, created_at')
        .ilike('name', name)
        .ilike('brand', brand)
        .limit(1)
        .timeout(const Duration(seconds: 4));

    if (rows.isEmpty) return null;
    final map = rows.first as Map<String, dynamic>;
    return Tobacco(
      id: map['id'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String,
      description: map['description'] as String?,
      flavors: const <String>[],
      // TODO: Actualizar cuando se ejecute la migración SQL
      rating: 0.0, // (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviews: 0, // (map['reviews'] as int?) ?? 0,
      imageUrl: map['image_url'] as String?,
    );
  }

  /// Obtiene la lista de marcas únicas disponibles en el catálogo, ordenadas alfabéticamente.
  Future<List<String>> fetchAvailableBrands() async {
    final client = _supabase.client;
    
    // Obtener marcas únicas y ordenarlas
    final List<dynamic> rows = await client
        .from('tobaccos')
        .select('brand')
        .order('brand', ascending: true)
        .timeout(const Duration(seconds: 4));

    // Extraer marcas únicas (por si Supabase no elimina duplicados)
    final brands = rows
        .map((r) => (r as Map<String, dynamic>)['brand'] as String)
        .toSet()
        .toList();
    
    return brands;
  }
}
