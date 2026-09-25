import '../../../core/models/mix.dart';

/// Contrato formal de dominio para la persistencia y gestión de favoritos
abstract class FavoritesRepository {
  Future<List<Mix>> loadFavorites({String? userId});
  Future<void> saveFavorites(List<Mix> mixes, {String? userId});
  Future<void> addFavorite(Mix mix, {String? userId});
  Future<void> removeFavorite(String mixId, {String? userId});
  Future<List<String>> loadTop5Ids({String? userId});
  Future<void> saveTop5Ids(List<String> ids, {String? userId});
}
