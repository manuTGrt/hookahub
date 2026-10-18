import '../../../../core/models/mix.dart';
import '../../../../core/models/tobacco.dart';

/// Tipo de sugerencia de búsqueda predictiva
enum SearchSuggestionType {
  tobacco,
  mix,
}

/// Entidad inmutable que representa una sugerencia predictiva en tiempo real
class SearchSuggestion {
  final String id;
  final String title;
  final String subtitle;
  final SearchSuggestionType type;
  final double rating;
  final int reviews;
  final String? imageUrl;
  final String? brand;
  final String? author;
  final Tobacco? tobacco;
  final Mix? mix;

  const SearchSuggestion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    this.rating = 0.0,
    this.reviews = 0,
    this.imageUrl,
    this.brand,
    this.author,
    this.tobacco,
    this.mix,
  });

  bool get isTobacco => type == SearchSuggestionType.tobacco;
  bool get isMix => type == SearchSuggestionType.mix;
}
