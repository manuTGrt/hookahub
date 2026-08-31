import 'package:flutter/material.dart';

/// Representa el contenido inmutable de una pantalla de Onboarding.
class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;
  final String badgeText;
  final List<String> highlights;

  const OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.badgeText,
    this.highlights = const [],
  });
}
