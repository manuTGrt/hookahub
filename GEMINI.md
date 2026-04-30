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

### Rendimiento en RLS: Vulnerabilidad "Auth RLS Initialization Plan"
- **Problema**: El linter de rendimiento de Supabase reporta "Auth RLS Initialization Plan" (`auth_rls_initplan`) cuando se usan funciones de autenticación (como `auth.uid()` o `auth.role()`) directamente en políticas RLS (`USING` o `WITH CHECK`). PostgreSQL evalúa la función por cada fila, lo que destruye el rendimiento en tablas grandes.
- **Solución (Regla de Oro)**: Al definir cualquier política RLS (tanto de SELECT, INSERT, UPDATE como DELETE), siempre se debe envolver la función en una subconsulta.
  - ❌ **Incorrecto**: `USING (auth.uid() = user_id)`
  - ✅ **Correcto**: `USING ((select auth.uid()) = user_id)`
  - ❌ **Incorrecto**: `USING (auth.role() = 'authenticated')`
  - ✅ **Correcto**: `USING ((select auth.role()) = 'authenticated')`

## 📝 Logging Centralizado (AppLogger)
- **Regla Estricta**: Está **PROHIBIDO** el uso directo de `print()` y `debugPrint()` a lo largo de toda la aplicación.
- **Implementación**: Se debe utilizar siempre la clase estática `AppLogger` (ubicada en `lib/core/utils/app_logger.dart`).
- **Niveles de Log**:
  - `AppLogger.info()` / `AppLogger.debug()` / `AppLogger.warning()`: Para seguimiento de flujo y estados. No se imprimen en producción.
  - `AppLogger.error()` / `AppLogger.fatal()`: Para manejar excepciones (`catch (e, stackTrace)`). Requieren de los parámetros nombrados `error` y opcionalmente `stackTrace` (ej. `AppLogger.error("Mensaje", error: e ?? 'Error desconocido', stackTrace: stack)`). Además de imprimirse en desarrollo, envían la información remotamente a la tabla `app_logs` de Supabase.

### Falsos Positivos y Desconexiones de Realtime
- **Problema**: La tabla `app_logs` se satura rápidamente con falsos errores críticos provenientes de desconexiones temporales de **Supabase Realtime** (ej. `RealtimeSubscribeException` por expiración de token al estar la app en segundo plano, o `RealtimeCloseEvent` código 1006 al perder cobertura).
- **Solución (Filtrado)**: Las excepciones transitorias derivadas de la pérdida de socket o expiración de sesión capturadas en bloques `onError` de un `Stream` **nunca** deben enviarse mediante `AppLogger.error()`. Se debe comprobar la naturaleza del error (ej. filtrando por `RealtimeSubscribeException`, `RealtimeCloseEvent` o `InvalidJWTToken`) y, en su lugar, emitir un `AppLogger.warning()`. De esta forma, el SDK de Supabase se encarga de re-conectar automáticamente en silencio sin consumir cuota de base de datos registrando falsos errores en remoto.

## 🎨 UI/UX y Consistencia Visual

### Gestión de Resultados Múltiples (Pestañas Dinámicas)
- **Problema**: Mostrar múltiples tipos de resultados (ej. Tabacos y Mezclas) en una única lista vertical resulta confuso y requiere demasiado espacio (scroll infinito).
- **Solución (Tabs Dinámicos)**: Para pantallas que consolidan búsquedas, se debe utilizar `DefaultTabController` junto con un `TabBar`.
  - Se mostrarán las pestañas **únicamente** si hay resultados en ambas categorías (`showTabs = listaA.isNotEmpty && listaB.isNotEmpty`).
  - Si solo hay resultados de un tipo, se prescinde del `TabBar` para simplificar la interfaz.

### Reutilización de Widgets y Grids (Consistencia)
- **Problema**: Las listas de resultados a menudo utilizan `ListView` genéricos con tarjetas simplificadas, rompiendo la experiencia con pantallas dedicadas como "Catálogo" que utilizan `GridView` más visuales.
- **Solución**: Se debe mantener la **estricta consistencia visual**. Si en la aplicación principal (ej. "Catálogo") un elemento (ej. Tabaco) se muestra en un formato de cuadrícula (`GridView` con 2 columnas, priorizando la imagen y usando `SliverGridDelegateWithFixedCrossAxisCount` responsivo al `scaleFactor`), los resultados de la búsqueda de ese mismo elemento deben **clonar esa misma distribución y tarjeta de visualización**. No se debe cambiar drásticamente el layout del elemento dependiendo de la pantalla en la que se encuentre el usuario.

