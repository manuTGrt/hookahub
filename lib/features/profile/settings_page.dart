import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/theme_provider.dart';

/// Página de configuración donde el usuario puede ajustar
/// las preferencias de la aplicación
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar removida: el título y navegación atrás se muestran en la barra superior global
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context, 'Apariencia'),
            const SizedBox(height: 12),
            _buildThemeSection(context),

            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Acerca de'),
            const SizedBox(height: 12),
            _buildAboutSettings(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? darkNavy : navy,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode : Icons.light_mode,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Tema de la aplicación',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                subtitle: Text(
                  isDark ? 'Modo oscuro activado' : 'Modo claro activado',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
                trailing: Switch.adaptive(
                  value: isDark,
                  activeThumbColor: Theme.of(context).primaryColor,
                  onChanged: (value) {
                    themeProvider.toggleTheme(value);
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color
                          ?.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El tema se aplicará en toda la aplicación y se guardará tu preferencia',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAboutSettings(BuildContext context) {
    return _buildSettingsCard(context, [
      _buildSettingsTile(
        context,
        icon: Icons.info_outline,
        title: 'Información de la app',
        subtitle: 'Versión 1.0.0',
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          _showAboutDialog(context);
        },
      ),
      _buildSettingsTile(
        context,
        icon: Icons.star_outline,
        title: 'Calificar la app',
        subtitle: 'Comparte tu experiencia',
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _rateApp(context),
      ),
      _buildSettingsTile(
        context,
        icon: Icons.contact_mail_outlined,
        title: 'Contáctanos',
        subtitle: 'Sugiere nuevos tabacos o reporta un error',
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _contactUs(context),
      ),
    ]);
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(
            context,
          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  void _rateApp(BuildContext context) async {
    // Cambia estos IDs por los reales de tu app cuando la publiques
    const String androidPackageName =
        'com.hookahub.app'; // Tu package name de Android
    const String iosAppId = '000000000'; // Tu App Store ID (solo números)

    Uri? storeUrl;

    if (Platform.isAndroid) {
      // Intenta abrir en Google Play Store app
      storeUrl = Uri.parse('market://details?id=$androidPackageName');

      if (!await canLaunchUrl(storeUrl)) {
        // Si no puede abrir la app, usa el navegador
        storeUrl = Uri.parse(
          'https://play.google.com/store/apps/details?id=$androidPackageName',
        );
      }
    } else if (Platform.isIOS) {
      // Abre App Store
      storeUrl = Uri.parse(
        'https://apps.apple.com/app/id$iosAppId?action=write-review',
      );
    }

    if (storeUrl != null) {
      try {
        final canLaunch = await canLaunchUrl(storeUrl);
        if (canLaunch) {
          await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo abrir la tienda de aplicaciones'),
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al abrir la tienda: $e')),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plataforma no soportada')),
        );
      }
    }
  }

  void _contactUs(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'manutgrt@gmail.com',
      queryParameters: {'subject': 'Hookahub'},
    );

    try {
      // Intentar abrir directamente el mailto (no dependemos de canLaunchUrl)
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;

      // Fallback: ofrecer opciones para instalar/usar correo
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No hay app de correo por defecto'),
            content: const Text(
              'Puedes abrir Gmail en el navegador o instalar una app de correo.',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final webCompose = Uri.parse(
                    'https://mail.google.com/mail/?view=cm&to=manutgrt@gmail.com&su=Hookahub',
                  );
                  await launchUrl(
                    webCompose,
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: const Text('Abrir Gmail Web'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  // Abrir Play Store/App Store para apps de correo
                  if (Platform.isAndroid) {
                    final market = Uri.parse('market://search?q=email');
                    if (!await launchUrl(market)) {
                      await launchUrl(
                        Uri.parse(
                          'https://play.google.com/store/search?q=email&c=apps',
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  } else if (Platform.isIOS) {
                    await launchUrl(
                      Uri.parse('https://apps.apple.com/search?term=email'),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                },
                child: const Text('Buscar app de correo'),
              ),
            ],
          ),
        );
      }

      // Último recurso: abrir Gmail web compose
      final webCompose = Uri.parse(
        'https://mail.google.com/mail/?view=cm&to=manutgrt@gmail.com&su=Hookahub',
      );
      if (await launchUrl(webCompose, mode: LaunchMode.externalApplication)) {
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir ninguna app de correo'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al abrir correo: $e')));
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Hookahub',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.local_fire_department,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        const Text('Tu comunidad de mezclas de tabaco'),
        const SizedBox(height: 16),
        const Text(
          'Desarrollado con ❤️ para los amantes de la hookah',
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
