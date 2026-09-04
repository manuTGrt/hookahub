import 'package:hookahub/core/utils/app_logger.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/notification.dart';
import '../../../core/providers/database_health_provider.dart';
import '../../auth/auth_provider.dart';
import '../data/notifications_repository.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class NotificationsState {
  const NotificationsState();
}

/// Estado inicial previo a cargar o tras cerrar sesión.
class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

/// Primera carga en progreso.
class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

/// Notificaciones cargadas con éxito.
class NotificationsLoaded extends NotificationsState {
  const NotificationsLoaded({
    required this.notifications,
    required this.unreadCount,
    this.isLoadingMore = false,
    this.hasMoreData = true,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoadingMore;
  final bool hasMoreData;

  NotificationsLoaded copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoadingMore,
    bool? hasMoreData,
  }) {
    return NotificationsLoaded(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreData: hasMoreData ?? this.hasMoreData,
    );
  }
}

/// Ocurrió un error al interactuar con las notificaciones.
class NotificationsError extends NotificationsState {
  const NotificationsError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Provider para gestionar el estado de las notificaciones
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider(this._repository, {AuthProvider? auth}) : _auth = auth {
    if (_repository.hasActiveUser) {
      _init();
    }
    _auth?.addSignInListener(_handleSignIn);
    _auth?.addSignOutListener(_handleSignOut);

    _reconnectedSub = DatabaseHealthProvider.instance.onReconnected.listen((_) {
      if (_repository.hasActiveUser) {
        unawaited(loadNotifications(refresh: true));
        _subscribeToRealtime();
      }
    });
  }

  final NotificationsRepository _repository;
  final AuthProvider? _auth;
  StreamSubscription<void>? _reconnectedSub;

  NotificationsState _state = const NotificationsInitial();
  StreamSubscription<AppNotification>? _realtimeSubscription;

  static const int _pageSize = 50;
  int _currentOffset = 0;

  // Getters
  NotificationsState get state => _state;
  List<AppNotification> get notifications =>
      _state is NotificationsLoaded
          ? List.unmodifiable((_state as NotificationsLoaded).notifications)
          : const [];
  int get unreadCount =>
      _state is NotificationsLoaded
          ? (_state as NotificationsLoaded).unreadCount
          : 0;
  bool get isLoading => _state is NotificationsLoading;
  bool get isLoadingMore =>
      _state is NotificationsLoaded &&
      (_state as NotificationsLoaded).isLoadingMore;
  bool get hasMoreData =>
      _state is NotificationsLoaded
          ? (_state as NotificationsLoaded).hasMoreData
          : true;
  String? get error =>
      _state is NotificationsError
          ? (_state as NotificationsError).message
          : null;
  bool get hasNotifications => notifications.isNotEmpty;

  void _handleSignIn() {
    unawaited(onUserAuthenticated());
  }

  void _handleSignOut() {
    cancelSubscriptionsAndClear();
  }

