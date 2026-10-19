import '../../../core/constants.dart';
import '../../../core/data/supabase_service.dart';
import '../domain/feedback_category.dart';

class FeedbackRepository {
  FeedbackRepository(this._svc);

  final SupabaseService _svc;

  /// Inserta un nuevo reporte o mensaje de feedback en la tabla `user_feedback`.
  Future<void> submitFeedback({
    required String userId,
    required FeedbackCategory category,
    required String subject,
    required String message,
    String? platform,
    String? appVersion,
  }) async {
    final client = _svc.client;
    await client
        .from('user_feedback')
        .insert({
          'user_id': userId,
          'category': category.value,
          'subject': subject,
          'message': message,
          if (platform != null && platform.isNotEmpty) 'platform': platform,
          if (appVersion != null && appVersion.isNotEmpty)
            'app_version': appVersion,
        })
        .timeout(supabaseWriteTimeout);
  }
}
