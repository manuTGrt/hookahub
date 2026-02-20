import 'package:flutter/material.dart';

/// Representa una entrada en el historial de mezclas visitadas.
/// Contiene la información necesaria para mostrar la mezcla visitada
/// junto con el timestamp de la visita.
class VisitEntry {
  /// ID único de la entrada en el historial
  final String id;

  /// ID de la mezcla visitada
  final String mixId;

  /// Nombre de la mezcla
  final String mixName;

  /// Autor de la mezcla
  final String author;

  /// Fecha y hora de la visita
  final DateTime visitedAt;

  /// Color representativo de la mezcla (del primer componente)
  final Color mixColor;

  /// Calificación de la mezcla
  final double rating;

  /// Número de reseñas
  final int reviews;

  /// Ingredientes de la mezcla
  final List<String> ingredients;

  const VisitEntry({
    required this.id,
    required this.mixId,
    required this.mixName,
    required this.author,
    required this.visitedAt,
    required this.mixColor,
    required this.rating,
    required this.reviews,
    required this.ingredients,
  });

  /// Crea una instancia desde un mapa (respuesta de Supabase)
  factory VisitEntry.fromMap(Map<String, dynamic> map) {
    try {
      debugPrint('🔍 VisitEntry.fromMap recibió: $map');

      // Extraer datos de la mezcla
      final mixData = map['mixes'] as Map<String, dynamic>?;

      // Si la mezcla fue eliminada, retornar entrada con datos mínimos
      if (mixData == null || mixData.isEmpty) {
        debugPrint('⚠️ Mezcla eliminada o sin datos: ${map['mix_id']}');
        return VisitEntry(
          id: map['id'] as String,
          mixId: map['mix_id'] as String,
          mixName: 'Mezcla eliminada',
          author: 'Desconocido',
          visitedAt: DateTime.parse(map['viewed_at'] as String),
          mixColor: const Color(0xFF72C8C1),
          rating: 0.0,
          reviews: 0,
          ingredients: [],
        );
      }

      // Extraer componentes para obtener color e ingredientes
      final components = mixData['mix_components'] as List? ?? [];
      final ingredients = components
          .map((c) => c['tobacco_name'] as String)
          .toList();

      // Determinar color (del primer componente o por defecto)
      Color mixColor = const Color(0xFF72C8C1); // turquoise por defecto
      if (components.isNotEmpty && components[0]['color'] != null) {
        final colorStr = components[0]['color'] as String;
        if (colorStr.startsWith('#') && colorStr.length == 7) {
          mixColor = Color(
            int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
          );
        }
      }

      // Extraer autor
      final profile = mixData['profiles'];
      final authorName = profile != null
          ? (profile['username'] as String? ?? 'Anónimo')
          : 'Anónimo';

      final entry = VisitEntry(
        id: map['id'] as String,
        mixId: map['mix_id'] as String,
        mixName: mixData['name'] as String? ?? 'Mezcla sin nombre',
        author: authorName,
        visitedAt: DateTime.parse(map['viewed_at'] as String),
        mixColor: mixColor,
        rating: (mixData['rating'] as num?)?.toDouble() ?? 0.0,
        reviews: (mixData['reviews'] as num?)?.toInt() ?? 0,
        ingredients: ingredients,
      );

      debugPrint('✅ VisitEntry creada: ${entry.mixName}');
      return entry;
    } catch (e, stackTrace) {
      debugPrint('❌ Error en VisitEntry.fromMap: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Data recibida: $map');
      rethrow;
    }
  }

  /// Convierte la entrada a un mapa
  Map<String, dynamic> toMap() => {
    'id': id,
    'mix_id': mixId,
    'mix_name': mixName,
    'author': author,
    'viewed_at': visitedAt.toIso8601String(),
    'mix_color': mixColor.value,
    'rating': rating,
    'reviews': reviews,
    'ingredients': ingredients,
  };
}
