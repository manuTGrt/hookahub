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
