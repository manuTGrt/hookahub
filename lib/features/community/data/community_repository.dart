import 'package:flutter/material.dart';
import '../../../core/data/supabase_service.dart';
import '../../../core/models/mix.dart';
// no-op

/// Repositorio para gestionar las mezclas de la comunidad desde Supabase.
class CommunityRepository {
  CommunityRepository(this._supabase);

  final SupabaseService _supabase;

  /// Obtiene una mezcla específica por su ID con todos sus detalles.
  /// Útil cuando se navega desde notificaciones o enlaces directos.
  Future<Mix?> fetchMixById(String mixId) async {
    try {
      final response = await _supabase.client
          .from('mixes')
          .select('''
            id,
            name,
            description,
            rating,
            reviews,
            created_at,
            profiles!mixes_author_id_fkey(username, display_name),
            mix_components(tobacco_name, brand, percentage, color)
          ''')
          .eq('id', mixId)
          .single();

      // Extraer componentes/ingredientes
      final components = response['mix_components'] as List? ?? [];
      final ingredients = components
          .map((c) => c['tobacco_name'] as String)
          .toList();

      // Usar el primer color de los componentes o un color por defecto
      Color mixColor = const Color(0xFF72C8C1);
      if (components.isNotEmpty && components[0]['color'] != null) {
        final colorStr = components[0]['color'] as String;
        if (colorStr.startsWith('#') && colorStr.length == 7) {
          mixColor = Color(
            int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
          );
        }
      }

      // Extraer autor
      final profile = response['profiles'];
      final authorName = profile != null
          ? (profile['username'] as String? ?? 'Anónimo')
          : 'Anónimo';

      return Mix(
        id: response['id'] as String,
        name: response['name'] as String,
        author: authorName,
        rating: (response['rating'] as num?)?.toDouble() ?? 0.0,

        reviews:
            (response['reviews_real'] as List?)?.firstOrNull?['count']
                as int? ??
            (response['reviews'] as num?)?.toInt() ??
            0,
        ingredients: ingredients,
        color: mixColor,
      );
    } catch (e) {
      debugPrint('Error al obtener mezcla por ID: $e');
      return null;
    }
  }

