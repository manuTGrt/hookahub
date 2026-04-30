import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/supabase_service.dart';
import '../domain/home_stats.dart';

class HomeStatsRepository {
  HomeStatsRepository(this._supabase);

  final SupabaseService _supabase;

  Future<HomeStats> fetchStats() async {
    final response = await _supabase.client
        .from('app_statistics')
        .select()
        .eq('id', 1)
        .maybeSingle();

    if (response == null) return HomeStats.empty;
    return HomeStats(
      tobaccos: response['total_tobaccos'] as int? ?? 0,
      mixes: response['total_mixes'] as int? ?? 0,
      users: response['total_users'] as int? ?? 0,
    );
  }

  Stream<HomeStats> streamStats() {
    return _supabase.client
        .from('app_statistics')
        .stream(primaryKey: ['id'])
        .eq('id', 1)
        .map((data) {
      if (data.isEmpty) return HomeStats.empty;
      final row = data.first;
      return HomeStats(
        tobaccos: row['total_tobaccos'] as int? ?? 0,
        mixes: row['total_mixes'] as int? ?? 0,
        users: row['total_users'] as int? ?? 0,
      );
    });
  }
}
