import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/mix.dart';
import '../domain/favorites_repository.dart' as domain;

/// Repositorio basado en SharedPreferences para guardar favoritos
/// y el orden del Top 5 (primeros elementos de la lista `top5Ids`).
class FavoritesRepository implements domain.FavoritesRepository {
  static const _favoritesKey = 'favorites_mixes'; // lista de mixes serializados
  static const _top5Key = 'top5_mix_ids'; // lista de ids (máx 5)

  @override
  Future<List<Mix>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_favoritesKey) ?? [];
    return jsonList
        .map((e) => Mix.fromMap(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveFavorites(List<Mix> mixes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = mixes.map((m) => jsonEncode(m.toMap())).toList();
    await prefs.setStringList(_favoritesKey, jsonList);
  }

  @override
  Future<List<String>> loadTop5Ids() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_top5Key) ?? [];
    // Garantizamos max 5
    return ids.take(5).toList();
  }

  @override
  Future<void> saveTop5Ids(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_top5Key, ids.take(5).toList());
  }
}
