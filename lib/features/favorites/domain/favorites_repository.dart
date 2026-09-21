import '../../../core/models/mix.dart';

/// Contrato formal de dominio para la persistencia y gestión de favoritos
abstract class FavoritesRepository {
  Future<List<Mix>> loadFavorites();
  Future<void> saveFavorites(List<Mix> mixes);
  Future<List<String>> loadTop5Ids();
  Future<void> saveTop5Ids(List<String> ids);
}
