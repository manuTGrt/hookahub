import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme_provider.dart';
import '../../widgets/pastel_textfield.dart';
import '../../widgets/main_navigation.dart';
import 'package:hookahub/features/auth/auth_provider.dart';
import 'presentation/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final bool isDark = themeProvider.isDarkMode;
        
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0, top: 8.0),
                child: Row(
                  children: [
                    Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode, 
                      color: Theme.of(context).primaryColor,
                    ),
                    Switch.adaptive(
                      value: isDark,
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (val) {
                        themeProvider.toggleTheme(val);
                      },
                    ),
                  ],
                ),
              ),
            ],
            automaticallyImplyLeading: false,
          ),
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Hookahub',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.18),
                            blurRadius: 6,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tu comunidad de mezclas de tabaco',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 40),
                    PastelTextField(
                      controller: _emailController,
                      hintText: 'Correo electrónico',
                      icon: Icons.email_outlined,
                      fillColor: isDark ? fieldDark : fieldLight,
                      iconColor: Theme.of(context).primaryColor,
                      textColor: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                    ),
                    const SizedBox(height: 20),
                    PastelTextField(
                      controller: _passwordController,
                      hintText: 'Contraseña',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      fillColor: isDark ? fieldDark : fieldLight,
                      iconColor: Theme.of(context).primaryColor,
                      textColor: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Theme.of(context).primaryColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          final auth = context.read<AuthProvider>();
                          final email = _emailController.text.trim();
                          final password = _passwordController.text;
                          final error = await auth.signInEmail(email, password);
                          if (!mounted) return;
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error)),
                            );
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const MainNavigationPage()),
                            );
                          }
                        },
                        child: const Text('Iniciar sesión'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final auth = context.read<AuthProvider>();
                              final error = await auth.signInGoogle();
                              if (!mounted) return;
                              if (error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                              }
                            },
                            icon: const Icon(Icons.g_mobiledata),
                            label: const Text('Google'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final auth = context.read<AuthProvider>();
                              final error = await auth.signInFacebook();
                              if (!mounted) return;
                              if (error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                              }
                            },
                            icon: const Icon(Icons.facebook),
                            label: const Text('Facebook'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
                        );
                      },
                      child: const Text('¿No tienes cuenta? Regístrate'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        textStyle: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
