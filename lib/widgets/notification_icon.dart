import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/notifications/presentation/notifications_provider.dart';
import '../features/notifications/presentation/notifications_page.dart';

/// Icono de notificaciones con badge de contador
class NotificationIcon extends StatelessWidget {
  const NotificationIcon({super.key, this.isDark = false});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationsProvider>(
      builder: (context, provider, _) {
        return Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_outlined,
                color: isDark ? Theme.of(context).primaryColor : Colors.white,
                size: 26,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NotificationsPage(),
                  ),
                );
              },
            ),
            if (provider.unreadCount > 0)
              Positioned(
                right: 11,
                top: 11,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Theme.of(context).scaffoldBackgroundColor
                          : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
