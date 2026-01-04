import 'package:flutter/material.dart';
import '../../../core/data/supabase_service.dart';
import '../../../core/models/mix.dart';

class UserMixesRepository {
  UserMixesRepository(this._supabase);

  final SupabaseService _supabase;

  Future<List<Mix>> fetchMyMixes({int limit = 20, int offset = 0}) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) return [];

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
          .eq('author_id', user.id)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((mixData) {
        final components = mixData['mix_components'] as List? ?? [];
        final ingredients = components.map((c) => c['tobacco_name'] as String).toList();

        Color mixColor = const Color(0xFF72C8C1);
        if (components.isNotEmpty && components[0]['color'] != null) {
          final colorStr = components[0]['color'] as String;
          if (colorStr.startsWith('#') && colorStr.length == 7) {
            mixColor = Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
          }
        }

        final profile = mixData['profiles'];
        final authorName = profile != null
            ? (profile['username'] as String? ?? 'Yo')
            : 'Yo';

        return Mix(
          id: mixData['id'] as String,
          name: mixData['name'] as String,
          author: authorName,
          rating: (mixData['rating'] as num?)?.toDouble() ?? 0.0,
          reviews: (mixData['reviews'] as num?)?.toInt() ?? 0,
          ingredients: ingredients,
          color: mixColor,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error al obtener mis mezclas: $e');
      return [];
    }
  }
}
