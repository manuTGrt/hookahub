import 'package:flutter/material.dart';

/// Modelo de Tabaco
class Tobacco {
  final String id;
  final String name;
  final String brand;
  final String? description; // texto descriptivo (usado en detalles)
  final List<String> flavors;
  final double rating; // media 0..5
  final int reviews; // número de reseñas
  final String? imageUrl; // opcional
  final Color? placeholderColor; // para UI si no hay imagen

  const Tobacco({
    required this.id,
    required this.name,
    required this.brand,
    this.description,
    required this.flavors,
    this.rating = 0,
    this.reviews = 0,
    this.imageUrl,
    this.placeholderColor,
  });
}
