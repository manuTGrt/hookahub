-- Migración para hacer público el bucket 'avatars'
-- Permite que los avatares se descarguen directamente por URL pública sin requerir llamadas costosas a signed URLs.
-- La seguridad se mantiene preservando que no exista política SELECT genérica sobre storage.objects (previene directory listing)
-- y las políticas de INSERT, UPDATE y DELETE continúan restringidas al propietario del directorio.

UPDATE storage.buckets
SET public = true
WHERE id = 'avatars';
