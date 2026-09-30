import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/providers/database_health_provider.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class ProfileState {
  const ProfileState();
}

/// Estado inicial previo a la carga o tras cerrar sesión.
class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

/// Carga del perfil en progreso.
class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

/// Perfil cargado con éxito.
class ProfileLoaded extends ProfileState {
  const ProfileLoaded({
    required this.profile,
    required this.mixesCount,
    this.signedAvatarUrl,
  });

  final Profile? profile;
  final int mixesCount;
  final String? signedAvatarUrl;

  ProfileLoaded copyWith({
    Profile? profile,
    int? mixesCount,
    String? signedAvatarUrl,
  }) {
    return ProfileLoaded(
      profile: profile ?? this.profile,
      mixesCount: mixesCount ?? this.mixesCount,
      signedAvatarUrl: signedAvatarUrl ?? this.signedAvatarUrl,
    );
  }
}

/// Ocurrió un error al cargar o actualizar el perfil.
class ProfileError extends ProfileState {
  const ProfileError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({
    required ProfileRepository repository,
    required AuthProvider auth,
  }) : _repo = repository,
       _auth = auth {
    _auth.addSignOutListener(clear);
    _reconnectedSub = DatabaseHealthProvider.instance.onReconnected.listen((_) {
      // La navegación principal decide refrescar el tab visible
      unawaited(load());
    });
  }

  final ProfileRepository _repo;
  final AuthProvider _auth;
  StreamSubscription<void>? _reconnectedSub;

  // Estado sellado (única fuente de verdad)
  ProfileState _state = const ProfileInitial();

  ProfileState get state => _state;

  /// Limpia los datos de perfil en memoria al cerrar sesión
  void clear() {
    _state = const ProfileInitial();
    notifyListeners();
  }

  // Getters derivados para compatibilidad y consumo simplificado
  Profile? get profile =>
      _state is ProfileLoaded ? (_state as ProfileLoaded).profile : null;
  bool get isLoading => _state is ProfileLoading;
  String? get error =>
      _state is ProfileError ? (_state as ProfileError).message : null;
  bool get isAuthenticated => _auth.isAuthenticated;
  String? get signedAvatarUrl =>
      _state is ProfileLoaded ? (_state as ProfileLoaded).signedAvatarUrl : null;
  int get mixesCount =>
      _state is ProfileLoaded ? (_state as ProfileLoaded).mixesCount : 0;
  bool get isLoaded => _state is ProfileLoaded;

  Future<void> load() async {
    if (!_auth.isAuthenticated) {
      _state = const ProfileError('No autenticado');
      notifyListeners();
      return;
    }
    _state = const ProfileLoading();
    notifyListeners();
    try {
      // Lanzar las consultas de base de datos simultáneamente
      final results = await Future.wait([
        _repo.getCurrentUserProfile(),
        _repo.countCurrentUserMixes(),
      ]);

      final profile = results[0] as Profile?;
      final mixesCount = results[1] as int;

      // Obtener la URL firmada depende de la carga previa del perfil
      final signedAvatarUrl =
          await _repo.createSignedAvatarUrl(profile?.avatarUrl);

      _state = ProfileLoaded(
        profile: profile,
        mixesCount: mixesCount,
        signedAvatarUrl: signedAvatarUrl,
      );

      DatabaseHealthProvider.reportSuccess();
    } catch (e) {
      _state = const ProfileError('Error cargando perfil');
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      notifyListeners();
    }
  }

  Future<String?> save(ProfileUpdate update) async {
    if (!_auth.isAuthenticated) return 'No autenticado';
    try {
      await _repo.updateCurrentUser(update);
      await load();
      return null;
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return 'Error guardando cambios';
    }
  }

  Future<String?> uploadAvatar(String filePath) async {
    if (!isAuthenticated) return 'No autenticado';
    try {
      final path = await _repo.uploadAvatarAndSave(filePath);
      final signedAvatarUrl = await _repo.createSignedAvatarUrl(path);
      final updatedProfile = await _repo.getCurrentUserProfile();

      final currentLoaded =
          _state is ProfileLoaded ? (_state as ProfileLoaded) : null;
      _state = ProfileLoaded(
        profile: updatedProfile,
        mixesCount: currentLoaded?.mixesCount ?? 0,
        signedAvatarUrl: signedAvatarUrl,
      );
      notifyListeners();
      return null;
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return AppErrorMapper.toSpanish(e);
    }
  }

  Future<String?> clearAvatar() async {
    if (!isAuthenticated) return 'No autenticado';
    try {
      await _repo.clearAvatarForCurrentUser();
      final updatedProfile = await _repo.getCurrentUserProfile();
      final currentLoaded =
          _state is ProfileLoaded ? (_state as ProfileLoaded) : null;
      _state = ProfileLoaded(
        profile: updatedProfile,
        mixesCount: currentLoaded?.mixesCount ?? 0,
        signedAvatarUrl: null,
      );
      notifyListeners();
      return null;
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return 'No se pudo quitar el avatar';
    }
  }

  Future<String?> setAvatarIcon(int index) async {
    if (!isAuthenticated) return 'No autenticado';
    try {
      await _repo.setAvatarIcon(index);
      final updatedProfile = await _repo.getCurrentUserProfile();
      final currentLoaded =
          _state is ProfileLoaded ? (_state as ProfileLoaded) : null;
      _state = ProfileLoaded(
        profile: updatedProfile,
        mixesCount: currentLoaded?.mixesCount ?? 0,
        signedAvatarUrl: null, // no imagen remota
      );
      notifyListeners();
      return null;
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return 'No se pudo establecer el avatar';
    }
  }

  @override
  void dispose() {
    _auth.removeSignOutListener(clear);
    _reconnectedSub?.cancel();
    super.dispose();
  }
}
