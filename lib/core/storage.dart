class StorageConfig {
  // Cambia este nombre si tu bucket de Supabase tiene otro distinto
  static const String avatarsBucket = 'avatars';
  static const String tobaccoImagesBucket = 'tobacco-images';

  // Marca si el bucket es privado (true) o público (false)
  static const bool avatarsPrivate = true;
  static const bool tobaccoImagesPrivate = false; // Público para mejor rendimiento

  // Segundos de validez para URLs firmadas
  static const int signedUrlExpiresIn = 3600; // 1 hora
}
