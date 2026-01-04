import 'package:flutter/foundation.dart';
import '../../../core/data/supabase_service.dart';
import '../../../core/models/notification.dart';

/// Repositorio para gestionar notificaciones desde Supabase
class NotificationsRepository {
  NotificationsRepository(this._supabase);

  final SupabaseService _supabase;

  /// Obtiene las notificaciones del usuario autenticado
  /// [limit] cantidad de notificaciones a obtener
  /// [offset] desde qué posición empezar (para paginación)
  Future<List<AppNotification>> fetchNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) {
        debugPrint('Usuario no autenticado');
        return [];
      }

      final response = await _supabase.client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener notificaciones: $e');
      return [];
    }
  }

  /// Obtiene el contador de notificaciones no leídas
  Future<int> getUnreadCount() async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) return 0;

      final response = await _supabase.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      debugPrint('Error al obtener contador de no leídas: $e');
      return 0;
    }
  }

  /// Marca una notificación como leída
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _supabase.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      return true;
    } catch (e) {
      debugPrint('Error al marcar como leída: $e');
      return false;
    }
  }

  /// Marca todas las notificaciones del usuario como leídas
  Future<bool> markAllAsRead() async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) return false;

      await _supabase.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
      
      return true;
    } catch (e) {
      debugPrint('Error al marcar todas como leídas: $e');
      return false;
    }
  }

  /// Elimina una notificación
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _supabase.client
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      return true;
    } catch (e) {
      debugPrint('Error al eliminar notificación: $e');
      return false;
    }
  }

  /// Elimina todas las notificaciones leídas del usuario
  Future<bool> deleteAllRead() async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) return false;

      await _supabase.client
          .from('notifications')
          .delete()
          .eq('user_id', user.id)
          .eq('is_read', true);
      
      return true;
    } catch (e) {
      debugPrint('Error al eliminar notificaciones leídas: $e');
      return false;
    }
  }

  /// Suscripción a notificaciones en tiempo real
  /// Retorna un Stream que emite nuevas notificaciones
  Stream<AppNotification> subscribeToNotifications() {
    final user = _supabase.client.auth.currentUser;
    if (user == null) {
      debugPrint('Usuario no autenticado para suscripción');
      return const Stream.empty();
    }

    return _supabase.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .map((data) {
          if (data.isEmpty) return <AppNotification>[];
          return data.map((json) => AppNotification.fromJson(json)).toList();
        })
        .expand((notifications) => notifications);
  }
}