  /// Obtiene las mezclas de la comunidad con filtros opcionales.
  ///
  /// [orderBy] puede ser:
  /// - 'popular': ordenar por rating descendente
  /// - 'recent': ordenar por fecha de creación descendente
  /// - 'top_rated': ordenar por rating y número de reviews
  ///
  /// [limit] cantidad de mezclas a obtener
  /// [offset] desde qué posición empezar (para paginación)
  Future<List<Mix>> fetchMixes({
    String orderBy = 'recent',
    int limit = 20,
    int offset = 0,
    String? tobaccoName,
    String? tobaccoBrand,
  }) async {
    try {
      final bool filterByTobacco =
          (tobaccoName != null && tobaccoName.isNotEmpty);

      // Si filtramos por tabaco, primero obtenemos los IDs de mixes que coinciden
      List<dynamic> response;
      List<String> targetIds = [];
      if (filterByTobacco) {
        dynamic idQuery = _supabase.client
            .from('mixes')
            .select('id, mix_components!inner(tobacco_name, brand)');

        idQuery = idQuery.eq('mix_components.tobacco_name', tobaccoName);
        if (tobaccoBrand != null && tobaccoBrand.isNotEmpty) {
          idQuery = idQuery.eq('mix_components.brand', tobaccoBrand);
        }

        // Aplicar el mismo orden a la consulta de IDs
        switch (orderBy) {
          case 'recent':
            idQuery = idQuery.order('created_at', ascending: false);
            break;
          case 'recent_asc':
            idQuery = idQuery.order('created_at', ascending: true);
            break;
          case 'name_asc':
            idQuery = idQuery.order('name', ascending: true);
            break;
          case 'name_desc':
            idQuery = idQuery.order('name', ascending: false);
            break;
          case 'popular':
          case 'top_rated':
            idQuery = idQuery
                .order('rating', ascending: false)
                .order('reviews', ascending: false);
            break;
          default:
            idQuery = idQuery.order('created_at', ascending: false);
        }

        final List dataIds = await idQuery.range(offset, offset + limit - 1);
        targetIds = dataIds
            .map((row) => (row as Map<String, dynamic>)['id'] as String)
            .toList();
        if (targetIds.isEmpty) {
          return [];
        }

        // Segunda consulta: traer mixes completos con todos los componentes
        dynamic request = _supabase.client
            .from('mixes')
            .select('''
              id,
              name,
              description,
              rating,
              reviews,
              reviews_real:reviews(count),
              created_at,
              profiles!mixes_author_id_fkey(username, display_name),
              mix_components(tobacco_name, brand, percentage, color)
            ''')
            .inFilter('id', targetIds);

        // Reaplicar orden para consistencia
        switch (orderBy) {
          case 'recent':
            request = request.order('created_at', ascending: false);
            break;
          case 'recent_asc':
            request = request.order('created_at', ascending: true);
            break;
          case 'name_asc':
            request = request.order('name', ascending: true);
            break;
          case 'name_desc':
            request = request.order('name', ascending: false);
            break;
          case 'popular':
          case 'top_rated':
            request = request
                .order('rating', ascending: false)
                .order('reviews', ascending: false);
            break;
          default:
            request = request.order('created_at', ascending: false);
        }

        response = await request;
      } else {
        // Sin filtro por tabaco: consulta directa con todos los componentes
        dynamic request = _supabase.client.from('mixes').select('''
              id,
              name,
              description,
              rating,
              reviews,
              created_at,
              profiles!mixes_author_id_fkey(username, display_name),
              reviews_real:reviews(count),
              mix_components(tobacco_name, brand, percentage, color)
            ''');

        switch (orderBy) {
          case 'recent':
            request = request.order('created_at', ascending: false);
            break;
          case 'recent_asc':
            request = request.order('created_at', ascending: true);
            break;
          case 'name_asc':
            request = request.order('name', ascending: true);
            break;
          case 'name_desc':
            request = request.order('name', ascending: false);
            break;
          case 'popular':
          case 'top_rated':
            request = request
                .order('rating', ascending: false)
                .order('reviews', ascending: false);
            break;
          default:
            request = request.order('created_at', ascending: false);
        }

        response = await request.range(offset, offset + limit - 1);
      }

      return response.map((mixData) {
        // Extraer componentes/ingredientes
        final components = mixData['mix_components'] as List? ?? [];
        final ingredients = components
            .map((c) => c['tobacco_name'] as String)
            .toList();

        // Usar el primer color de los componentes o un color por defecto
        Color mixColor = const Color(0xFF72C8C1); // turquoise por defecto
        if (components.isNotEmpty && components[0]['color'] != null) {
          final colorStr = components[0]['color'] as String;
          // Si es un hex color string (ej: "#RRGGBB"), parsearlo
          if (colorStr.startsWith('#') && colorStr.length == 7) {
            mixColor = Color(
              int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
            );
          }
        }

        // Extraer autor (usar username en lugar de display_name)
        final profile = mixData['profiles'];
        final authorName = profile != null
            ? (profile['username'] as String? ?? 'Anónimo')
            : 'Anónimo';

        return Mix(
          id: mixData['id'] as String,
          name: mixData['name'] as String,
          author: authorName,
          rating: (mixData['rating'] as num?)?.toDouble() ?? 0.0,
          reviews:
              (mixData['reviews_real'] as List?)?.firstOrNull?['count']
                  as int? ??
              (mixData['reviews'] as num?)?.toInt() ??
              0,
          ingredients: ingredients,
          color: mixColor,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error al obtener mezclas: $e');
      return [];
    }
  }

  /// Devuelve una lista de tabacos disponibles (name, brand) para el buscador.
  Future<List<Map<String, String>>> fetchAvailableTobaccos({
    String? query,
    int? limit,
  }) async {
    final q = query?.trim();
    final client = _supabase.client;
    final result = <Map<String, String>>[];
    final seen = <String>{};

    // Búsqueda con query: filtrar en servidor y aplicar límite si se pasó
    if (q != null && q.isNotEmpty) {
      dynamic request = client
          .from('tobaccos')
          .select('name, brand')
          .or('name.ilike.%$q%,brand.ilike.%$q%')
          .order('brand', ascending: true)
          .order('name', ascending: true);

      if (limit != null) {
        request = request.limit(limit);
      }

      final List data = await request;
      for (final row in data) {
        final name = (row['name'] as String?) ?? '';
        final brand = (row['brand'] as String?) ?? '';
        final key = '$brand::$name';
        if (name.isEmpty || brand.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        result.add({'name': name, 'brand': brand});
      }
      return result;
    }

    // Sin query: traer todo con paginación amplia y filtrar localmente, como en catálogo
    const pageSize = 1000; // tamaño de página grande para reducir rondas
    final cap = limit ?? 5000; // tope de seguridad para no dispararse
    var offset = 0;
    while (offset < cap) {
      final end = offset + pageSize - 1;
      final List page = await client
          .from('tobaccos')
          .select('name, brand')
          .order('brand', ascending: true)
          .order('name', ascending: true)
          .range(offset, end);

      if (page.isEmpty) break;
      for (final row in page) {
        final name = (row['name'] as String?) ?? '';
        final brand = (row['brand'] as String?) ?? '';
        final key = '$brand::$name';
        if (name.isEmpty || brand.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        result.add({'name': name, 'brand': brand});
        if (result.length >= cap) break;
      }
      if (page.length < pageSize || result.length >= cap) break;
      offset += pageSize;
    }

    return result;
  }

  /// Actualiza una mezcla y sustituye sus componentes.
  Future<Mix?> updateMix({
    required String mixId,
    required String name,
    String? description,
    required List<Map<String, dynamic>> components,
  }) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) {
        debugPrint('Usuario no autenticado');
        return null;
      }

      // Actualizar cabecera de la mezcla
      await _supabase.client
          .from('mixes')
          .update({
            'name': name,
            'description': description,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', mixId);

      // Reemplazar componentes: borrar e insertar
      await _supabase.client
          .from('mix_components')
          .delete()
          .eq('mix_id', mixId);

      if (components.isNotEmpty) {
        final componentsData = components
            .map(
              (c) => {
                'mix_id': mixId,
                'tobacco_name': c['tobacco_name'],
                'brand': c['brand'],
                'percentage': c['percentage'],
                'color': c['color'],
              },
            )
            .toList();
        await _supabase.client.from('mix_components').insert(componentsData);
      }

      // Obtener username del autor para regresar un Mix coherente
      final profileResponse = await _supabase.client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .single();
      final authorName = profileResponse['username'] as String? ?? 'Anónimo';

      final ingredients = components
          .map((c) => c['tobacco_name'] as String)
          .toList();

      Color mixColor = const Color(0xFF72C8C1);
      if (components.isNotEmpty && components[0]['color'] != null) {
        final colorStr = components[0]['color'] as String;
        if (colorStr.startsWith('#') && colorStr.length == 7) {
          mixColor = Color(
            int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
          );
        }
      }

      // Recuperar rating/reviews actuales
      final mixRow = await _supabase.client
          .from('mixes')
          .select('rating, reviews')
          .eq('id', mixId)
          .single();

      return Mix(
        id: mixId,
        name: name,
        author: authorName,
        rating: (mixRow['rating'] as num?)?.toDouble() ?? 0.0,
        reviews: (mixRow['reviews'] as num?)?.toInt() ?? 0,
        ingredients: ingredients,
        color: mixColor,
      );
    } catch (e) {
      debugPrint('Error al actualizar mezcla: $e');
      return null;
    }
  }

  /// Obtiene las mezclas favoritas del usuario autenticado.
  Future<List<Mix>> fetchFavorites() async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase.client
          .from('favorites')
          .select('''
            mix_id,
            mixes!inner(
              id,
              name,
              description,
              rating,
              reviews,
              reviews_real:reviews(count),
              created_at,
              profiles!mixes_author_id_fkey(username, display_name),
              mix_components(tobacco_name, brand, percentage, color)
            )
          ''')
          .eq('user_id', user.id);

      return (response as List).map((favData) {
        final mixData = favData['mixes'];
        final components = mixData['mix_components'] as List? ?? [];
        final ingredients = components
            .map((c) => c['tobacco_name'] as String)
            .toList();

        Color mixColor = const Color(0xFF72C8C1);
        if (components.isNotEmpty && components[0]['color'] != null) {
          final colorStr = components[0]['color'] as String;
          if (colorStr.startsWith('#') && colorStr.length == 7) {
            mixColor = Color(
              int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
            );
          }
        }

        // Extraer autor (usar username en lugar de display_name)
        final profile = mixData['profiles'];
        final authorName = profile != null
            ? (profile['username'] as String? ?? 'Anónimo')
            : 'Anónimo';

        return Mix(
          id: mixData['id'] as String,
          name: mixData['name'] as String,
          author: authorName,
          rating: (mixData['rating'] as num?)?.toDouble() ?? 0.0,
          reviews:
              (mixData['reviews_real'] as List?)?.firstOrNull?['count']
                  as int? ??
              (mixData['reviews'] as num?)?.toInt() ??
              0,
          ingredients: ingredients,
          color: mixColor,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error al obtener favoritas: $e');
      return [];
    }
  }

  /// Crea una nueva mezcla en la base de datos.
  ///
  /// [components] es una lista de mapas con los campos:
  /// - tobacco_name: String
  /// - brand: String
  /// - percentage: double
  /// - color: String (hex, ej: "#72C8C1")
  Future<Mix?> createMix({
    required String name,
    String? description,
    required List<Map<String, dynamic>> components,
  }) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) {
        debugPrint('Usuario no autenticado');
        return null;
      }

      // Insertar mezcla
      final mixResponse = await _supabase.client
          .from('mixes')
          .insert({
            'name': name,
            'description': description,
            'author_id': user.id,
            'rating': 0.0,
            'reviews': 0,
          })
          .select()
          .single();

      final mixId = mixResponse['id'] as String;

      // Insertar componentes
      final componentsData = components
          .map(
            (c) => {
              'mix_id': mixId,
              'tobacco_name': c['tobacco_name'],
              'brand': c['brand'],
              'percentage': c['percentage'],
              'color': c['color'],
            },
          )
          .toList();

      await _supabase.client.from('mix_components').insert(componentsData);

      // Obtener perfil del usuario (usar username)
      final profileResponse = await _supabase.client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .single();

      final authorName = profileResponse['username'] as String? ?? 'Anónimo';

      // Construir objeto Mix
      final ingredients = components
          .map((c) => c['tobacco_name'] as String)
          .toList();

      Color mixColor = const Color(0xFF72C8C1);
      if (components.isNotEmpty && components[0]['color'] != null) {
        final colorStr = components[0]['color'] as String;
        if (colorStr.startsWith('#') && colorStr.length == 7) {
          mixColor = Color(
            int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
          );
        }
      }

      return Mix(
        id: mixId,
        name: name,
        author: authorName,
        rating: 0.0,
        reviews: 0,
        ingredients: ingredients,
        color: mixColor,
      );
    } catch (e) {
      debugPrint('Error al crear mezcla: $e');
      return null;
    }
  }

  /// Obtiene los detalles completos de una mezcla específica por ID.
  /// Incluye descripción y componentes (ingredientes con porcentajes).
  Future<Map<String, dynamic>?> fetchMixDetails(String mixId) async {
    try {
      final response = await _supabase.client
          .from('mixes')
          .select('''
            id,
            name,
            description,
            rating,
            reviews,
            created_at,
            profiles!mixes_author_id_fkey(username, display_name),
            mix_components(tobacco_name, brand, percentage, color)
          ''')
          .eq('id', mixId)
          .single();

      // Extraer componentes
      final List<Map<String, dynamic>> components = [];
      for (final c in (response['mix_components'] as List? ?? [])) {
        Color color = const Color(0xFF72C8C1); // color por defecto
        final colorVal = c['color'];
        if (colorVal is String &&
            colorVal.startsWith('#') &&
            colorVal.length == 7) {
          color = Color(
            int.parse(colorVal.substring(1), radix: 16) + 0xFF000000,
          );
        }
        components.add({
          'tobacco_name': c['tobacco_name'] as String,
          'brand': c['brand'] as String,
          'percentage': (c['percentage'] as num).toDouble(),
          'color': color,
        });
      }

      // Enriquecer cada componente con su descripción desde la tabla tobaccos
      for (final comp in components) {
        try {
          final List descRes = await _supabase.client
              .from('tobaccos')
              .select('description')
              .eq('name', comp['tobacco_name'] as String)
              .eq('brand', comp['brand'] as String)
              .limit(1);
          if (descRes.isNotEmpty) {
            comp['description'] = descRes.first['description'];
          }
        } catch (_) {
          // Ignorar errores de descripción individual
        }
      }

      return {
        'description':
            response['description'] as String? ?? 'Sin descripción disponible.',
        'components': components,
      };
    } catch (e) {
      debugPrint('Error al obtener detalles de mezcla: $e');
      return null;
    }
  }

  /// Obtiene mezclas relacionadas que comparten al menos un tabaco con la mezcla dada.
  /// Excluye la mezcla actual de los resultados.
  Future<List<Mix>> fetchRelatedMixes({
    required String currentMixId,
    required List<String> tobaccoNames,
    int limit = 5,
  }) async {
    if (tobaccoNames.isEmpty) return [];

    try {
      // Buscar mezclas que contengan al menos uno de los tabacos
      final response = await _supabase.client
          .from('mix_components')
          .select('''
            mix_id,
            mixes!inner(
              id,
              name,
              description,
              rating,
              reviews,
              reviews_real:reviews(count),
              created_at,
              profiles!mixes_author_id_fkey(username, display_name),
              mix_components(tobacco_name, brand, percentage, color)
            )
          ''')
          .inFilter('tobacco_name', tobaccoNames)
          .neq('mix_id', currentMixId)
          .limit(limit * 3); // Obtener más para filtrar duplicados

      // Agrupar por mix_id para evitar duplicados
      final Map<String, dynamic> uniqueMixes = {};
      for (final item in response as List) {
        final mixData = item['mixes'];
        final mixId = mixData['id'] as String;
        if (!uniqueMixes.containsKey(mixId)) {
          uniqueMixes[mixId] = mixData;
        }
      }

      // Convertir a objetos Mix
      final mixes = uniqueMixes.values.take(limit).map((mixData) {
        final components = mixData['mix_components'] as List? ?? [];
        final ingredients = components
            .map((c) => c['tobacco_name'] as String)
            .toList();

        Color mixColor = const Color(0xFF72C8C1);
        if (components.isNotEmpty && components[0]['color'] != null) {
          final colorStr = components[0]['color'] as String;
          if (colorStr.startsWith('#') && colorStr.length == 7) {
            mixColor = Color(
              int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
            );
          }
        }

        final profile = mixData['profiles'];
        final authorName = profile != null
            ? (profile['username'] as String? ?? 'Anónimo')
            : 'Anónimo';

        return Mix(
          id: mixData['id'] as String,
          name: mixData['name'] as String,
          author: authorName,
          rating: (mixData['rating'] as num?)?.toDouble() ?? 0.0,
          reviews:
              (mixData['reviews_real'] as List?)?.firstOrNull?['count']
                  as int? ??
              (mixData['reviews'] as num?)?.toInt() ??
              0,
          ingredients: ingredients,
          color: mixColor,
        );
      }).toList();

      return mixes;
    } catch (e) {
      debugPrint('Error al obtener mezclas relacionadas: $e');
      return [];
    }
  }

  /// Obtiene las reseñas de una mezcla específica.
  Future<List<Map<String, dynamic>>> fetchReviews(String mixId) async {
    try {
      final response = await _supabase.client
          .from('reviews')
          .select('''
            id,
            rating,
            comment,
            created_at,
            author_id,
            profiles!reviews_author_id_fkey(username, display_name, avatar_url)
          ''')
          .eq('mix_id', mixId)
          .order('created_at', ascending: false);

      return (response as List).map((reviewData) {
        final profile = reviewData['profiles'];
        return {
          'id': reviewData['id'] as String,
          'author': profile != null
              ? (profile['username'] as String? ?? 'Anónimo')
              : 'Anónimo',
          'author_id': reviewData['author_id'] as String?,
          'rating': (reviewData['rating'] as num).toDouble(),
          'comment': reviewData['comment'] as String? ?? '',
          'created_at': DateTime.parse(reviewData['created_at'] as String),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error al obtener reseñas: $e');
      return [];
    }
  }

  /// Crea una nueva reseña para una mezcla.
  Future<bool> createReview({
    required String mixId,
    required double rating,
    required String comment,
  }) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) {
        debugPrint('Usuario no autenticado');
        return false;
      }

      await _supabase.client.from('reviews').insert({
        'mix_id': mixId,
        'author_id': user.id,
        'rating': rating,
        'comment': comment,
      });

      // Actualizar el rating promedio y el conteo de reviews de la mezcla
      await _updateMixRating(mixId);

      return true;
    } catch (e) {
      debugPrint('Error al crear reseña: $e');
      return false;
    }
  }

  /// Actualiza el rating promedio y el conteo de reviews de una mezcla.
  Future<void> _updateMixRating(String mixId) async {
    try {
      final reviews = await _supabase.client
          .from('reviews')
          .select('rating')
          .eq('mix_id', mixId);

      if (reviews.isEmpty) {
        await _supabase.client
            .from('mixes')
            .update({'rating': 0.0, 'reviews': 0})
            .eq('id', mixId);
        return;
      }

      final ratings = (reviews as List)
          .map((r) => (r['rating'] as num).toDouble())
          .toList();
      final avgRating = ratings.reduce((a, b) => a + b) / ratings.length;

      await _supabase.client
          .from('mixes')
          .update({'rating': avgRating, 'reviews': ratings.length})
          .eq('id', mixId);
    } catch (e) {
      debugPrint('Error al actualizar rating de mezcla: $e');
    }
  }

  /// Elimina una reseña por su ID.
  Future<bool> deleteReview(String reviewId, String mixId) async {
    try {
      await _supabase.client.from('reviews').delete().eq('id', reviewId);

      // Actualizar el rating de la mezcla después de eliminar
      await _updateMixRating(mixId);

      return true;
    } catch (e) {
      debugPrint('Error al eliminar reseña: $e');
      return false;
    }
  }

  /// Actualiza una reseña existente.
  Future<bool> updateReview({
    required String reviewId,
    required String mixId,
    required double rating,
    required String comment,
  }) async {
    try {
      await _supabase.client
          .from('reviews')
          .update({'rating': rating, 'comment': comment})
          .eq('id', reviewId);

      // Actualizar el rating de la mezcla después de editar
      await _updateMixRating(mixId);

      return true;
    } catch (e) {
      debugPrint('Error al actualizar reseña: $e');
      return false;
    }
  }

  /// Verifica si la mezcla pertenece al usuario autenticado.
  Future<bool> isMyMix(String mixId) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) return false;

      final res = await _supabase.client
          .from('mixes')
          .select('author_id')
          .eq('id', mixId)
          .single();

      final authorId = res['author_id'] as String?;
      return authorId != null && authorId == user.id;
    } catch (e) {
      debugPrint('Error al comprobar propiedad de mezcla: $e');
      return false;
    }
  }

  /// Elimina una mezcla por ID. Requiere permisos RLS adecuados en Supabase.
  Future<bool> deleteMix(String mixId) async {
    try {
      // Intentar borrar directamente la mezcla. Si hay FKs con CASCADE,
      // eliminará componentes/reseñas asociadas automáticamente.
      await _supabase.client.from('mixes').delete().eq('id', mixId);
      return true;
    } catch (e) {
      debugPrint('Error al eliminar mezcla: $e');
      return false;
    }
  }
}
