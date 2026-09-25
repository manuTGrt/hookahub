import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/data/supabase_service.dart';
import '../../../core/models/mix.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/favorites_repository.dart' as domain;

/// Repositorio híbrido (Supabase + SharedPreferences) para gestionar
/// las mezclas favoritas y el Top 5 con aislamiento por usuario.
class FavoritesRepository implements domain.FavoritesRepository {
  FavoritesRepository({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService();

  final SupabaseService _supabase;
  SupabaseClient get _client => _supabase.client;

  static const _legacyFavoritesKey = 'favorites_mixes';
  static const _legacyTop5Key = 'top5_mix_ids';

  String _getFavoritesKey(String? userId) =>
      (userId != null && userId.isNotEmpty)
          ? 'favorites_mixes_$userId'
          : 'favorites_mixes_guest';

  String _getTop5Key(String? userId) =>
      (userId != null && userId.isNotEmpty)
          ? 'top5_mix_ids_$userId'
          : 'top5_mix_ids_guest';

  String? _resolveUserId(String? userId) {
    if (userId != null && userId.isNotEmpty) return userId;
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Mix>> loadFavorites({String? userId}) async {
    final effectiveUserId = _resolveUserId(userId);

    if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
      try {
        final response = await _client
            .from('favorites')
            .select('''
              mix_id,
              is_top5,
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
            .eq('user_id', effectiveUserId)
            .timeout(supabaseReadTimeout);

        final List<Mix> cloudFavorites = (response as List).map((favData) {
          final mixData = favData['mixes'] as Map<String, dynamic>;
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

        // Si la nube está vacía, comprobar si hay datos legacy para migrar
        if (cloudFavorites.isEmpty) {
          final migrated = await _migrateLegacyFavoritesIfPresent(effectiveUserId);
          if (migrated.isNotEmpty) {
            return migrated;
          }
        }

        // Guardar copia fresca en caché local del usuario
        await _saveFavoritesToCache(cloudFavorites, effectiveUserId);
        return cloudFavorites;
      } catch (e, stack) {
        AppLogger.warning(
          'No se pudieron cargar favoritos de Supabase, usando caché local',
          error: e,
          stackTrace: stack,
        );
        return _loadFavoritesFromCache(effectiveUserId);
      }
    }

    return _loadFavoritesFromCache(null);
  }

  @override
  Future<void> saveFavorites(List<Mix> mixes, {String? userId}) async {
    final effectiveUserId = _resolveUserId(userId);
    await _saveFavoritesToCache(mixes, effectiveUserId);
  }

  @override
  Future<void> addFavorite(Mix mix, {String? userId}) async {
    final effectiveUserId = _resolveUserId(userId);

    // 1. Actualizar caché local de inmediato para respuesta optimista
    final current = await _loadFavoritesFromCache(effectiveUserId);
    if (!current.any((m) => m.id == mix.id)) {
      await _saveFavoritesToCache([...current, mix], effectiveUserId);
    }

    // 2. Persistir en Supabase si hay usuario autenticado
    if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
      try {
        await _client.from('favorites').upsert({
          'user_id': effectiveUserId,
          'mix_id': mix.id,
          'is_top5': false,
        }).timeout(supabaseWriteTimeout);
      } catch (e, stack) {
        AppLogger.error(
          'Error al guardar favorito en Supabase',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }

  @override
  Future<void> removeFavorite(String mixId, {String? userId}) async {
    final effectiveUserId = _resolveUserId(userId);

    // 1. Actualizar caché local
    final current = await _loadFavoritesFromCache(effectiveUserId);
    await _saveFavoritesToCache(
      current.where((m) => m.id != mixId).toList(),
      effectiveUserId,
    );
    final top5 = await loadTop5Ids(userId: effectiveUserId);
    if (top5.contains(mixId)) {
      await saveTop5Ids(
        top5.where((id) => id != mixId).toList(),
        userId: effectiveUserId,
      );
    }

    // 2. Borrar de Supabase si hay sesión
    if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
      try {
        await _client
            .from('favorites')
            .delete()
            .eq('user_id', effectiveUserId)
            .eq('mix_id', mixId)
            .timeout(supabaseWriteTimeout);
      } catch (e, stack) {
        AppLogger.error(
          'Error al eliminar favorito de Supabase',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }

  @override
  Future<List<String>> loadTop5Ids({String? userId}) async {
    final effectiveUserId = _resolveUserId(userId);

    if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
      try {
        final response = await _client
            .from('favorites')
            .select('mix_id, is_top5, created_at')
            .eq('user_id', effectiveUserId)
            .eq('is_top5', true)
            .order('created_at', ascending: true)
            .timeout(supabaseReadTimeout);

        final cloudTop5 = (response as List)
            .map((item) => item['mix_id'] as String)
            .take(5)
            .toList();

        if (cloudTop5.isEmpty) {
          final migrated = await _migrateLegacyTop5IfPresent(effectiveUserId);
          if (migrated.isNotEmpty) {
            return migrated;
          }
        }

        await _saveTop5ToCache(cloudTop5, effectiveUserId);
        return cloudTop5;
      } catch (e, stack) {
        AppLogger.warning(
          'No se pudo cargar Top 5 de Supabase, usando caché local',
          error: e,
          stackTrace: stack,
        );
        return _loadTop5FromCache(effectiveUserId);
      }
    }

    return _loadTop5FromCache(null);
  }

  @override
  Future<void> saveTop5Ids(List<String> ids, {String? userId}) async {
    final effectiveUserId = _resolveUserId(userId);
    final limitedIds = ids.take(5).toList();

    // 1. Guardar en caché local
    await _saveTop5ToCache(limitedIds, effectiveUserId);

    // 2. Actualizar en Supabase
    if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
      try {
        // Desmarcar las mezclas favoritas que ya no están en el Top 5
        if (limitedIds.isEmpty) {
          await _client
              .from('favorites')
              .update({'is_top5': false})
              .eq('user_id', effectiveUserId)
              .timeout(supabaseWriteTimeout);
        } else {
          final filterList = "(${limitedIds.map((id) => '"$id"').join(',')})";
          await _client
              .from('favorites')
              .update({'is_top5': false})
              .eq('user_id', effectiveUserId)
              .filter('mix_id', 'not.in', filterList)
              .timeout(supabaseWriteTimeout);

          await _client
              .from('favorites')
              .update({'is_top5': true})
              .eq('user_id', effectiveUserId)
              .filter('mix_id', 'in', filterList)
              .timeout(supabaseWriteTimeout);
        }
      } catch (e, stack) {
        AppLogger.error(
          'Error al guardar Top 5 en Supabase',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }

  // --- Métodos Privados de Caché y Migración ---

  Future<List<Mix>> _loadFavoritesFromCache(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getFavoritesKey(userId);
    var jsonList = prefs.getStringList(key);
    if ((jsonList == null || jsonList.isEmpty) && prefs.containsKey(_legacyFavoritesKey)) {
      jsonList = prefs.getStringList(_legacyFavoritesKey);
      if (jsonList != null && jsonList.isNotEmpty && userId != null) {
        // Copiar a la clave del usuario
        await prefs.setStringList(key, jsonList);
      }
    }
    jsonList ??= [];
    return jsonList
        .map((e) => Mix.fromMap(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveFavoritesToCache(List<Mix> mixes, String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getFavoritesKey(userId);
    final jsonList = mixes.map((m) => jsonEncode(m.toMap())).toList();
    await prefs.setStringList(key, jsonList);
  }

  Future<List<String>> _loadTop5FromCache(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getTop5Key(userId);
    var ids = prefs.getStringList(key);
    if ((ids == null || ids.isEmpty) && prefs.containsKey(_legacyTop5Key)) {
      ids = prefs.getStringList(_legacyTop5Key);
      if (ids != null && ids.isNotEmpty && userId != null) {
        await prefs.setStringList(key, ids);
      }
    }
    ids ??= [];
    return ids.take(5).toList();
  }

  Future<void> _saveTop5ToCache(List<String> ids, String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getTop5Key(userId);
    await prefs.setStringList(key, ids.take(5).toList());
  }

  Future<List<Mix>> _migrateLegacyFavoritesIfPresent(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final legacyList = prefs.getStringList(_legacyFavoritesKey);
    if (legacyList == null || legacyList.isEmpty) return [];

    try {
      final mixes = legacyList
          .map((e) => Mix.fromMap(jsonDecode(e) as Map<String, dynamic>))
          .toList();

      for (final mix in mixes) {
        await _client.from('favorites').upsert({
          'user_id': userId,
          'mix_id': mix.id,
          'is_top5': false,
        }).timeout(supabaseWriteTimeout);
      }

      await _saveFavoritesToCache(mixes, userId);
      await prefs.remove(_legacyFavoritesKey);
      AppLogger.info('Migración exitosa de favoritos legacy a Supabase');
      return mixes;
    } catch (e, stack) {
      AppLogger.warning(
        'No se pudo migrar favoritos legacy a Supabase',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }

  Future<List<String>> _migrateLegacyTop5IfPresent(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final legacyIds = prefs.getStringList(_legacyTop5Key);
    if (legacyIds == null || legacyIds.isEmpty) return [];

    try {
      final top5 = legacyIds.take(5).toList();
      for (final id in top5) {
        await _client.from('favorites').upsert({
          'user_id': userId,
          'mix_id': id,
          'is_top5': true,
        }).timeout(supabaseWriteTimeout);
      }

      await _saveTop5ToCache(top5, userId);
      await prefs.remove(_legacyTop5Key);
      AppLogger.info('Migración exitosa de Top 5 legacy a Supabase');
      return top5;
    } catch (e, stack) {
      AppLogger.warning(
        'No se pudo migrar Top 5 legacy a Supabase',
        error: e,
        stackTrace: stack,
      );
      return [];
    }
  }
}

