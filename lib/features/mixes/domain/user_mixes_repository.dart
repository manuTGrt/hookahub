import '../../../core/models/mix.dart';

/// Contrato formal de dominio para la persistencia y consulta de mezclas del usuario
abstract class UserMixesRepository {
  Future<List<Mix>> fetchMyMixes({int limit = 20, int offset = 0});
}
