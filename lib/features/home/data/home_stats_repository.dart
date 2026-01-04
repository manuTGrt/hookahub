import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/supabase_service.dart';
import '../domain/home_stats.dart';

class HomeStatsRepository {
  HomeStatsRepository(this._supabase);

  final SupabaseService _supabase;

  Future<HomeStats> fetchStats() async {
    final client = _supabase.client;

    final results = await Future.wait<int>([
      _count(client, 'tobaccos'),
      _count(client, 'mixes'),
      _count(client, 'profiles'),
    ]);

    return HomeStats(
      tobaccos: results[0],
      mixes: results[1],
      users: results[2],
    );
  }

  Future<int> _count(SupabaseClient client, String table) async {
    // Nota: para compatibilidad con la versión actual de supabase_flutter
    // hacemos un select ligero y contamos filas en memoria. Si el dataset
    // crece, cambiar a una RPC de conteo o a select con opciones de count
    // cuando la API esté disponible.
    final response = await client.from(table).select('id');
    return (response as List).length;
  }
}
