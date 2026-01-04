import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/supabase_service.dart';
import '../domain/profile.dart';
import '../../../core/storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProfileRepository {
  ProfileRepository(this._svc);

  final SupabaseService _svc;

  SupabaseClient get _client => _svc.client;

  Future<Profile?> getCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final res = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (res == null) return null;
    return _fromMap(res);
  }

  /// Cuenta cuántas mezclas ha creado el usuario autenticado.
  Future<int> countCurrentUserMixes() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;
    try {
      final List res = await _client
          .from('mixes')
          .select('id')
          .eq('author_id', user.id);
      return res.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> updateCurrentUser(ProfileUpdate update) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No hay usuario autenticado');
    }

    final displayName = _composeDisplayName(update.firstName, update.lastName);

    final data = <String, dynamic>{
      if (update.username != null) 'username': update.username,
      if (update.email != null) 'email': update.email,
      if (displayName != null) 'display_name': displayName,
      if (update.birthdate != null) 'birthdate': update.birthdate!.toIso8601String(),
      if (update.avatarUrl != null) 'avatar_url': update.avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (data.isEmpty) return;

    await _client.from('profiles').update(data).eq('id', user.id);

    // Nota: si se requiere cambiar email del auth, hay que usar auth.updateUser
    if (update.email != null && update.email!.isNotEmpty && update.email != user.email) {
      await _client.auth.updateUser(UserAttributes(email: update.email));
    }
  }

  /// Sube una imagen al bucket 'avatars' y actualiza avatar_url en el perfil.
  /// Retorna la URL pública.
  Future<String> uploadAvatarAndSave(String filePath) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No hay usuario autenticado');

    // Nombre único por usuario + timestamp y extensión acorde
    // Convertir a JPG comprimido para compatibilidad y peso
    final tmpPath = await _compressToJpg(filePath);
    final ext = '.jpg';
    final fileName = 'avatar_current$ext';
  final storagePath = '${user.id}/$fileName';

    try {
      // Sube archivo
  await _client.storage.from(StorageConfig.avatarsBucket).upload(
            storagePath,
    File(tmpPath),
    fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
    } on StorageException catch (e) {
      throw StorageException('Error al subir a Storage: ${e.message}');
    } catch (e) {
      rethrow;
    }

    // Guarda en perfil el path (no URL). Con bucket privado usaremos Signed URLs al leer.
    try {
      await _client
          .from('profiles')
          .update({'avatar_url': storagePath, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', user.id);
    } on PostgrestException catch (e) {
      throw PostgrestException(message: 'Error al actualizar perfil: ${e.message}', code: e.code, details: e.details, hint: e.hint);
    }

    // Limpieza: eliminar avatares antiguos en la carpeta del usuario (mantener solo el recién subido)
    try {
      await _cleanupOldAvatars(userId: user.id, keepPath: storagePath);
    } catch (_) {
      // No bloquear si la limpieza falla
    }

    return storagePath;
  }

  Future<String> _compressToJpg(String inputPath) async {
    // Usa flutter_image_compress para convertir a JPG con compresión
    final dir = await getTemporaryDirectory();
    final outPath = p.join(dir.path, 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final result = await FlutterImageCompress.compressAndGetFile(
      inputPath,
      outPath,
      quality: 82, // equilibrio entre peso y calidad
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (result == null) {
      // fallback: copiar original si falla compresión
      await File(inputPath).copy(outPath);
      return outPath;
    }
    return result.path;
  }

  Future<void> _cleanupOldAvatars({required String userId, required String keepPath}) async {
    try {
      final folderPath = userId; // estamos guardando como '<uid>/<filename>'
      final files = await _client.storage
          .from(StorageConfig.avatarsBucket)
          .list(path: folderPath);
      if (files.isEmpty) return;
      final keepName = keepPath.split('/').last;
      // Mantener solo el archivo actual (avatar_current.*) y eliminar el resto
      final toRemove = files
          .where((f) => f.name != keepName)
          .map((f) => '$folderPath/${f.name}')
          .toList();
      if (toRemove.isEmpty) return;
      await _client.storage.from(StorageConfig.avatarsBucket).remove(toRemove);
    } catch (_) {
      // Ignorar errores de limpieza
    }
  }

  /// Genera una Signed URL temporal para un path dentro del bucket de avatares.
  Future<String?> createSignedAvatarUrl(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return null;
    try {
      final url = await _client.storage
          .from(StorageConfig.avatarsBucket)
          .createSignedUrl(storagePath, StorageConfig.signedUrlExpiresIn);
      return url;
    } on StorageException catch (e) {
      throw StorageException('No se pudo generar Signed URL: ${e.message}');
    }
  }

  /// Establece un avatar de icono (no imagen), persistiendo como 'icon:<index>'
  /// y elimina archivos existentes en Storage.
  Future<void> setAvatarIcon(int index) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No hay usuario autenticado');

    // Borrar ficheros previos
    try {
      final folderPath = user.id;
      final files = await _client.storage
          .from(StorageConfig.avatarsBucket)
          .list(path: folderPath);
      if (files.isNotEmpty) {
        final toRemove = files.map((f) => '$folderPath/${f.name}').toList();
        await _client.storage.from(StorageConfig.avatarsBucket).remove(toRemove);
      }
    } catch (_) {}

    // Guardar referencia de icono en DB
    await _client
        .from('profiles')
        .update({'avatar_url': 'icon:$index', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', user.id);
  }

  /// Elimina el avatar actual del usuario: borra archivos en su carpeta y pone avatar_url a NULL.
  Future<void> clearAvatarForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No hay usuario autenticado');

    // Borrar archivos en carpeta del usuario (best-effort)
    try {
      final folderPath = user.id;
      final files = await _client.storage
          .from(StorageConfig.avatarsBucket)
          .list(path: folderPath);
      if (files.isNotEmpty) {
        final toRemove = files.map((f) => '$folderPath/${f.name}').toList();
        await _client.storage.from(StorageConfig.avatarsBucket).remove(toRemove);
      }
    } catch (_) {
      // ignorar errores de borrado
    }

    // Poner avatar_url a null en profiles
    await _client
        .from('profiles')
        .update({'avatar_url': null, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', user.id);
  }

  Profile _fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      username: (map['username'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      birthdate: map['birthdate'] != null
          ? DateTime.tryParse(map['birthdate'].toString())
          : null,
    );
  }

  String? _composeDisplayName(String? first, String? last) {
    final f = (first ?? '').trim();
    final l = (last ?? '').trim();
    if (f.isEmpty && l.isEmpty) return null;
    if (f.isEmpty) return l;
    if (l.isEmpty) return f;
    return '$f $l';
  }
}
