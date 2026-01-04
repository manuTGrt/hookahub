import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña actual es obligatoria';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La nueva contraseña es obligatoria';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
      return 'La contraseña debe contener al menos una mayúscula, una minúscula y un número';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu nueva contraseña';
    }
    if (value != _newPasswordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Simular cambio de contraseña
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contraseña cambiada exitosamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar contraseña: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const borderTurquoise = turquoiseDark;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: TextStyle(
        color: isDark ? darkNavy : navy,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(
          Icons.lock_outline,
          color: borderTurquoise,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: isDark ? darkNavy.withOpacity(0.6) : navy.withOpacity(0.6),
          ),
          onPressed: onToggleVisibility,
        ),
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDark ? darkNavy.withOpacity(0.6) : navy.withOpacity(0.5),
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
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      // AppBar removida: el título y navegación atrás se muestran en la barra superior global
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Information card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark 
                    ? darkTurquoise.withOpacity(0.1) 
                    : turquoise.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? darkTurquoise.withOpacity(0.3) : turquoise.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: isDark ? darkTurquoise : turquoise,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tu nueva contraseña debe tener al menos 8 caracteres e incluir una mayúscula, una minúscula y un número.',
                        style: TextStyle(
                          color: isDark ? darkNavy.withOpacity(0.8) : navy.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Current password
              Text(
                'Contraseña actual',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: _currentPasswordController,
                hintText: 'Introduce tu contraseña actual',
                obscureText: _obscureCurrentPassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscureCurrentPassword = !_obscureCurrentPassword;
                  });
                },
                validator: _validateCurrentPassword,
              ),
              
              const SizedBox(height: 24),
              
              // New password
              Text(
                'Nueva contraseña',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: _newPasswordController,
                hintText: 'Introduce tu nueva contraseña',
                obscureText: _obscureNewPassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscureNewPassword = !_obscureNewPassword;
                  });
                },
                validator: _validateNewPassword,
              ),
              
              const SizedBox(height: 24),
              
              // Confirm password
              Text(
                'Confirmar nueva contraseña',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: _confirmPasswordController,
                hintText: 'Confirma tu nueva contraseña',
                obscureText: _obscureConfirmPassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
                validator: _validateConfirmPassword,
              ),
              
              const SizedBox(height: 48),
              
              // Change password button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
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
                        'Cambiar contraseña',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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