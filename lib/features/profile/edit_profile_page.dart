import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import 'change_password_page.dart';
import 'presentation/profile_provider.dart';
import 'domain/profile.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'dart:io' show Platform;
import 'package:image_cropper/image_cropper.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  
  DateTime? _selectedBirthDate;
  String _selectedAvatarType = 'avatar'; // 'avatar' o 'photo'
  int _selectedAvatarIndex = 0;
  bool _hasChanges = false;
  bool _isLoading = false;
  bool _settingInitialValues = false;
  bool _initialLoading = true; // Nuevo: indica si estamos cargando los datos iniciales

  // Lista de avatares predefinidos
  final List<IconData> _avatarIcons = [
    Icons.person,
    Icons.account_circle,
    Icons.face,
    Icons.sentiment_satisfied,
    Icons.mood,
    Icons.emoji_emotions,
    Icons.psychology,
    Icons.elderly,
  ];

  @override
  void initState() {
    super.initState();
    // Cargar datos reales desde Supabase
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ProfileProvider>();
      await provider.load();
      final p = provider.profile;
      if (p != null && mounted) {
        _populateFromProfile(p);
      }
      // Finalizar la carga inicial
      if (mounted) {
        setState(() {
          _initialLoading = false;
        });
      }
    });
    
    // Listeners para detectar cambios
    _usernameController.addListener(_onDataChanged);
    _firstNameController.addListener(_onDataChanged);
    _lastNameController.addListener(_onDataChanged);
    _emailController.addListener(_onDataChanged);
  }

  void _populateFromProfile(Profile p) {
    _settingInitialValues = true;
    _usernameController.text = p.username;
    _firstNameController.text = p.firstName;
    _lastNameController.text = p.lastName;
    _emailController.text = p.email;
    _selectedBirthDate = p.birthdate;
    if (p.avatarUrl != null && p.avatarUrl!.startsWith('icon:')) {
      final idx = int.tryParse(p.avatarUrl!.substring(5));
      if (idx != null && idx >= 0 && idx < _avatarIcons.length) {
        _selectedAvatarIndex = idx;
      }
      _selectedAvatarType = 'avatar';
    } else if (p.avatarUrl != null && p.avatarUrl!.isNotEmpty) {
      _selectedAvatarType = 'photo';
    } else {
      _selectedAvatarType = 'avatar';
    }
    _settingInitialValues = false;
    setState(() {
      _hasChanges = false;
    });
  }

  void _onDataChanged() {
    if (_settingInitialValues) return;
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  void _onBirthDateChanged(DateTime? date) {
    setState(() {
      _selectedBirthDate = date;
      _hasChanges = true;
    });
  }

  bool _isOlderThan18(DateTime birthDate) {
    final now = DateTime.now();
    final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);
    return birthDate.isBefore(eighteenYearsAgo) || birthDate.isAtSameMomentAs(eighteenYearsAgo);
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: isDark ? darkTurquoise : turquoise,
              surface: isDark ? darkBg : Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (_isOlderThan18(picked)) {
        _onBirthDateChanged(picked);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Debes ser mayor de 18 años para usar esta aplicación'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  void _showAvatarSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAvatarSelector(),
    );
  }

  // Selección de imagen multiplataforma con fallback
  Future<String?> _pickImagePath({bool fromCamera = false}) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: fromCamera ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 90,
          maxWidth: 2048,
        );
        return picked?.path;
      } else {
        final result = await fp.FilePicker.platform.pickFiles(type: fp.FileType.image, allowMultiple: false, withData: false);
        return result?.files.single.path;
      }
    } catch (_) {
      return null;
    }
  }

  Future<bool> _chooseImageSource() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? darkBg : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Galería'),
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Cámara'),
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    return result == true;
  }

  Future<String?> _cropImage(String path) async {
    // Solo intentamos recortar en Android/iOS; en otras plataformas devolvemos la imagen tal cual.
    if (!(Platform.isAndroid || Platform.isIOS)) return path;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 88,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar foto',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: Theme.of(context).primaryColor,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Ajustar foto',
            aspectRatioLockEnabled: false,
          ),
        ],
      );
      return cropped?.path;
    } on MissingPluginException {
      // Si el plugin no está registrado (p.ej., no se reinició completamente la app), seguimos sin recortar.
      return path;
    } catch (_) {
      return path;
    }
  }

  Widget _buildAvatarSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Estado local dentro del modal para que la UI responda inmediatamente
    String localSelectedType = _selectedAvatarType;
    int localSelectedIndex = _selectedAvatarIndex;

    return StatefulBuilder(
      builder: (modalCtx, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: isDark ? darkBg : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? darkNavy.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Título
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Seleccionar foto de perfil',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? darkNavy : navy,
                  ),
                ),
              ),

              // Opciones
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Opción de avatar
                      _buildAvatarOption(
                        title: 'Elegir avatar',
                        subtitle: 'Selecciona uno de nuestros avatares',
                        isSelected: localSelectedType == 'avatar',
                        onTap: () {
                          // Solo cambia el modo de selección y despliega la rejilla.
                          setModalState(() {
                            localSelectedType = 'avatar';
                          });
                        },
                      ),

                      if (localSelectedType == 'avatar') ...[
                        const SizedBox(height: 16),
                        // Grid de avatares
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _avatarIcons.length,
                          itemBuilder: (context, index) {
                            final isSelected = localSelectedIndex == index;
                            return GestureDetector(
                              onTap: () async {
                                setModalState(() {
                                  localSelectedIndex = index;
                                });
                                final provider = context.read<ProfileProvider>();
                                setState(() => _isLoading = true);
                                final err = await provider.setAvatarIcon(index);
                                if (!mounted) return;
                                setState(() => _isLoading = false);
                                if (err != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
                                  );
                                  return;
                                }
                                // Reflejar selección en el estado padre para la cabecera
                                if (mounted) {
                                  setState(() {
                                    _selectedAvatarType = 'avatar';
                                    _selectedAvatarIndex = index;
                                  });
                                }
                                // Cerrar sheet al elegir
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? darkTurquoise : turquoise)
                                      : (isDark ? darkBg.withOpacity(0.5) : Colors.grey.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark ? darkTurquoise : turquoise)
                                        : (isDark ? darkNavy.withOpacity(0.2) : Colors.grey.withOpacity(0.3)),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  _avatarIcons[index],
                                  size: 32,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? darkNavy : navy),
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Opción de foto
                      _buildAvatarOption(
                        title: 'Usar cámara o galería',
                        subtitle: 'Toma una foto o elige de tu galería',
                        isSelected: localSelectedType == 'photo',
                        onTap: () async {
                          setModalState(() {
                            localSelectedType = 'photo';
                          });
                          // Elegir origen: cámara o galería
                          final useCamera = await _chooseImageSource();
                          try {
                            final path = await _pickImagePath(fromCamera: useCamera == true);
                            if (path == null) return;
                            // Evitar crop en cámara y en Android (algunos dispositivos pueden cerrar la app)
                            final shouldSkipCrop = useCamera == true || Platform.isAndroid;
                            final finalPath = shouldSkipCrop ? path : (await _cropImage(path) ?? path);
                            if (!mounted) return;
                            final provider = context.read<ProfileProvider>();
                            setState(() => _isLoading = true);
                            final err = await provider.uploadAvatar(finalPath);
                            if (!mounted) return;
                            setState(() => _isLoading = false);
                            if (err != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
                              );
                            } else {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Foto actualizada'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('No se pudo procesar la imagen'), behavior: SnackBarBehavior.floating),
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarOption({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
            ? (isDark ? darkTurquoise.withOpacity(0.1) : turquoise.withOpacity(0.1))
            : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
              ? (isDark ? darkTurquoise : turquoise)
              : (isDark ? darkNavy.withOpacity(0.2) : Colors.grey.withOpacity(0.3)),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected 
                ? (isDark ? darkTurquoise : turquoise)
                : (isDark ? darkNavy.withOpacity(0.6) : Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? darkNavy : navy,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? darkNavy.withOpacity(0.7) : navy.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ProfileProvider>();
    setState(() => _isLoading = true);
    final err = await provider.save(ProfileUpdate(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      birthdate: _selectedBirthDate,
      // avatarUrl: ... // pendiente cuando se implemente subida de foto
    ));
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Perfil actualizado exitosamente'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() => _hasChanges = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return AlertDialog(
          backgroundColor: isDark ? darkBg : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Eliminar cuenta',
            style: TextStyle(
              color: isDark ? darkNavy : navy,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '¿Estás seguro de que quieres eliminar tu cuenta? Esta acción no se puede deshacer y perderás todos tus datos.',
            style: TextStyle(
              color: isDark ? darkNavy.withOpacity(0.8) : navy.withOpacity(0.7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: isDark ? darkNavy.withOpacity(0.7) : navy.withOpacity(0.6),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Aquí implementarías la lógica de eliminación
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Funcionalidad de eliminación próximamente'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Eliminar',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const borderTurquoise = turquoiseDark; // Mismo color que PastelTextField
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          color: borderTurquoise,
        ),
        hintText: hintText,
        hintStyle: TextStyle(
          color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withOpacity(0.5),
        ),
        filled: true,
        fillColor: isDark ? fieldDark : fieldLight,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderTurquoise, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderTurquoise, width: 2.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2.2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderTurquoise, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const borderTurquoise = turquoiseDark; // Mismo color que PastelTextField
    
    return GestureDetector(
      onTap: _selectBirthDate,
      child: TextFormField(
        enabled: false,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.calendar_today_outlined,
            color: borderTurquoise,
          ),
          hintText: _selectedBirthDate != null
            ? '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}'
            : 'Selecciona tu fecha de nacimiento',
          hintStyle: TextStyle(
            color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black),
          ),
          filled: true,
          fillColor: isDark ? fieldDark : fieldLight,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: borderTurquoise, width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: borderTurquoise, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: borderTurquoise, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileProvider = context.watch<ProfileProvider>();
    
    return Scaffold(
      // AppBar removida: el título y navegación atrás se muestran en la barra superior global
      body: _initialLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: isDark ? darkTurquoise : turquoise,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando perfil...',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profileProvider.isLoading)
                      const LinearProgressIndicator(minHeight: 2),
              // Avatar section
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showAvatarSelector,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? darkTurquoise : turquoise,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: isDark ? darkTurquoise : turquoise,
                          backgroundImage: (profileProvider.signedAvatarUrl != null && profileProvider.signedAvatarUrl!.isNotEmpty)
                ? NetworkImage(profileProvider.signedAvatarUrl!)
                              : null,
                          child: (profileProvider.signedAvatarUrl == null || profileProvider.signedAvatarUrl!.isEmpty)
                              ? (_selectedAvatarType == 'avatar'
                                  ? Icon(
                                      _avatarIcons[_selectedAvatarIndex],
                                      size: 60,
                                      color: Colors.white,
                                    )
                                  : const Icon(
                                      Icons.photo_camera,
                                      size: 60,
                                      color: Colors.white,
                                    ))
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showAvatarSelector,
                      child: Text(
                        'Cambiar foto',
                        style: TextStyle(
                          color: isDark ? darkTurquoise : turquoise,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Username
              Text(
                'Nombre de usuario',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              _buildCustomTextField(
                controller: _usernameController,
                hintText: 'Introduce tu nombre de usuario',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El nombre de usuario es obligatorio';
                  }
                  if (value.length < 3) {
                    return 'El nombre de usuario debe tener al menos 3 caracteres';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                    return 'Solo se permiten letras, números y guiones bajos';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // First name
              Text(
                'Nombre',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              _buildCustomTextField(
                controller: _firstNameController,
                hintText: 'Introduce tu nombre',
                icon: Icons.badge_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  if (value.length < 2) {
                    return 'El nombre debe tener al menos 2 caracteres';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Last name
              Text(
                'Apellidos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              _buildCustomTextField(
                controller: _lastNameController,
                hintText: 'Introduce tus apellidos',
                icon: Icons.family_restroom_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Los apellidos son obligatorios';
                  }
                  if (value.length < 2) {
                    return 'Los apellidos deben tener al menos 2 caracteres';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Birth date
              Text(
                'Fecha de nacimiento',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              _buildDateField(),
              
              const SizedBox(height: 24),
              
              // Email
              Text(
                'Correo electrónico',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              _buildCustomTextField(
                controller: _emailController,
                hintText: 'Introduce tu correo electrónico',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El correo electrónico es obligatorio';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Introduce un correo electrónico válido';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              // Change password button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? darkTurquoise.withOpacity(0.8) : turquoise.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Cambiar contraseña',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Save changes button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _hasChanges && !_isLoading ? () => _saveChanges() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? darkTurquoise : turquoise,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Guardar cambios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Delete account button
              Center(
                child: TextButton(
                  onPressed: _showDeleteAccountDialog,
                  child: const Text(
                    'Eliminar cuenta',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}