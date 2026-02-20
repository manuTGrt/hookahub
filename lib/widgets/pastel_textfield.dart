import 'package:flutter/material.dart';
// import '../core/constants.dart';

class PastelTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final Color? fillColor;
  final Color? iconColor;
  final Color? textColor;
  final Widget? suffixIcon;

  const PastelTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.fillColor,
    this.iconColor,
    this.textColor,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    // Color turquesa aún más claro para el borde
    const turquoiseDark = Color(0xFF008080);
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: textColor ?? Colors.black),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: iconColor ?? turquoiseDark),
        hintText: hintText,
        hintStyle: TextStyle(
          color: (textColor ?? Colors.black).withOpacity(0.5),
        ),
        filled: true,
        fillColor: fillColor ?? Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: turquoiseDark, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: turquoiseDark, width: 2.2),
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
          borderSide: const BorderSide(color: turquoiseDark, width: 1.5),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
