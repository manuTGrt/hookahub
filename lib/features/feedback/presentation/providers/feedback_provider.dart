import 'package:flutter/material.dart';

import '../../../../core/data/supabase_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/feedback_repository.dart';
import '../../domain/feedback_category.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class FeedbackState {}

/// Estado inicial: formulario listo para rellenar.
class FeedbackInitial extends FeedbackState {}

/// El reporte o mensaje se está enviando a Supabase.
class FeedbackLoading extends FeedbackState {}

/// El mensaje se guardó correctamente en Supabase.
class FeedbackSuccess extends FeedbackState {}

/// Ocurrió un error durante el envío.
class FeedbackError extends FeedbackState {
  FeedbackError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class FeedbackProvider extends ChangeNotifier {
  FeedbackProvider(this._repository);

  final FeedbackRepository _repository;

  FeedbackState _state = FeedbackInitial();
  FeedbackState get state => _state;

  /// Envía el reporte o sugerencia a Supabase.
  /// Retorna `true` si fue exitoso, `false` en caso contrario.
  Future<bool> submit({
    required FeedbackCategory category,
    required String subject,
    required String message,
    String? platform,
    String? appVersion,
  }) async {
    // Validar usuario autenticado
    final currentUser = SupabaseService().client.auth.currentUser;
    if (currentUser == null) {
      _state = FeedbackError(
        'Debes iniciar sesión para enviar un mensaje de contacto.',
      );
      notifyListeners();
      return false;
    }

    _state = FeedbackLoading();
    notifyListeners();

    try {
      await _repository.submitFeedback(
        userId: currentUser.id,
        category: category,
        subject: subject.trim(),
        message: message.trim(),
        platform: platform,
        appVersion: appVersion,
      );

      _state = FeedbackSuccess();
      notifyListeners();
      return true;
    } catch (e, stack) {
      AppLogger.error(
        'Error enviando mensaje de feedback',
        error: e,
        stackTrace: stack,
      );
      _state = FeedbackError(
        'No se pudo enviar el mensaje. Inténtalo de nuevo más tarde.',
      );
      notifyListeners();
      return false;
    }
  }

  /// Resetea el estado al inicial para reintentar tras un error.
  void reset() {
    _state = FeedbackInitial();
    notifyListeners();
  }
}
