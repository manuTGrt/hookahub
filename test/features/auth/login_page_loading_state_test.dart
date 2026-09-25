import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/data/supabase_service.dart';
import 'package:hookahub/core/theme_provider.dart';
import 'package:hookahub/features/auth/auth_provider.dart';
import 'package:hookahub/features/auth/login_page.dart';
import 'package:hookahub/widgets/pastel_textfield.dart';
import 'package:hookahub/widgets/social_login_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Session? get currentSession => null;
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  @override
  GoTrueClient get auth => FakeGoTrueClient();
}

class FakeAuthSupabaseService implements SupabaseService {
  @override
  SupabaseClient get client => FakeSupabaseClient();

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthProvider extends AuthProvider {
  MockAuthProvider(super.svc);

  int signInEmailCallCount = 0;
  int signInGoogleCallCount = 0;
  Completer<String?>? emailCompleter;
  Completer<String?>? googleCompleter;

  @override
  Future<String?> signInEmail(String email, String password) async {
    signInEmailCallCount++;
    if (emailCompleter != null) {
      return emailCompleter!.future;
    }
    return null;
  }

  @override
  Future<String?> signInGoogle() async {
    signInGoogleCallCount++;
    if (googleCompleter != null) {
      return googleCompleter!.future;
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthProvider mockAuth;
  late ThemeProvider themeProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final fakeSvc = FakeAuthSupabaseService();
    mockAuth = MockAuthProvider(fakeSvc);
    themeProvider = ThemeProvider();
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: const MaterialApp(
        home: LoginPage(),
      ),
    );
  }

  group('LoginPage Loading State & Anti-Spam Tests', () {
    testWidgets(
      'Email login shows loading spinner and disables buttons against spam clicks',
      (tester) async {
        mockAuth.emailCompleter = Completer<String?>();

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final loginButtonFinder = find.widgetWithText(ElevatedButton, 'Iniciar sesión');
        expect(loginButtonFinder, findsOneWidget);

        // First click
        await tester.tap(loginButtonFinder);
        await tester.pump(); // Trigger frame for setState

        // Assert: Loading indicator is shown inside ElevatedButton
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(mockAuth.signInEmailCallCount, equals(1));

        // Assert: ElevatedButton is disabled
        final elevatedBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(elevatedBtn.onPressed, isNull);

        // Assert: SocialLoginButton is disabled
        final socialBtn = tester.widget<SocialLoginButton>(find.byType(SocialLoginButton));
        expect(socialBtn.onPressed, isNull);

        // Assert: PastelTextField fields are readOnly
        final textFields = tester.widgetList<PastelTextField>(find.byType(PastelTextField));
        for (final tf in textFields) {
          expect(tf.readOnly, isTrue);
        }

        // Spam click 3 more times while request is in flight
        await tester.tap(find.byType(ElevatedButton));
        await tester.tap(find.byType(ElevatedButton));
        await tester.tap(find.byType(SocialLoginButton), warnIfMissed: false);
        await tester.pump();

        // Call count MUST remain 1
        expect(mockAuth.signInEmailCallCount, equals(1));
        expect(mockAuth.signInGoogleCallCount, equals(0));

        // Complete the request with error
        mockAuth.emailCompleter!.complete('Credenciales inválidas');
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Assert: State returns to idle, button is re-enabled and shows text
        final reenabledBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(reenabledBtn.onPressed, isNotNull);
        expect(find.text('Iniciar sesión'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'Google login activates SocialLoginButton spinner and prevents email login',
      (tester) async {
        mockAuth.googleCompleter = Completer<String?>();

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final googleButtonFinder = find.byType(SocialLoginButton);
        expect(googleButtonFinder, findsOneWidget);

        // First click on Google
        await tester.tap(googleButtonFinder, warnIfMissed: false);
        await tester.pump();

        // Assert: SocialLoginButton has isLoading: true
        final socialBtn = tester.widget<SocialLoginButton>(find.byType(SocialLoginButton));
        expect(socialBtn.isLoading, isTrue);
        expect(socialBtn.onPressed, isNull);
        expect(mockAuth.signInGoogleCallCount, equals(1));

        // Assert: Email login button is disabled
        final elevatedBtn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(elevatedBtn.onPressed, isNull);

        // Spam clicks
        await tester.tap(googleButtonFinder, warnIfMissed: false);
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        expect(mockAuth.signInGoogleCallCount, equals(1));
        expect(mockAuth.signInEmailCallCount, equals(0));

        // Complete Google login
        mockAuth.googleCompleter!.complete(null);
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Once completed, state returns to idle
        final resetSocialBtn = tester.widget<SocialLoginButton>(find.byType(SocialLoginButton));
        expect(resetSocialBtn.isLoading, isFalse);
        expect(resetSocialBtn.onPressed, isNotNull);
      },
    );
  });
}
