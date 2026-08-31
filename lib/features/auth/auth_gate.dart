import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import '../onboarding/presentation/onboarding_provider.dart';
import '../onboarding/presentation/onboarding_page.dart';
import '../../widgets/main_navigation.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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
                    if (auth.isAuthenticated) {
                      return const MainNavigationPage();
                    }
                    return const LoginPage();
                  },
                ),
        );
      },
    );
  }
}

