import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hookahub/core/utils/app_logger.dart';
import '../../../core/constants.dart';
import '../../../core/data/supabase_service.dart';
import '../domain/visit_entry.dart';

/// Repositorio para gestionar el historial de mezclas visitadas.
/// Se encarga de la comunicación con Supabase para registrar y recuperar vistas.
class HistoryRepository {
  HistoryRepository(this._supabase);

  final SupabaseService _supabase;

  /// Registra una vista de mezcla en el historial del usuario actual.
  /// Si ya existe una vista previa de esta mezcla, actualiza la fecha/hora.
  ///
  /// [mixId]: ID de la mezcla que se está visitando.
  ///
  /// Retorna `true` si se registró correctamente, `false` en caso contrario.
  Future<bool> recordMixView(String mixId) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) {
        AppLogger.info('No hay usuario autenticado para registrar vista');
        return false;
      }

      // UPSERT: Insertar o actualizar si ya existe
      // La constraint unique(user_id, mix_id) asegura un solo registro por usuario-mezcla
      await _supabase.client.from('mix_views').upsert(
        {
          'user_id': user.id,
          'mix_id': mixId,
          'viewed_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,mix_id', // Columnas de la constraint única
      ).timeout(supabaseWriteTimeout);

      AppLogger.info('✅ Vista de mezcla registrada/actualizada: $mixId');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('❌ Error al registrar vista de mezcla', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Obtiene el historial de mezclas visitadas en los últimos [days] días.
  /// Por defecto obtiene las vistas de los últimos 2 días.
  ///
  /// [days]: Número de días hacia atrás para buscar (por defecto 2).
  /// [limit]: Número máximo de entradas a retornar (por defecto 100).
  ///
  /// Retorna una lista de [VisitEntry] ordenada por fecha descendente (más recientes primero).
  Future<List<VisitEntry>> fetchRecentHistory({
    int days = 2,
    int limit = 100,
  }) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) {
        AppLogger.info('No hay usuario autenticado');
        return [];
      }

      // Calcular la fecha límite (hace X días)
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      AppLogger.info('🔍 Cargando historial para usuario: ${user.id}');
      AppLogger.info('🔍 Fecha límite: ${cutoffDate.toIso8601String()}');

      // Consultar vistas con JOIN a mixes para obtener toda la información
      final response = await _supabase.client
          .from('mix_views')
          .select('''
            id,
            mix_id,
            viewed_at,
            mixes(
              id,
              name,
              rating,
              reviews,
              reviews_real:reviews(count),
              profiles!mixes_author_id_fkey(username),
              mix_components(tobacco_name, brand, percentage, color)
            )
          ''')
          .eq('user_id', user.id)
          .gte('viewed_at', cutoffDate.toIso8601String())
          .order('viewed_at', ascending: false)
          .limit(limit)
          .timeout(supabaseReadTimeout);

      // Convertir respuesta a lista de VisitEntry
      final entries = (response as List).map((data) {
        return VisitEntry.fromMap(data as Map<String, dynamic>);
      }).toList();

      AppLogger.info('✅ Historial cargado: ${entries.length} entradas');
      return entries;
    } catch (e, stackTrace) {
      AppLogger.error('Error al obtener historial', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Elimina todas las vistas de mezclas anteriores a [days] días.
  /// Útil para limpieza de datos antiguos.
  ///
  /// [days]: Número de días a mantener (por defecto 7).
  ///
  /// Retorna el número de registros eliminados.
  Future<int> clearOldHistory({int days = 7}) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) {
        AppLogger.info('No hay usuario autenticado');
        return 0;
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final response = await _supabase.client
          .from('mix_views')
          .delete()
          .eq('user_id', user.id)
          .lt('viewed_at', cutoffDate.toIso8601String())
          .select()
          .timeout(supabaseWriteTimeout);

      final deletedCount = (response as List).length;
      AppLogger.info('Eliminadas $deletedCount vistas antiguas');
      return deletedCount;
    } catch (e, stackTrace) {
      AppLogger.error('Error al limpiar historial antiguo', error: e, stackTrace: stackTrace);
      return 0;
    }
  }

  /// Elimina todo el historial del usuario actual.
  ///
  /// Retorna `true` si se eliminó correctamente.
  Future<bool> clearAllHistory() async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) {
        AppLogger.info('No hay usuario autenticado');
        return false;
      }

      await _supabase.client
          .from('mix_views')
          .delete()
          .eq('user_id', user.id)
          .timeout(supabaseWriteTimeout);

      AppLogger.info('Historial completo eliminado');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error al eliminar historial', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Obtiene el número total de mezclas únicas visitadas en los últimos [days] días.
  /// Utiliza conteo exacto a nivel de motor SQL sin sobrecargar la red ni la memoria.
  Future<int> getUniqueVisitedCount({int days = 2}) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) return 0;

      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final count = await _supabase.client
          .from('mix_views')
          .count(CountOption.exact)
          .eq('user_id', user.id)
          .gte('viewed_at', cutoffDate.toIso8601String())
          .timeout(supabaseReadTimeout);

      return count;
    } catch (e, stackTrace) {
      AppLogger.error('Error al contar visitas únicas', error: e, stackTrace: stackTrace);
      return 0;
    }
  }
}