## 🔄 Arquitectura de Datos y Sincronización

### Estadísticas Globales en Tiempo Real (La "Bala de Plata")
- **Problema**: Realizar operaciones `COUNT(*)` sobre tablas grandes (ej. tabacos, mezclas, usuarios) cada vez que el usuario navega a "Home" o refresca la pantalla destruye el rendimiento de la base de datos y consume excesiva cuota de lectura, pero al mismo tiempo se desea mostrar las métricas completamente actualizadas al milisegundo de toda la comunidad.
- **Solución Arquitectónica**:
  1. **En Supabase (Backend)**: En lugar de contar, se delega la tarea a una tabla central (`app_statistics` con un único registro `id=1`). Se crean **Triggers de PostgreSQL** en cada tabla implicada (`tobaccos`, `mixes`, `profiles`) que, ante cualquier `INSERT` o `DELETE`, suman o restan automáticamente a la cuenta correspondiente en `app_statistics`.
  2. **En Flutter (Frontend)**: En lugar de hacer múltiples peticiones manuales o refrescos (pull-to-refresh forzados), se utiliza **Supabase Realtime** mediante `supabase.from('app_statistics').stream(...)`. El `Provider` (ej. `HomeStatsProvider`) se suscribe a este `Stream` y actualiza la interfaz reactivamente. Esto reduce el coste de red y CPU al mínimo indispensable (1 sola lectura inicial seguida de suscripción websocket a una fila estática), escalando perfectamente a millones de usuarios a la vez que proporciona una experiencia mágica y en vivo.

### Condición de Carrera en Carga de Perfil (Lazy Loading vs Warm-up)
- **Problema**: En la pestaña de Comunidad, las tarjetas de mezclas no mostraban las opciones de edición/borrado porque el `ProfileProvider` cargaba los datos del usuario de forma perezosa (*lazy loading*) solo al entrar a la pestaña de Perfil. Si se visitaba Comunidad primero, el ID de usuario era `null` y la comprobación de autoría fallaba.
- **Solución (Warm-up)**: Los datos que determinan "permisos" o "propiedad" a lo largo de toda la aplicación deben precargarse proactivamente. Se implementó una carga temprana (*warm-up*) en el `initState` del `MainNavigationPage` (usando `WidgetsBinding.instance.addPostFrameCallback`) para forzar la inicialización de `ProfileProvider` y `FavoritesProvider` al montar la navegación, asegurando que el estado sea consistente globalmente sin importar qué pestaña se visite primero.

## 🐛 Depuración y Herramientas (Tooling)

### Desconexión Repentina del Debugger de Flutter
- **Problema**: Al lanzar la aplicación en modo debug (ej. usando Antigravity o VS Code con el flag `--machine`), la aplicación arranca y es completamente usable en el dispositivo, pero el debugger se detiene de forma abrupta, deja de mostrar logs y se pierde el Hot Reload.
- **Causa Principal**: El uso de paquetes de logs (como `logger`) configurados con colores (`colors: true`). Los códigos de escape ANSI generados para pintar colores en la terminal interfieren y corrompen el flujo JSON estructurado del protocolo `--machine`. Al fallar el parseo de este JSON, la herramienta de depuración colapsa.
- **Solución (Logging)**: Asegurarse de que el logger centralizado (`AppLogger`) tenga desactivados los colores (`colors: false`) en su `Printer` base.

### Permisos de Red Local para Depuración en iOS Físico
- **Problema**: En iOS 14 y superior, si Flutter no puede conectarse al dispositivo físico mediante mDNS, la aplicación se instalará pero el depurador no podrá acoplarse y eventualmente la conexión caducará (timeout).
- **Solución**: Es mandatorio incluir en el archivo `ios/Runner/Info.plist` las políticas de uso de red local:
  ```xml
  <key>NSBonjourServices</key>
  <array>
      <string>_dartobservatory._tcp</string>
  </array>
  <key>NSLocalNetworkUsageDescription</key>
  <string>Permitir depuración de Flutter en la red local.</string>
  ```
