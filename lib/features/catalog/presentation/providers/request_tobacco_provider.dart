import 'package:flutter/material.dart';

import '../../../../core/data/supabase_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/tobacco_repository.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class RequestTobaccoState {}

/// Estado inicial: formulario vacío, listo para rellenar.
class RequestTobaccoInitial extends RequestTobaccoState {}

/// La solicitud se está enviando a Supabase.
class RequestTobaccoLoading extends RequestTobaccoState {}

/// La solicitud se guardó correctamente en la BD.
class RequestTobaccoSuccess extends RequestTobaccoState {}

/// Ocurrió un error durante el envío.
class RequestTobaccoError extends RequestTobaccoState {
  RequestTobaccoError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class RequestTobaccoProvider extends ChangeNotifier {
  RequestTobaccoProvider(this._repository);

  final TobaccoRepository _repository;

  RequestTobaccoState _state = RequestTobaccoInitial();
  RequestTobaccoState get state => _state;

  /// Envía la solicitud de tabaco a Supabase.
  /// Retorna `true` si fue exitoso, `false` en caso contrario.
  Future<bool> submit({
    required String brand,
    required String name,
    String? description,
    String? flavors,
  }) async {
    // Obtener usuario autenticado
    final currentUser = SupabaseService().client.auth.currentUser;
    if (currentUser == null) {
      _state = RequestTobaccoError(
        'Debes iniciar sesión para enviar una solicitud.',
      );
      notifyListeners();
      return false;
    }

    _state = RequestTobaccoLoading();
    notifyListeners();

    try {
      await _repository.submitTobaccoRequest(
        userId: currentUser.id,
        brand: brand.trim(),
        name: name.trim(),
        description: description?.trim(),
        flavors: flavors?.trim(),
      );

      _state = RequestTobaccoSuccess();
      notifyListeners();
      return true;
    } catch (e, stack) {
      AppLogger.error(
        'Error enviando solicitud de tabaco',
        error: e,
        stackTrace: stack,
      );
      _state = RequestTobaccoError(
        'No se pudo enviar la solicitud. Inténtalo de nuevo.',
      );
      notifyListeners();
      return false;
    }
  }

  /// Resetea el estado al inicial (útil si el usuario quiere reenviar).
  void reset() {
    _state = RequestTobaccoInitial();
    notifyListeners();
  }
}
