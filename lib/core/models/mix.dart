import 'package:flutter/material.dart';

/// Modelo simple para representar una mezcla.
/// Mantiene un set mínimo de campos y soporta (de)serialización a Map.
class Mix {
  final String id; // estable para persistencia
  final String name;
  final String author;
  final double rating; // 0..5
  final int reviews; // nº reseñas (opcional, por defecto 0)
  final List<String> ingredients;
  final Color color; // usado para UI; serializado como ARGB int

  const Mix({
    required this.id,
    required this.name,
    required this.author,
    required this.rating,
    required this.ingredients,
    required this.color,
    this.reviews = 0,
  });

  Mix copyWith({
    String? id,
    String? name,
    String? author,
    double? rating,
    List<String>? ingredients,
    Color? color,
    int? reviews,
  }) {
    return Mix(
      id: id ?? this.id,
      name: name ?? this.name,
      author: author ?? this.author,
      rating: rating ?? this.rating,
      ingredients: ingredients ?? this.ingredients,
      color: color ?? this.color,
      reviews: reviews ?? this.reviews,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'author': author,
        'rating': rating,
        'ingredients': ingredients,
        'color': color.value,
    'reviews': reviews,
      };

  factory Mix.fromMap(Map<String, dynamic> map) {
    return Mix(
      id: map['id'] as String,
      name: map['name'] as String,
      author: map['author'] as String,
      rating: (map['rating'] as num).toDouble(),
      ingredients: (map['ingredients'] as List).map((e) => e.toString()).toList(),
      color: Color(map['color'] as int),
      reviews: (map['reviews'] as num?)?.toInt() ?? 0,
    );
  }
}
