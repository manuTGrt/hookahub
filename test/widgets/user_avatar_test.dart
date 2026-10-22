import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/constants.dart';
import 'package:hookahub/widgets/user_avatar.dart';

void main() {
  group('UserAvatar Widget Tests', () {
    testWidgets('Muestra la inicial del nombre de usuario si avatarUrl es null',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              username: 'manutgrt',
              avatarUrl: null,
            ),
          ),
        ),
      );

      expect(find.text('M'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('Muestra la inicial del nombre de usuario si avatarUrl está vacío',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              username: 'alex',
              avatarUrl: '   ',
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('Muestra signo de interrogación si el username está vacío',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              username: '',
              avatarUrl: null,
            ),
          ),
        ),
      );

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('Muestra el icono correcto cuando avatarUrl es icon:<index>',
        (tester) async {
      const iconIndex = 2;
      final expectedIcon = appAvatarIcons[iconIndex];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              username: 'carlos',
              avatarUrl: 'icon:$iconIndex',
            ),
          ),
        ),
      );

      expect(find.byIcon(expectedIcon), findsOneWidget);
      expect(find.text('C'), findsNothing);
    });

    testWidgets(
        'Hace fallback a inicial si el índice de icono no es válido (fuera de rango)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              username: 'david',
              avatarUrl: 'icon:999',
            ),
          ),
        ),
      );

      expect(find.text('D'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  });
}
