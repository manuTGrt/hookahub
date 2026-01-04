import 'package:flutter/material.dart';
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
        debugPrint('No hay usuario autenticado para registrar vista');
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
      );

      debugPrint('✅ Vista de mezcla registrada/actualizada: $mixId');
      return true;
    } catch (e) {
      debugPrint('❌ Error al registrar vista de mezcla: $e');
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
        debugPrint('No hay usuario autenticado');
        return [];
      }

      // Calcular la fecha límite (hace X días)
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      debugPrint('🔍 Cargando historial para usuario: ${user.id}');
      debugPrint('🔍 Fecha límite: ${cutoffDate.toIso8601String()}');

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
              profiles!mixes_author_id_fkey(username),
              mix_components(tobacco_name, brand, percentage, color)
            )
          ''')
          .eq('user_id', user.id)
          .gte('viewed_at', cutoffDate.toIso8601String())
          .order('viewed_at', ascending: false)
          .limit(limit);

      debugPrint('🔍 Respuesta raw de Supabase: $response');
      debugPrint('🔍 Tipo de respuesta: ${response.runtimeType}');
      debugPrint('🔍 Número de registros: ${(response as List).length}');

      // Convertir respuesta a lista de VisitEntry
      final entries = (response as List)
          .map((data) {
            debugPrint('🔍 Procesando entrada: $data');
            return VisitEntry.fromMap(data as Map<String, dynamic>);
          })
          .toList();

      debugPrint('✅ Historial cargado: ${entries.length} entradas');
      return entries;
    } catch (e) {
      debugPrint('Error al obtener historial: $e');
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
        debugPrint('No hay usuario autenticado');
        return 0;
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final response = await _supabase.client
          .from('mix_views')
          .delete()
          .eq('user_id', user.id)
          .lt('viewed_at', cutoffDate.toIso8601String())
          .select();

      final deletedCount = (response as List).length;
      debugPrint('Eliminadas $deletedCount vistas antiguas');
      return deletedCount;
    } catch (e) {
      debugPrint('Error al limpiar historial antiguo: $e');
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
        debugPrint('No hay usuario autenticado');
        return false;
      }

      await _supabase.client
          .from('mix_views')
          .delete()
          .eq('user_id', user.id);

      debugPrint('Historial completo eliminado');
      return true;
    } catch (e) {
      debugPrint('Error al eliminar historial: $e');
      return false;
    }
  }

  /// Obtiene el número total de mezclas únicas visitadas en los últimos [days] días.
  /// Con la constraint UNIQUE, cada registro ya representa una mezcla única.
  Future<int> getUniqueVisitedCount({int days = 2}) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) return 0;

      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      final response = await _supabase.client
          .from('mix_views')
          .select('id')
          .eq('user_id', user.id)
          .gte('viewed_at', cutoffDate.toIso8601String());

      // Con la constraint UNIQUE, el conteo directo es el de mezclas únicas
      return (response as List).length;
    } catch (e) {
      debugPrint('Error al contar visitas únicas: $e');
      return 0;
    }
  }
}
