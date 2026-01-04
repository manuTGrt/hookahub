import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/providers/database_health_provider.dart';
import '../../auth/auth_provider.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({required ProfileRepository repository, required AuthProvider auth})
      : _repo = repository,
        _auth = auth {
    _reconnectedSub = DatabaseHealthProvider.instance.onReconnected.listen((_) {
      // La navegación principal decide refrescar el tab visible
      unawaited(load());
    });
  }

  final ProfileRepository _repo;
  final AuthProvider _auth;
  StreamSubscription<void>? _reconnectedSub;

  Profile? _profile;
  bool _loading = false;
  String? _error;
  String? _signedAvatarUrl;
  int _mixesCount = 0;
  bool _hasLoadedOnce = false;

  Profile? get profile => _profile;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _auth.isAuthenticated;
  String? get signedAvatarUrl => _signedAvatarUrl;
  int get mixesCount => _mixesCount;
  bool get isLoaded => _hasLoadedOnce;

  Future<void> load() async {
    if (!_auth.isAuthenticated) {
      _profile = null;
      _error = 'No autenticado';
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
  _profile = await _repo.getCurrentUserProfile();
  _signedAvatarUrl = await _repo.createSignedAvatarUrl(_profile?.avatarUrl);
      _mixesCount = await _repo.countCurrentUserMixes();
      DatabaseHealthProvider.reportSuccess();
    } catch (e) {
      _error = 'Error cargando perfil';
      DatabaseHealthProvider.reportFailure(e);
    } finally {
      _loading = false;
      _hasLoadedOnce = true;
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
      _signedAvatarUrl = await _repo.createSignedAvatarUrl(path);
      // Evita notificar inmediatamente durante un build en curso; deja que la UI consulte luego
      _profile = await _repo.getCurrentUserProfile();
      notifyListeners();
      return null;
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return e.toString();
    }
  }

  Future<String?> clearAvatar() async {
    if (!isAuthenticated) return 'No autenticado';
    try {
      await _repo.clearAvatarForCurrentUser();
      _signedAvatarUrl = null;
      _profile = await _repo.getCurrentUserProfile();
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
      _signedAvatarUrl = null; // no imagen remota
      _profile = await _repo.getCurrentUserProfile();
      notifyListeners();
      return null;
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return 'No se pudo establecer el avatar';
    }
  }

  @override
  void dispose() {
    _reconnectedSub?.cancel();
    super.dispose();
  }
}
