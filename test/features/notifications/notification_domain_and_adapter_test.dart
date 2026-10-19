import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/features/notifications/domain/entities/app_notification.dart';
import 'package:hookahub/features/notifications/domain/models/notification_payload.dart';
import 'package:hookahub/features/notifications/domain/models/notification_type.dart';
import 'package:hookahub/features/notifications/presentation/adapters/notification_presentation_adapter.dart';

void main() {
  group('NotificationType Forward-Compatibility', () {
    test('Parsea correctamente los tipos nuevos de soporte y anuncios', () {
      expect(
        NotificationType.fromString('general_announcement'),
        NotificationType.generalAnnouncement,
      );
      expect(
        NotificationType.fromString('feedback_response'),
        NotificationType.feedbackResponse,
      );
      expect(
        NotificationType.fromString('system_maintenance'),
        NotificationType.systemMaintenance,
      );
    });

    test('Fallback seguro ante tipos desconocidos o cadenas vacías sin crashear', () {
      expect(
        NotificationType.fromString('future_ai_feature_v2'),
        NotificationType.unknown,
      );
      expect(
        NotificationType.fromString(null),
        NotificationType.unknown,
      );
      expect(
        NotificationType.fromString('   '),
        NotificationType.unknown,
      );
    });
  });

  group('NotificationPayload Deserialization', () {
    test('Resuelve aliases de title y message de forma flexible', () {
      final payloadFromAliases = NotificationPayload.fromJson({
        'subject': 'Aviso de actualización',
        'body': 'Los servidores se reiniciarán a las 03:00 UTC',
        'feedback_id': 'fb-999',
        'status': 'in_progress',
      });

      expect(payloadFromAliases.title, 'Aviso de actualización');
      expect(payloadFromAliases.message, 'Los servidores se reiniciarán a las 03:00 UTC');
      expect(payloadFromAliases.feedbackId, 'fb-999');
      expect(payloadFromAliases.status, 'in_progress');
    });

    test('Maneja nulls y tipos inesperados sin excepciones', () {
      final payload = NotificationPayload.fromJson(null);
      expect(payload.title, isNull);
      expect(payload.message, isNull);
      expect(payload.mixId, isNull);
      expect(payload.raw, isEmpty);
    });
  });

  group('AppNotification Domain Entity', () {
    test('Construcción desde JSON de Supabase para general_announcement', () {
      final json = {
        'id': 'notif-announcement-1',
        'user_id': 'user-123',
        'type': 'general_announcement',
        'data': {
          'title': '¡Gran Torneo de Mezclas!',
          'message': 'Participa este fin de semana para ganar insignias exclusivas.',
        },
        'is_read': false,
        'created_at': '2026-10-19T10:00:00Z',
      };

      final notification = AppNotification.fromJson(json);

      expect(notification.id, 'notif-announcement-1');
      expect(notification.type, NotificationType.generalAnnouncement);
      expect(notification.title, '¡Gran Torneo de Mezclas!');
      expect(
        notification.message,
        'Participa este fin de semana para ganar insignias exclusivas.',
      );
      expect(notification.isRead, isFalse);
    });

    test('Ofrece fallbacks semánticos adecuados si data no especifica title ni message', () {
      final json = {
        'id': 'notif-maintenance-1',
        'user_id': 'user-123',
        'type': 'system_maintenance',
        'data': {},
        'is_read': false,
        'created_at': '2026-10-19T10:00:00Z',
      };

      final notification = AppNotification.fromJson(json);

      expect(notification.type, NotificationType.systemMaintenance);
      expect(notification.title, 'Mantenimiento del sistema');
      expect(
        notification.message,
        'Trabajos programados de mantenimiento en el sistema',
      );
    });

    test('Tipo desconocido desconocido no rompe y provee títulos amigables', () {
      final json = {
        'id': 'notif-future-1',
        'user_id': 'user-123',
        'type': 'unsupported_future_type',
        'data': {
          'content': 'Mensaje emitido por una versión futura',
        },
        'is_read': true,
        'created_at': '2026-10-19T10:00:00Z',
      };

      final notification = AppNotification.fromJson(json);

      expect(notification.type, NotificationType.unknown);
      expect(notification.title, 'Aviso de Hookahub');
      expect(notification.message, 'Mensaje emitido por una versión futura');
      expect(notification.isRead, isTrue);
    });
  });

  group('NotificationPresentationAdapter', () {
    testWidgets('Adapta correctamente estilos y badges para temas claro y oscuro',
        (tester) async {
      final notification = AppNotification(
        id: 'notif-test',
        userId: 'user-1',
        type: NotificationType.feedbackResponse,
        data: {
          'title': 'Respuesta a tu reporte de tabaco',
          'message': 'Hemos agregado la marca solicitada al catálogo.',
        },
        isRead: false,
        createdAt: DateTime.now(),
      );

      late NotificationUiModel lightModel;
      late NotificationUiModel darkModel;

      await tester.pumpWidget(
        Theme(
          data: ThemeData(brightness: Brightness.light),
          child: Builder(
            builder: (context) {
              lightModel = NotificationPresentationAdapter.adapt(context, notification);
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        Theme(
          data: ThemeData(brightness: Brightness.dark),
          child: Builder(
            builder: (context) {
              darkModel = NotificationPresentationAdapter.adapt(context, notification);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(lightModel.categoryBadge, 'SOPORTE');
      expect(lightModel.title, 'Respuesta a tu reporte de tabaco');
      expect(lightModel.icon, Icons.support_agent_rounded);

      expect(darkModel.categoryBadge, 'SOPORTE');
      expect(darkModel.title, 'Respuesta a tu reporte de tabaco');
      // Colores reactivos a Dark Mode
      expect(lightModel.accentColor != darkModel.accentColor, isTrue);
      expect(lightModel.backgroundColor != darkModel.backgroundColor, isTrue);
    });
  });
}
