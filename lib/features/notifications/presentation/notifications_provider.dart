import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/notification.dart';
import '../../../core/providers/database_health_provider.dart';
import '../data/notifications_repository.dart';

/// Provider para gestionar el estado de las notificaciones
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider(this._repository) {
    _init();
    _reconnectedSub = DatabaseHealthProvider.instance.onReconnected.listen((_) {
      unawaited(loadNotifications(refresh: true));
      _subscribeToRealtime();
    });
  }

  final NotificationsRepository _repository;
  StreamSubscription<void>? _reconnectedSub;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _error;

  StreamSubscription<AppNotification>? _realtimeSubscription;

  static const int _pageSize = 50;
  int _currentOffset = 0;

  // Getters
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  String? get error => _error;
  bool get hasNotifications => _notifications.isNotEmpty;

  /// Inicialización: cargar notificaciones y suscribirse a Realtime
  Future<void> _init() async {
    await loadNotifications();
    _subscribeToRealtime();
  }

  /// Cargar notificaciones (primera carga o refresh)
  Future<void> loadNotifications({bool refresh = false}) async {
    if (refresh) {
      _currentOffset = 0;
      _hasMoreData = true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final notifications = await _repository.fetchNotifications(
        limit: _pageSize,
        offset: 0,
      );

      _notifications = notifications;
      _hasMoreData = notifications.length >= _pageSize;
      _currentOffset = notifications.length;

      // Actualizar contador de no leídas
      await _updateUnreadCount();
    } catch (e) {
      _error = 'Error al cargar notificaciones';
      debugPrint('Error en loadNotifications: $e');
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar más notificaciones (paginación)
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMoreData) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final moreNotifications = await _repository.fetchNotifications(
        limit: _pageSize,
        offset: _currentOffset,
      );

      if (moreNotifications.isEmpty) {
        _hasMoreData = false;
      } else {
        _notifications.addAll(moreNotifications);
        _currentOffset += moreNotifications.length;
        _hasMoreData = moreNotifications.length >= _pageSize;
      }
    } catch (e) {
      debugPrint('Error en loadMore: $e');
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Actualizar contador de notificaciones no leídas
  Future<void> _updateUnreadCount() async {
    try {
      _unreadCount = await _repository.getUnreadCount();
      notifyListeners();
    } catch (e) {
      debugPrint('Error al actualizar contador: $e');
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  /// Marcar notificación como leída
  Future<void> markAsRead(String notificationId) async {
    try {
      final success = await _repository.markAsRead(notificationId);
      if (success) {
        // Actualizar localmente
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1 && !_notifications[index].isRead) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
          _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error al marcar como leída: $e');
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  /// Marcar todas como leídas
  Future<void> markAllAsRead() async {
    try {
      final success = await _repository.markAllAsRead();
      if (success) {
        // Actualizar localmente
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
        _unreadCount = 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error al marcar todas como leídas: $e');
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  /// Eliminar notificación
  Future<void> deleteNotification(String notificationId) async {
    try {
      final success = await _repository.deleteNotification(notificationId);
      if (success) {
        // Actualizar localmente
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          if (!_notifications[index].isRead) {
            _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
          }
          _notifications.removeAt(index);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error al eliminar notificación: $e');
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  /// Eliminar todas las notificaciones leídas
  Future<void> deleteAllRead() async {
    try {
      final success = await _repository.deleteAllRead();
      if (success) {
        _notifications.removeWhere((n) => n.isRead);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error al eliminar notificaciones leídas: $e');
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  /// Suscribirse a notificaciones en tiempo real
  void _subscribeToRealtime() {
    _realtimeSubscription?.cancel();

    _realtimeSubscription = _repository.subscribeToNotifications().listen(
      _onNewNotification,
      onError: (error) {
        debugPrint('Error en suscripción Realtime: $error');
      },
    );
  }

  /// Callback cuando llega una nueva notificación
  void _onNewNotification(AppNotification notification) {
    // Verificar si ya existe (evitar duplicados)
    final exists = _notifications.any((n) => n.id == notification.id);

    if (!exists) {
      // Insertar al inicio de la lista
      _notifications.insert(0, notification);

      // Incrementar contador si no está leída
      if (!notification.isRead) {
        _unreadCount++;
      }

      notifyListeners();

      debugPrint('Nueva notificación recibida: ${notification.title}');
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _reconnectedSub?.cancel();
    super.dispose();
  }
}
