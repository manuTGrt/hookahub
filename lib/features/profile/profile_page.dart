import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import 'settings_page.dart';
import 'edit_profile_page.dart';
import '../favorites/favorites_page.dart';
import '../mixes/user_mixes_page.dart';
import '../auth/login_page.dart';
import 'package:hookahub/features/auth/auth_provider.dart';
import 'presentation/profile_provider.dart';
import '../favorites/favorites_provider.dart';
import '../history/history_page.dart';
import '../../widgets/main_navigation.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    // Carga diferida: se realizará al entrar en la pestaña Perfil
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
  final profileProvider = context.watch<ProfileProvider>();
  final favoritesProvider = context.watch<FavoritesProvider>();
    final profile = profileProvider.profile;
    final signedUrl = profileProvider.signedAvatarUrl;
    final hasPhoto = signedUrl != null && signedUrl.isNotEmpty;
    final iconIndex = (profile?.avatarUrl != null && profile!.avatarUrl!.startsWith('icon:'))
        ? int.tryParse(profile.avatarUrl!.substring(5))
        : null;
    final displayName = (profile?.displayName != null && profile!.displayName!.trim().isNotEmpty)
        ? profile.displayName!
        : (profile?.username ?? 'Usuario');
    
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header del perfil
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                    ? [darkTurquoise.withOpacity(0.2), darkNavy.withOpacity(0.1)]
                    : [turquoise.withOpacity(0.1), turquoiseDark.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark 
                    ? darkTurquoise.withOpacity(0.3) 
                    : turquoise.withOpacity(0.2)
                ),
              ),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: isDark ? darkTurquoise : turquoise,
                    backgroundImage: hasPhoto ? NetworkImage(signedUrl) : null,
                    child: hasPhoto
                        ? null
                        : Icon(
                            iconIndex != null && iconIndex >= 0 && iconIndex < 8
                                ? _avatarIcons[iconIndex]
                                : Icons.person,
                            size: 60,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(height: 16),
                  // Nombre del usuario
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? darkNavy : navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profileProvider.isLoading
                        ? 'Cargando perfil...'
                        : (profile != null ? '@${profile.username}' : ''),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark 
                        ? darkNavy.withOpacity(0.7) 
                        : navy.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Estadísticas del usuario
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    profileProvider.mixesCount.toString(),
                    'Mezclas',
                    Theme.of(context).primaryColor,
                    onTap: () {
                      final nav = MainNavigationPage.of(context);
                      nav?.pushInCurrentTab('Mis mezclas', const UserMixesPage());
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    favoritesProvider.favorites.length.toString(),
                    'Favoritas',
                    Theme.of(context).primaryColor,
                    onTap: () {
                      final nav = MainNavigationPage.of(context);
                      nav?.pushInCurrentTab('Favoritas', const FavoritesPage());
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Opciones del perfil
            _buildOptionsList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String number, String label, Color color, {VoidCallback? onTap}) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
    final textScaler = MediaQuery.textScalerOf(context);
    final scaleFactor = textScaler.scale(1.0);
        
        final card = Container(
          height: scaleFactor > 1.1 ? (scaleFactor > 1.4 ? 110 : 90) : 80,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                number,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? darkNavy.withOpacity(0.8)
                        : navy.withOpacity(0.7),
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );

        if (onTap == null) return card;

        return Semantics(
          button: true,
          label: '$label: $number',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: card,
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionsList(BuildContext context) {
    return Column(
      children: [
        _buildOptionTile(
          icon: Icons.person_outline,
          title: 'Editar Perfil',
          subtitle: 'Cambiar foto y datos personales',
          onTap: () {
            final nav = MainNavigationPage.of(context);
            nav?.pushInCurrentTab('Editar perfil', const EditProfilePage());
          },
        ),
        const SizedBox(height: 12),
        _buildOptionTile(
          icon: Icons.settings_outlined,
          title: 'Configuración',
          subtitle: 'Tema, notificaciones y privacidad',
          onTap: () {
            final nav = MainNavigationPage.of(context);
            nav?.pushInCurrentTab('Configuración', const SettingsPage());
          },
        ),
        const SizedBox(height: 12),
        _buildOptionTile(
          icon: Icons.history,
          title: 'Historial',
          subtitle: 'Tu actividad reciente',
          onTap: () {
            final nav = MainNavigationPage.of(context);
            nav?.pushInCurrentTab('Historial', const HistoryPage());
          },
        ),
        const SizedBox(height: 12),
        

        Container(
          margin: const EdgeInsets.symmetric(vertical: 16.0),
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Theme.of(context).dividerColor.withOpacity(0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),

        Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Center(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
                            Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95)
                          ]
                        : [
                            Theme.of(context).primaryColor,
                            Theme.of(context).colorScheme.secondary
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: isDark
                      ? Border.all(
                          color: Theme.of(context).primaryColor.withOpacity(0.3),
                          width: 1,
                        )
                      : null,
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final auth = context.read<AuthProvider>();
                      try {
                        await auth.signOut();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Error al cerrar sesión')),
                          );
                        }
                        return;
                      }
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                      child: Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: isDark
                              ? Theme.of(context).primaryColor
                              : Colors.white,
                          shadows: null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        // Colores pastel para el botón destructivo
        final Color destructiveIconColor = isDark 
            ? const Color(0xFFFF9999) // Rojo pastel más claro para modo oscuro
            : const Color(0xFFE57373); // Rojo pastel para modo claro
        
        final Color destructiveTextColor = isDark 
            ? const Color(0xFFFFB3B3) // Rojo pastel muy claro para modo oscuro
            : const Color(0xFFE57373); // Rojo pastel para modo claro
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isDestructive 
              ? Colors.transparent // Sin fondo para el botón destructivo
              : (isDark ? darkBg.withOpacity(0.3) : Colors.grey.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(12),
            border: isDestructive 
              ? null // Sin borde para el botón destructivo
              : Border.all(
                  color: isDark ? darkTurquoise.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                ),
          ),
          child: ListTile(
            leading: Icon(
              icon,
              color: isDestructive 
                ? destructiveIconColor
                : (isDark ? darkTurquoise : turquoise),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDestructive 
                  ? destructiveTextColor
                  : (isDark ? darkNavy : navy),
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                color: isDark 
                  ? darkNavy.withOpacity(0.7) 
                  : navy.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            trailing: isDestructive 
              ? null // Sin flecha para el botón destructivo
              : Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDark ? darkNavy.withOpacity(0.6) : Colors.grey,
                ),
            onTap: onTap,
          ),
        );
      },
    );
  }
}

// Conjunto de iconos posibles para avatares por icono
const List<IconData> _avatarIcons = [
  Icons.person,
  Icons.account_circle,
  Icons.face,
  Icons.sentiment_satisfied,
  Icons.mood,
  Icons.emoji_emotions,
  Icons.psychology,
  Icons.elderly,
];