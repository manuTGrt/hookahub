# HookaHub - Mejores Prácticas y Soluciones (GEMINI)

Este documento recopila las soluciones arquitectónicas, problemas resueltos y reglas descubiertas durante el desarrollo de la aplicación, para que sirvan como referencia en futuras implementaciones dictadas a asistentes de inteligencia artificial.

## 🔐 Autenticación y Seguridad

### Integración Nativa de Google SignIn (google_sign_in ^7.0.0+)
Durante la migración a autenticación nativa de Google para iOS y Android junto con Supabase, se descubrieron los siguientes *Breaking Changes* y configuraciones esenciales:

1. **La API actua como Singleton:**
   - A partir de la versión 7, ya no se debe instanciar `GoogleSignIn()`. En su lugar, se utiliza el patrón `GoogleSignIn.instance`.
2. **Ciclo de inicialización estricto:**
   - Es obligatorio llamar y hacer un *await* a `GoogleSignIn.instance.initialize(serverClientId: webClientId, clientId: iosClientId)` antes de intentar iniciar sesión.
   - La recuperación del selector de cuentas se hace mediante `GoogleSignIn.instance.authenticate()`, la cual, en caso de que el usuario lo cancele, devuelve una excepción tratable `GoogleSignInException(code: GoogleSignInExceptionCode.canceled)`, en vez de devolver directamente `null`.

### Huellas SHA-1 y Flujo de Desarrollo Activo vs Producción
Para que Google reconozca adecuadamente a la aplicación en Android durante el Login y no cancele automáticamente el intento sin mostrar el selector de cuentas:
- Es imperativo tener registradas en Google Cloud Console **dos Credenciales para Android**:
  1. **Depuración (Debug)**: Generada automáticamente al probar en emulador (clave: `debug.keystore`).
  2. **Producción (Release)**: Vinculada al fichero `upload-keystore.jks` utilizado mediante `key.properties` para construir el Google Play AppBundle (`.aab`).

## 📁 Estructura y Seguridad del Repositorio
- Siempre ignorar (`.gitignore`) ficheros como `.env`, `key.properties`, y cualquier `.keystore` o `.jks` que contenga claves criptográficas o IDs críticos en texto plano.

## 🗄️ Base de Datos y Funciones (Supabase)
### Funciones con "SECURITY DEFINER" (Vulnerabilidad de Search Path)
- Al crear funciones en PostgreSQL (Supabase) que requieran privilegios elevados (`SECURITY DEFINER`), es **obligatorio** fijar el `search_path` para evitar ataques de inyección y manipulación de funciones (ej. `ALTER FUNCTION nombre_funcion() SET search_path = public;`).
- Esto mitiga la advertencia del linter de seguridad de Supabase *"Function Search Path Mutable"*.

### Storage: Vulnerabilidad "Public Bucket Allows Listing"
- **Problema**: Supabase reporta "Public Bucket Allows Listing" (o data scraping) cuando un bucket público tiene una política RLS que permite `SELECT` genérico al rol `public` sobre la tabla `storage.objects`. Esto permite que cualquier atacante consulte el endpoint `/list` de la API de Storage para obtener el árbol completo de tus archivos.
- **Solución**: Dado que los archivos de un bucket marcado como "Público" (`public: true` en `storage.buckets`) ya son accesibles de forma individual por URL (`getPublicUrl()`), **no se requiere ninguna política `SELECT`** para que las imágenes puedan descargarse. La mejor práctica de seguridad es eliminar cualquier política `SELECT` genérica en buckets públicos, bloqueando así el listado de directorios sin romper la visualización de imágenes en la aplicación.
### Tablas Públicas y Logs: Vulnerabilidad "RLS Policy Always True"
- **Problema**: Supabase reporta la advertencia "RLS Policy Always True" cuando una tabla pública (ej. `app_logs`) tiene una política RLS que permite operaciones `INSERT`, `UPDATE` o `DELETE` con `WITH CHECK (true)`. Esto permite que usuarios maliciosos inyecten datos basura de forma indiscriminada, evadiendo la seguridad a nivel de filas.
- **Solución**: Para las tablas de logs o similares que recogen datos generados por los usuarios desde la app, si solo hay usuarios registrados, se debe asignar la política de `INSERT` estrictamente al rol `authenticated`. Además, es imperativo validar en la cláusula `WITH CHECK` que el identificador del usuario que envía el registro corresponda con su propio token JWT (ej. `WITH CHECK (auth.uid() = user_id)`), garantizando que nadie pueda crear registros a nombre de otro usuario.

## 📝 Logging Centralizado (AppLogger)
- **Regla Estricta**: Está **PROHIBIDO** el uso directo de `print()` y `debugPrint()` a lo largo de toda la aplicación.
- **Implementación**: Se debe utilizar siempre la clase estática `AppLogger` (ubicada en `lib/core/utils/app_logger.dart`).
- **Niveles de Log**:
  - `AppLogger.info()` / `AppLogger.debug()` / `AppLogger.warning()`: Para seguimiento de flujo y estados. No se imprimen en producción.
  - `AppLogger.error()` / `AppLogger.fatal()`: Para manejar excepciones (`catch (e, stackTrace)`). Requieren de los parámetros nombrados `error` y opcionalmente `stackTrace` (ej. `AppLogger.error("Mensaje", error: e ?? 'Error desconocido', stackTrace: stack)`). Además de imprimirse en desarrollo, envían la información remotamente a la tabla `app_logs` de Supabase.