  /// Cancela suscripciones Realtime y purga los datos del usuario en memoria
  void cancelSubscriptionsAndClear() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _currentOffset = 0;
    _state = const NotificationsInitial();
    notifyListeners();
    AppLogger.info('NotificationsProvider: Suscripciones canceladas y estado purgado');
  }

  /// Inicializa la carga y suscripción cuando el usuario se autentica
  Future<void> onUserAuthenticated() async {
    await loadNotifications(refresh: true);
    _subscribeToRealtime();
  }

  /// Inicialización: cargar notificaciones y suscribirse a Realtime
  Future<void> _init() async {
    await loadNotifications();
    _subscribeToRealtime();
  }

  /// Cargar notificaciones (primera carga o refresh)
  Future<void> loadNotifications({bool refresh = false}) async {
    if (refresh) {
      _currentOffset = 0;
    }

    if (!refresh && _state is! NotificationsLoaded) {
      _state = const NotificationsLoading();
      notifyListeners();
    }

    try {
      final notifications = await _repository.fetchNotifications(
        limit: _pageSize,
        offset: 0,
      );

      final unreadCount = await _repository.getUnreadCount();
      _currentOffset = notifications.length;

      _state = NotificationsLoaded(
        notifications: notifications,
        unreadCount: unreadCount,
        hasMoreData: notifications.length >= _pageSize,
      );
    } catch (e) {
      _state = const NotificationsError('Error al cargar notificaciones');
      AppLogger.error('Error en loadNotifications: $e');
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      notifyListeners();
    }
  }

  /// Cargar más notificaciones (paginación)
  Future<void> loadMore() async {
    if (_state is! NotificationsLoaded) return;
    final current = _state as NotificationsLoaded;
    if (current.isLoadingMore || !current.hasMoreData) return;

    _state = current.copyWith(isLoadingMore: true);
    notifyListeners();

    try {
      final moreNotifications = await _repository.fetchNotifications(
        limit: _pageSize,
        offset: _currentOffset,
      );

      if (_state is NotificationsLoaded) {
        final active = _state as NotificationsLoaded;
        if (moreNotifications.isEmpty) {
          _state = active.copyWith(
            isLoadingMore: false,
            hasMoreData: false,
          );
        } else {
          _currentOffset += moreNotifications.length;
          _state = active.copyWith(
            notifications: [...active.notifications, ...moreNotifications],
            isLoadingMore: false,
            hasMoreData: moreNotifications.length >= _pageSize,
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error en loadMore: $e');
      DatabaseHealthProvider.reportFailure(e);
      if (_state is NotificationsLoaded) {
        _state = (_state as NotificationsLoaded).copyWith(isLoadingMore: false);
      }
    } finally {
      notifyListeners();
    }
  }

  /// Actualizar contador de notificaciones no leídas
  Future<void> updateUnreadCount() async {
    try {
      final unread = await _repository.getUnreadCount();
      if (_state is NotificationsLoaded) {
        _state = (_state as NotificationsLoaded).copyWith(unreadCount: unread);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Error al actualizar contador: $e');
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  /// Marcar notificación como leída
  Future<void> markAsRead(String notificationId) async {
    try {
      final success = await _repository.markAsRead(notificationId);
      if (success && _state is NotificationsLoaded) {
        final current = _state as NotificationsLoaded;
        final index = current.notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1 && !current.notifications[index].isRead) {
          final updated = List<AppNotification>.from(current.notifications);
          updated[index] = updated[index].copyWith(isRead: true);
          final newUnread = (current.unreadCount - 1).clamp(0, double.infinity).toInt();
          _state = current.copyWith(
            notifications: updated,
            unreadCount: newUnread,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      AppLogger.error('Error al marcar como leída: $e');
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  /// Marcar todas como leídas
  Future<void> markAllAsRead() async {
    try {
      final success = await _repository.markAllAsRead();
      if (success && _state is NotificationsLoaded) {
        final current = _state as NotificationsLoaded;
        final updated = current.notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
        _state = current.copyWith(
          notifications: updated,
          unreadCount: 0,
        );
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Error al marcar todas como leídas: $e');
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  /// Eliminar notificación
  Future<void> deleteNotification(String notificationId) async {
    try {
      final success = await _repository.deleteNotification(notificationId);
      if (success && _state is NotificationsLoaded) {
        final current = _state as NotificationsLoaded;
        final index = current.notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          final isUnread = !current.notifications[index].isRead;
          final updated = List<AppNotification>.from(current.notifications)
            ..removeAt(index);
          final newUnread = isUnread
              ? (current.unreadCount - 1).clamp(0, double.infinity).toInt()
              : current.unreadCount;
          _state = current.copyWith(
            notifications: updated,
            unreadCount: newUnread,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      AppLogger.error('Error al eliminar notificación: $e');
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  /// Eliminar todas las notificaciones leídas
  Future<void> deleteAllRead() async {
    try {
      final success = await _repository.deleteAllRead();
      if (success && _state is NotificationsLoaded) {
        final current = _state as NotificationsLoaded;
        final updated = current.notifications.where((n) => !n.isRead).toList();
        _state = current.copyWith(notifications: updated);
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Error al eliminar notificaciones leídas: $e');
      DatabaseHealthProvider.reportFailure(e);
    }
  }

  /// Suscribirse a notificaciones en tiempo real
  void _subscribeToRealtime() {
    _realtimeSubscription?.cancel();

    _realtimeSubscription = _repository.subscribeToNotifications().listen(
      _onNewNotification,
      onError: (error) {
        final errorString = error.toString();
        if (errorString.contains('RealtimeSubscribeException') || 
            errorString.contains('RealtimeCloseEvent') ||
            errorString.contains('InvalidJWTToken')) {
          AppLogger.warning('Desconexión temporal en suscripción Realtime: $errorString');
        } else {
          AppLogger.error('Error en suscripción Realtime', error: error);
        }
      },
    );
  }

  /// Callback cuando llega una nueva notificación
  void _onNewNotification(AppNotification notification) {
    if (_state is NotificationsLoaded) {
      final current = _state as NotificationsLoaded;
      final exists = current.notifications.any((n) => n.id == notification.id);
      if (!exists) {
        final updated = [notification, ...current.notifications];
        final newUnread = notification.isRead ? current.unreadCount : current.unreadCount + 1;
        _state = current.copyWith(
          notifications: updated,
          unreadCount: newUnread,
        );
        notifyListeners();
        AppLogger.info('Nueva notificación recibida: ${notification.title}');
      }
    } else {
      unawaited(loadNotifications());
    }
  }

  @override
  void dispose() {
    _auth?.removeSignInListener(_handleSignIn);
    _auth?.removeSignOutListener(_handleSignOut);
    _realtimeSubscription?.cancel();
    _reconnectedSub?.cancel();
    super.dispose();
  }
}
