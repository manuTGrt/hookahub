import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'notifications_provider.dart';
import '../../../core/models/notification.dart';
import '../../../core/constants.dart';
import '../../../core/utils/app_toast.dart';
import 'adapters/notification_presentation_adapter.dart';
import 'handlers/notification_action_handler.dart';

/// Página completa de notificaciones
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Configurar locale para timeago
    timeago.setLocaleMessages('es', timeago.EsMessages());
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      // Cargar más cuando llegue al 90% del scroll
      context.read<NotificationsProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: isDark ? darkBg : Colors.white,
        foregroundColor: isDark ? darkNavy : navy,
        elevation: 0,
        actions: [
          // Marcar todas como leídas
          Consumer<NotificationsProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();

              return IconButton(
                icon: const Icon(Icons.done_all),
                tooltip: 'Marcar todas como leídas',
                onPressed: () async {
                  await provider.markAllAsRead();
                  if (context.mounted) {
                    AppToast.showInfo(context, 'Todas las notificaciones marcadas como leídas',);
                  }
                },
              );
            },
          ),

          // Eliminar todas las leídas
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete_read') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Eliminar notificaciones'),
                    content: const Text(
                      '¿Eliminar todas las notificaciones leídas?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  await context.read<NotificationsProvider>().deleteAllRead();
                  if (context.mounted) {
                    AppToast.showInfo(context, 'Notificaciones eliminadas');
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete_read',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 20),
                    SizedBox(width: 8),
                    Text('Eliminar leídas'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, provider, _) {
          return switch (provider.state) {
            NotificationsInitial() || NotificationsLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            NotificationsError(:final message) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: isDark
                            ? darkNavy.withValues(alpha: 0.5)
                            : navy.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar notificaciones',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? darkNavy.withValues(alpha: 0.7)
                              : navy.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () =>
                            provider.loadNotifications(refresh: true),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            NotificationsLoaded(:final notifications) when notifications.isEmpty =>
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 80,
                      color: isDark
                          ? darkNavy.withValues(alpha: 0.5)
                          : navy.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes notificaciones',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Te notificaremos cuando haya actividad',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? darkNavy.withValues(alpha: 0.7)
                            : navy.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            NotificationsLoaded() => RefreshIndicator(
                onRefresh: () => provider.loadNotifications(refresh: true),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      provider.notifications.length +
                      (provider.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == provider.notifications.length) {
                      // Loading indicator al final
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final notification = provider.notifications[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: NotificationTile(
                        notification: notification,
                        isDark: isDark,
                        onTap: () => NotificationActionHandler.handleTap(
                          context,
                          notification,
                        ),
                        onDismiss: () =>
                            provider.deleteNotification(notification.id),
                      ),
                    );
                  },
                ),
              ),
          };
        },
      ),
    );
  }
}

/// Widget para cada notificación individual
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.isDark,
    required this.onTap,
    required this.onDismiss,
  });

  final AppNotification notification;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final uiModel = NotificationPresentationAdapter.adapt(context, notification);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDismiss(),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? fieldDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead
                ? (isDark ? darkNavy.withValues(alpha: 0.2) : navy.withValues(alpha: 0.1))
                : (isDark
                      ? darkTurquoise.withValues(alpha: 0.4)
                      : turquoise.withValues(alpha: 0.3)),
            width: notification.isRead ? 1 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : navy).withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icono temático de la notificación
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: uiModel.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      uiModel.icon,
                      color: uiModel.accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Contenido enriquecido
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: uiModel.accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                uiModel.categoryBadge,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                  color: uiModel.accentColor,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (!notification.isRead) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isDark ? darkTurquoise : turquoise,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          uiModel.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: notification.isRead
                                    ? FontWeight.w600
                                    : FontWeight.bold,
                                color: isDark ? darkNavy : navy,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          uiModel.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? darkNavy.withValues(alpha: 0.8)
                                    : navy.withValues(alpha: 0.7),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: isDark
                                  ? darkNavy.withValues(alpha: 0.6)
                                  : navy.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeago.format(
                                notification.createdAt,
                                locale: 'es',
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: isDark
                                        ? darkNavy.withValues(alpha: 0.6)
                                        : navy.withValues(alpha: 0.5),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
