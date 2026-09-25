import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import 'auth_provider.dart';
import '../onboarding/presentation/onboarding_provider.dart';
import '../onboarding/presentation/onboarding_page.dart';
import '../../widgets/main_navigation.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, onboarding, _) {
        if (onboarding.isLoading) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 550),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
            return Stack(
              alignment: Alignment.center,
              fit: StackFit.expand,
              children: <Widget>[
                ...previousChildren,
                ?currentChild,
              ],
            );
          },
          transitionBuilder: (Widget child, Animation<double> animation) {
            final scaleAnimation = Tween<double>(
              begin: 0.88,
              end: 1.0,
            ).animate(animation);

            final fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
          child: !onboarding.hasCompleted
              ? OnboardingPage(
                  key: const ValueKey('onboarding_page'),
                  onFinish: () {
                    // El provider se actualiza internamente y desencadena la animación
                  },
                )
              : Consumer<AuthProvider>(
                  key: const ValueKey('auth_content'),
                  builder: (context, auth, _) {
                    return _AuthSwitcher(
                      auth: auth,
                      navigatorKey: navigatorKey,
                    );
                  },
                ),
        );
      },
    );
  }
}

class _AuthSwitcher extends StatefulWidget {
  const _AuthSwitcher({
    required this.auth,
    this.navigatorKey,
  });

  final AuthProvider auth;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<_AuthSwitcher> createState() => _AuthSwitcherState();
}

class _AuthSwitcherState extends State<_AuthSwitcher> {
  @override
  void initState() {
    super.initState();
    widget.auth.addSignOutListener(_onSignOut);
  }

  @override
  void didUpdateWidget(covariant _AuthSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth != widget.auth) {
      oldWidget.auth.removeSignOutListener(_onSignOut);
      widget.auth.addSignOutListener(_onSignOut);
    }
  }

  void _onSignOut() {
    final navKey = widget.navigatorKey ?? rootNavigatorKey;
    final nav = navKey.currentState;
    if (nav != null && nav.mounted && nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    widget.auth.removeSignOutListener(_onSignOut);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final scaleAnimation = Tween<double>(
          begin: 0.94,
          end: 1.0,
        ).animate(animation);

        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
      child: widget.auth.isAuthenticated
          ? const MainNavigationPage(key: ValueKey('main_nav'))
          : const LoginPage(key: ValueKey('login_page')),
    );
  }
}

