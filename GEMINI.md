# Hookahub - Mejores Prácticas y Soluciones (GEMINI)

Este documento recopila las soluciones arquitectónicas, problemas resueltos y reglas descubiertas durante el desarrollo de la aplicación, para que sirvan como referencia en futuras implementaciones dictadas a asistentes de inteligencia artificial.

## 🔐 Autenticación y Seguridad

### Integración Nativa de Google SignIn (google_sign_in ^7.0.0+)

Durante la migración a autenticación nativa de Google para iOS y Android junto con Supabase, se descubrieron los siguientes _Breaking Changes_ y configuraciones esenciales:

1. **La API actua como Singleton:**
   - A partir de la versión 7, ya no se debe instanciar `GoogleSignIn()`. En su lugar, se utiliza el patrón `GoogleSignIn.instance`.
2. **Ciclo de inicialización estricto:**
   - Es obligatorio llamar y hacer un _await_ a `GoogleSignIn.instance.initialize(serverClientId: webClientId, clientId: iosClientId)` antes de intentar iniciar sesión.
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
- Esto mitiga la advertencia del linter de seguridad de Supabase _"Function Search Path Mutable"_.

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

### Sistema de Colores Global: Formularios y Pantallas (Regla de Oro)

- **Regla Estricta**: Está **PROHIBIDO** usar colores hexadecimales hardcodeados (`Color(0xFF...)`) para los elementos de formulario o el fondo de pantallas. Siempre se deben usar las constantes centralizadas definidas en `lib/core/constants.dart`.
- **Tabla de constantes obligatorias**:

  | Elemento                       | Constante (dark)                                    | Constante (light)                  |
  | ------------------------------ | --------------------------------------------------- | ---------------------------------- |
  | `fillColor` de campos de texto | `fieldDark` → `Color(0xFF26343A)`                   | `fieldLight` → `Color(0xFFE0F7F4)` |
  | Color de labels/etiquetas      | `darkNavy` → `Color(0xFFB2DFDB)`                    | `navy` → `Color(0xFF23404A)`       |
  | Color de borde de campos       | `turquoiseDark` (siempre, en ambos temas)           | `turquoiseDark`                    |
  | Fondo del `Scaffold`           | `theme.scaffoldBackgroundColor` (siempre explícito) | `theme.scaffoldBackgroundColor`    |

- **Patrón de implementación correcto** para cualquier campo de formulario:
  ```dart
  // ✅ Correcto
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final fillColor = isDark ? fieldDark : fieldLight;
  const borderColor = turquoiseDark;
  // En el label:
  color: isDark ? darkNavy : navy,
  ```
  ```dart
  // ❌ Incorrecto
  final fillColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  final borderColor = Theme.of(context).primaryColor;
  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
  ```
- **Import requerido**: Cualquier archivo que use estas constantes debe importar `'../../../core/constants.dart'` (ajustando la ruta relativa según la profundidad del archivo).

### Patrón Completo: Formulario con Envío a Supabase (Solicitud de Tabaco)

Este patrón documenta cómo implementar correctamente una pantalla de formulario que persiste datos en una tabla de Supabase, siguiendo Clean Architecture. Sirve como referencia para cualquier funcionalidad similar (ej. formularios de reporte, solicitudes, feedback).

#### 1. Base de datos (Supabase)

- **Tabla**: `tobacco_requests` con columnas `id (uuid PK)`, `user_id (FK → auth.users)`, `brand`, `name`, `description`, `flavors` (texto plano), `status` (`pending|approved|rejected`), `created_at`.
- **RLS**: solo política `INSERT` para rol `authenticated` con `WITH CHECK ((select auth.uid()) = user_id)`. **Sin política `SELECT`** si el usuario no necesita ver historial.
- Las migraciones SQL se documentan en `supabase/migrations/` con nombre `YYYYMMDD_nombre_migracion.sql`.

#### 2. Repositorio (`data/`)

- Añadir el método al repositorio existente de la feature (ej. `TobaccoRepository`), no crear uno nuevo, salvo que el dominio sea claramente distinto.
- El método debe aceptar parámetros nombrados (`required` para campos obligatorios, opcionales para el resto) y usar `.timeout()` consistente con el resto del repositorio.
- Los campos opcionales que lleguen vacíos se deben filtrar antes del `insert` usando colecciones condicionales `if (campo != null && campo.isNotEmpty) 'col': campo`.

#### 3. Provider con estados sellados (`presentation/providers/`)

- **Regla Estricta**: nunca usar booleanos fragmentados (`isLoading`, `hasError`). Siempre usar una `sealed class` con los estados necesarios:
  ```dart
  sealed class MiFormularioState {}
  class MiFormularioInitial extends MiFormularioState {}
  class MiFormularioLoading extends MiFormularioState {}
  class MiFormularioSuccess extends MiFormularioState {}
  class MiFormularioError extends MiFormularioState {
    MiFormularioError(this.message);
    final String message;
  }
  ```
- El provider obtiene el `user_id` internamente desde `SupabaseService().client.auth.currentUser` y gestiona el caso `null` (usuario no autenticado).
- Los errores se registran siempre con `AppLogger.error('...', error: e, stackTrace: stack)`.
- Exponer un método `reset()` para volver al estado `Initial` tras un error.

#### 4. UI (`presentation/`)

- Usar `ChangeNotifierProvider` creado localmente en la pantalla raíz (patrón igual que `CreateMixPage`), no en el árbol global.
- Separar la pantalla en dos widgets: uno de "shell" que crea el provider (`StatelessWidget`) y uno interno con el formulario (`StatefulWidget`).
- **Estado Loading**: deshabilitar el botón (`onPressed: isLoading ? null : callback`) y mostrar `CircularProgressIndicator` dentro del botón con tamaño fijo (`SizedBox(height: 22, width: 22)`).
- **Estado Success**: mostrar snackbar verde + `Navigator.pop()` con un `await Future.delayed` breve (800ms) para que el usuario vea el mensaje.
- **Estado Error**: mostrar snackbar rojo con el mensaje del estado + llamar a `provider.reset()` para permitir reenvío.
- Usar `context.select<MiProvider, bool>(...)` en vez de `Consumer` completo cuando solo se necesita un único campo del estado (más eficiente).

### Reutilización de Widgets y Grids (Consistencia)

- **Problema**: Las listas de resultados a menudo utilizan `ListView` genéricos con tarjetas simplificadas, rompiendo la experiencia con pantallas dedicadas como "Catálogo" que utilizan `GridView` más visuales.
- **Solución**: Se debe mantener la **estricta consistencia visual**. Si en la aplicación principal (ej. "Catálogo") un elemento (ej. Tabaco) se muestra en un formato de cuadrícula (`GridView` con 2 columnas, priorizando la imagen y usando `SliverGridDelegateWithFixedCrossAxisCount` responsivo al `scaleFactor`), los resultados de la búsqueda de ese mismo elemento deben **clonar esa misma distribución y tarjeta de visualización**. No se debe cambiar drásticamente el layout del elemento dependiendo de la pantalla en la que se encuentre el usuario.

### Sistema de Notificaciones (Toasts)

Se ha migrado del sistema de `ScaffoldMessenger` a un sistema de notificaciones enriquecidas con `toastification`, optimizado para la estética premium de Hookahub.

1. **Implementación de `AppToast` (Custom Widget)**:
   - Se utiliza `toastification.showCustom()` para tener control total sobre el widget renderizado (`_AppToastWidget`).
   - **Regla Estética**: Queda prohibido el uso de sombras (`boxShadow`), bordes con degradados, barras laterales de acento o indicadores de arrastre (puntos). El diseño debe ser plano, limpio y con bordes sólidos.
   - **Identificación por Tipo**: La distinción entre Éxito, Error e Información se realiza mediante:
     - El color del borde sólido (procedente de `constants.dart`).
     - El icono circular tintado.
     - Un "label" de tipo en mayúsculas con el color de acento correspondiente.
2. **Gestión de Colores y Contraste**:
   - Para garantizar la legibilidad en ambos temas, se utiliza `Color.alphaBlend` para mezclar el color de acento con el fondo de superficie (`surfaceDark` o `surfaceLight`), creando un color de fondo opaco y suave que no compromete el contraste del texto.
   - **Modernización**: Se debe preferir el uso de `.withValues(alpha: X)` sobre `.withOpacity(X)` para cumplir con las directrices actuales de Flutter.

### Gestión de Temas (Claro, Oscuro, Sistema), SegmentedButton y Botón Cíclico

- **Problema**: El uso de un `Switch` binario limita la personalización a forzar claro u oscuro, impidiendo que la app se sincronice automáticamente con el brillo del sistema operativo del usuario. Además, en pantallas de Login o espacios reducidos, un selector complejo satura la interfaz, y en pantallas pequeñas o con tamaños de texto aumentados (accesibilidad), componentes horizontales como `SegmentedButton` pueden desbordar (_RenderFlex overflow_).
- **Solución Arquitectónica**:
  1. **ThemeProvider (`ThemeMode`)**: Maneja el enum nativo `ThemeMode` (`system`, `light`, `dark`), persistiendo el valor como `String` en `SharedPreferences` con retrocompatibilidad para booleanos previos.
  2. **Detección Efectiva de Brillo**: Para componentes globales (ej. `AnnotatedRegion<SystemUiOverlayStyle>` en `MaterialApp.builder`) o colores de formularios (`PastelTextField`), la evaluación del brillo debe hacerse mediante `Theme.of(context).brightness == Brightness.dark` en lugar de comparar estrictamente contra `ThemeMode.dark`, asegurando que el modo del sistema refleje el estilo visual y barra de estado correctos.
  3. **SegmentedButton Resistente a Overflows (Pantalla de Ajustes)**:
     - Configurar `showSelectedIcon: false` para evitar que el checkmark desplace o reduzca el espacio horizontal útil.
     - Envolver las etiquetas de texto en `FittedBox(fit: BoxFit.scaleDown)` con `maxLines: 1` y `overflow: TextOverflow.ellipsis` para garantizar escalabilidad limpia bajo cualquier escala de fuente.
  4. **Selector Cíclico Compacto (Pantalla de Login / Auth)**:
     - En pantallas de autenticación o con espacio reducido en el `AppBar`, sustituir switches o botones anchos por un `IconButton` que cicla ordenadamente entre los 3 modos (**Sistema ➔ Claro ➔ Oscuro ➔ Sistema**), mostrando dinámicamente el icono del estado activo (`Icons.brightness_auto`, `Icons.light_mode`, `Icons.dark_mode`).

## 🔄 Arquitectura de Datos y Sincronización

### Estadísticas Globales en Tiempo Real (La "Bala de Plata")

- **Problema**: Realizar operaciones `COUNT(*)` sobre tablas grandes (ej. tabacos, mezclas, usuarios) cada vez que el usuario navega a "Home" o refresca la pantalla destruye el rendimiento de la base de datos y consume excesiva cuota de lectura, pero al mismo tiempo se desea mostrar las métricas completamente actualizadas al milisegundo de toda la comunidad.
- **Solución Arquitectónica**:
  1. **En Supabase (Backend)**: En lugar de contar, se delega la tarea a una tabla central (`app_statistics` con un único registro `id=1`). Se crean **Triggers de PostgreSQL** en cada tabla implicada (`tobaccos`, `mixes`, `profiles`) que, ante cualquier `INSERT` o `DELETE`, suman o restan automáticamente a la cuenta correspondiente en `app_statistics`.
  2. **En Flutter (Frontend)**: En lugar de hacer múltiples peticiones manuales o refrescos (pull-to-refresh forzados), se utiliza **Supabase Realtime** mediante `supabase.from('app_statistics').stream(...)`. El `Provider` (ej. `HomeStatsProvider`) se suscribe a este `Stream` y actualiza la interfaz reactivamente. Esto reduce el coste de red y CPU al mínimo indispensable (1 sola lectura inicial seguida de suscripción websocket a una fila estática), escalando perfectamente a millones de usuarios a la vez que proporciona una experiencia mágica y en vivo.

### Condición de Carrera en Carga de Perfil (Lazy Loading vs Warm-up)

- **Problema**: En la pestaña de Comunidad, las tarjetas de mezclas no mostraban las opciones de edición/borrado porque el `ProfileProvider` cargaba los datos del usuario de forma perezosa (_lazy loading_) solo al entrar a la pestaña de Perfil. Si se visitaba Comunidad primero, el ID de usuario era `null` y la comprobación de autoría fallaba.
- **Solución (Warm-up)**: Los datos que determinan "permisos" o "propiedad" a lo largo de toda la aplicación deben precargarse proactivamente. Se implementó una carga temprana (_warm-up_) en el `initState` del `MainNavigationPage` (usando `WidgetsBinding.instance.addPostFrameCallback`) para forzar la inicialización de `ProfileProvider` y `FavoritesProvider` al montar la navegación, asegurando que el estado sea consistente globalmente sin importar qué pestaña se visite primero.

### Gestión de Suscripciones y Prevención de Fugas de Memoria (Lifecycle & dispose)

- **Problema**: Declarar métodos de ciclo de vida (`dispose`) de forma anidada dentro de métodos o bloques condicionales (en lugar de como método miembro de clase) impide que `ChangeNotifier.dispose()` sea sobrescrito. Si el provider se suscribe a Streams de singletons o servicios globales (ej. `DatabaseHealthProvider.instance.onReconnected`), la suscripción nunca se cancela, reteniendo la instancia del provider en memoria de por vida (Memory Leak) y provocando excepciones de `notifyListeners()` sobre objetos destruidos.
- **Solución (Regla de Oro)**:
  - Todo `ChangeNotifier` o `StatefulWidget` que mantenga suscripciones a `Stream`, controladores o temporizadores (`Timer`) **debe** sobrescribir explícitamente `@override void dispose()` a nivel de clase.
  - Cancelar todas las suscripciones (`_sub?.cancel()`), cerrar controladores y siempre invocar `super.dispose()` al final.

### Ciclo de Vida de Controladores en Pantallas de Auth y Listas Dinámicas (Regla de Oro)

- **Problema 1 (Pantallas de Autenticación / Formularios)**: En pantallas como `LoginPage`, los controladores instanciados en el estado (`_emailController`, `_passwordController`) retienen conexiones con el subsistema de texto del framework. Si el usuario inicia sesión y la pantalla es reemplazada (`Navigator.pushReplacement`), no implementar `dispose()` en el `State` deja estos controladores anclados en memoria, fugando recursos en cada flujo de login/logout.
- **Solución**: Todo `StatefulWidget` con `TextEditingController` o `FocusNode` locales **debe** implementar `@override void dispose()` llamando a `.dispose()` en cada instancia antes de `super.dispose()`.
- **Problema 2 (Objetos y Listas Dinámicas con Controladores)**: Cuando una vista administra colecciones dinámicas cuyos elementos encapsulan un `TextEditingController` (ej. `_SelectedIngredient.percentCtrl` en `CreateMixPage`), eliminar elementos con `removeWhere` o vaciar la colección con `clear()` deja los controladores huérfanos sin llamar a `.dispose()`.
- **Solución**:
  1. Las clases auxiliares que encapsulen un controlador deben proveer un método `dispose()` propio (respetando encapsulamiento).
  2. Al eliminar elementos de la lista (`removeWhere`), se debe ejecutar `.dispose()` sobre la instancia coincidente antes de removerla.
  3. Antes de llamar a `list.clear()`, se debe iterar sobre los elementos existentes y llamar a `.dispose()`.
  4. En el `dispose()` del widget padre, delegar la destrucción llamando a `item.dispose()` en cada elemento de la colección.

### Prohibición de ScrollController en Providers Globales (Regla de Oro)

- **Problema**: Instanciar un `ScrollController` dentro de un `ChangeNotifier`/`Provider` global (como `CatalogProvider` registrado en el `MultiProvider` raíz de `app.dart`):
  1. Rompe Clean Architecture al acoplar la capa de estado con componentes de presentación (`flutter/widgets.dart`).
  2. Genera una **fuga de memoria crítica (Memory Leak)**: al ser un provider singleton de raíz, su método `dispose()` nunca se ejecuta, reteniendo indefinidamente `ScrollPosition`, tamaños del viewport y closures.
  3. Lanza la excepción en tiempo de ejecución: `ScrollController attached to multiple scroll views` si la vista es reconstruida o transicionada antes de liberar la posición previa.
- **Solución Arquitectónica**:
  1. **La Vista Posee el Controlador**: El `ScrollController` debe pertenecer **estrictamente** al `State` de un `StatefulWidget` (ej. `_CatalogPageState`), instanciándolo en el estado y liberándolo obligatoriamente en `dispose()`.
  2. **Detección de Paginación en UI**: El listener de scroll (`_onScroll`) debe residir en la vista, invocando los métodos del provider (`context.read<T>().loadMore()`) cuando la posición alcance el umbral de carga.
  3. **Delegación Desacoplada para Acciones Externas (ej. scrollToTop)**: Si un componente externo (como la barra de navegación en `main_navigation.dart`) necesita ordenar un scroll al inicio, el provider **no debe** contener controladores. En su lugar, debe exponer un callback delegado `VoidCallback? onScrollToTopRequested`. La vista lo suscribe en `didChangeDependencies()` y lo limpia a `null` en `dispose()`.
  4. **Protección `_isDisposed` en Providers Asíncronos**: Para evitar la excepción `A <Provider> was used after being disposed` provocada por llamadas asíncronas no esperadas que resuelven tras la destrucción del provider, se debe implementar una bandera `bool _isDisposed = false` y sobrescribir `@override void notifyListeners()` para ignorar notificaciones una vez que `_isDisposed == true`.

### Cancelación de Suscripciones Realtime y Purga de Estado en Logout/Login (Regla de Oro)

- **Problema**: Los providers registrados en el `MultiProvider` raíz (`app.dart`) son singletons de larga duración que persisten incluso tras el cierre de sesión (`signOut()`). Si un provider mantiene un `StreamSubscription` a canales Realtime de Supabase (ej. `NotificationsProvider` escuchando la tabla `notifications` para el `user_id` del usuario) o datos en memoria (`UserMixesProvider`, `HistoryProvider`, `ProfileProvider`):
  1. La conexión WebSocket Realtime permanece abierta en segundo plano consumiendo ancho de banda, batería y generando reconexiones fallidas con tokens expirados.
  2. Al iniciar sesión otro usuario, se produce fuga de datos cruzada en memoria (_data leak_) hasta que se completen nuevas peticiones.
  3. Si la app arranca sin sesión, el stream retorna vacío y nunca vuelve a re-suscribirse tras el Login.
- **Solución Arquitectónica**:
  1. **AuthProvider como emisor de ciclo de vida**: `AuthProvider` expone `addSignInListener` / `removeSignInListener` y `addSignOutListener` / `removeSignOutListener`, disparándolos ante cambios en `onAuthStateChange` y en `signOut()`.
  2. **Inyección de AuthProvider**: Los providers dependientes reciben `AuthProvider? auth` en su constructor, registrando sus handlers (`auth?.addSignOutListener(clear)` o `cancelSubscriptionsAndClear()`, y `auth?.addSignInListener(onUserAuthenticated)`).
  3. **Métodos `clear()` / `cancelSubscriptionsAndClear()` obligatorios**:
     - Cancelar explícitamente `_realtimeSubscription?.cancel()` y asignarlo a `null`.
     - Purgar todas las colecciones en memoria (`_notifications = []`, `_mixes = []`, `_entries = []`, `_profile = null`).
     - Resetear indicadores (`unreadCount = 0`, `isLoaded = false`, etc.) y notificar a los listeners.
  4. **Protección en Reconexión**: Los listeners de reconexión (`DatabaseHealthProvider.instance.onReconnected`) deben condicionar cualquier `fetch` o re-suscripción a la existencia de un usuario activo (`hasActiveUser`).
  5. **Limpieza en `dispose()`**: Siempre desregistrar los listeners de `AuthProvider` en el `@override void dispose()`.

## 🧭 Navegación y Diálogos

### Gestión de Diálogos en Navegadores Anidados (Root Navigator)

- **Problema**: Al mostrar un diálogo de carga global (ej. `showDialog` que por defecto usa el `rootNavigator`) desde una pantalla anidada en un sistema de pestañas (como un `BottomNavigationBar` u otra navegación paralela), al intentar cerrarlo tras finalizar la operación con `Navigator.of(context).pop()`, la aplicación se queda bloqueada con el spinner congelado. Esto ocurre porque Flutter intenta cerrar el diálogo usando el navegador local de la pestaña activa en lugar del navegador raíz que lo originó.
- **Solución**: Siempre que se cierre programáticamente un diálogo o _bottom sheet_ global invocado desde una vista anidada, es **obligatorio** especificar explícitamente el uso del navegador raíz:
  - ❌ **Incorrecto**: `Navigator.of(context).pop();`
  - ✅ **Correcto**: `Navigator.of(context, rootNavigator: true).pop();`

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

## 📱 Sistema y Status Bar (iOS / Android)

### Visibilidad de la Barra de Estado Oculta en iOS

- **Problema**: En iOS, la barra de estado superior (hora, nivel de batería, wifi, etc.) no aparece en ninguna parte de la aplicación (la pantalla se comporta como si estuviera en modo "pantalla completa" o inmersivo).
- **Causa Principal**: La propiedad `<key>UIStatusBarHidden</key>` está configurada a `<true/>` de forma estática en el archivo `ios/Runner/Info.plist`.
- **Solución (Nativa)**: Asegurarse de que en `ios/Runner/Info.plist` la clave `UIStatusBarHidden` tenga valor `<false/>`. **Cualquier cambio en este archivo requiere detener por completo la app y recompilar desde Xcode o línea de comandos; el Hot Reload no sirve.**

### Consistencia del Color de la Barra de Estado con el Tema Activo

- **Problema**: Incluso si la barra es visible nativamente, cuando la aplicación implementa pantallas que no tienen un `AppBar` clásico (ej. layouts personalizados con `SafeArea`), el texto de la barra de estado puede tomar el color por defecto (ej. negro) y resultar ilegible si el usuario tiene activado el tema oscuro (fondo oscuro).
- **Solución (Arquitectónica Global)**:
  1. **Configuración en Tema**: Incluir siempre el bloque `appBarTheme` en `ThemeData` dentro del archivo de temas (ej. `lib/core/theme.dart`), forzando `systemOverlayStyle: SystemUiOverlayStyle.dark` en el tema claro, y `SystemUiOverlayStyle.light` en el tema oscuro.
  2. **Envoltorio en la Raíz**: Para asegurar que el color de la barra aplique en toda la app reactivamente y sobre pantallas personalizadas, es imperativo envolver el contenido del `builder` del `MaterialApp` (ej. en `lib/app.dart`) dentro de un `AnnotatedRegion<SystemUiOverlayStyle>` dinámico.

## ⚡ Rendimiento de Renderizado y Rebuilds Granulares

### Optimización en Listas y Vistas Complejas (`context.select` vs `context.watch`)

- **Problema**: En vistas complejas con listas (ej. `CommunityPage`, `FavoritesPage`, `UserMixesPage`), el uso de `context.watch<Provider>()` dentro del `itemBuilder` de un `ListView` o `SliverChildBuilderDelegate` suscribe cada elemento individual a la totalidad del estado del provider. Cuando se modifica el estado de un único elemento (ej. pulsar "favorito"), o cuando se produce un cambio en cualquier propiedad ajena del provider, **todas las tarjetas visibles en el viewport se reconstruyen por completo**, generando caída de fotogramas (_jank_) y desperdicio de CPU/GPU. Asimismo, envolver pantallas completas en un único `Consumer<T>` monolítico provoca que cambios menores (como un flag de paginación `isLoadingMore`) invaliden cabeceras y filtros estáticos.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Selectores Booleanos Granulares**: Dentro de elementos de lista o tarjetas, está **estrictamente prohibido** usar `context.watch<T>()`. Se debe utilizar `context.select<T, bool>((p) => ...)` devolviendo un valor primitivo univariante (ej. booleanos como `isFavorite` o `isOwned`). El motor de Provider solo invalidará el widget si el valor retornado por el selector cambia tras evaluar la igualdad por valor (`==`).
     - ❌ **Incorrecto**:
       ```dart
       final fav = context.watch<FavoritesProvider>();
       final isFav = fav.favorites.any((x) => x.id == mix.id);
       ```
     - ✅ **Correcto**:
       ```dart
       final isFav = context.select<FavoritesProvider, bool>(
         (fav) => fav.favorites.any((x) => x.id == mix.id),
       );
       ```
  2. **Desacoplamiento de Eventos con `context.read<T>`**:
     - Las acciones disparadas por interacción del usuario (`onTap`, `onFavoriteTap`, `onEdit`, `onDelete`) **nunca** deben depender de instancias observadas con `watch`. Se debe utilizar siempre `context.read<T>()` dentro del cuerpo de la función de callback.
  3. **Aislamiento en Widgets Dedicados**:
     - Evitar métodos de construcción imperativos como `_buildMixCard()`. Extraer cada elemento a un `StatelessWidget` dedicado (ej. `_CommunityMixItem`) para que el `BuildContext` del ítem esté estrictamente aislado del contenedor de la lista.
  4. **Descomposición de `Consumer` Monolíticos**:
     - En pantallas con scroll y cabeceras de filtros, no envolver el `Scaffold.body` en un único `Consumer`. Dividir en slivers y widgets independientes que escuchen exclusivamente su subconjunto de datos (ej. un `_CommunityFooter` suscrito únicamente a `isLoadingMore`, y una barra de filtros suscrita solo a `filterState`).
  5. **Uso Seguro de `context.select` en Listas (`widget is! SliverWithKeepAliveWidget`)**:
     - En `ListView.builder`, `ListView.separated`, `SliverList` o `GridView`, el `BuildContext` entregado directamente en `itemBuilder: (context, index)` pertenece al elemento contenedor del sliver (`SliverWithKeepAliveWidget`). Si se llama a `context.select` directamente sobre dicho `context`, Provider lanza la excepción de aserción:
       ```
       _AssertionError: Failed assertion: line 251 pos 12: 'widget is! SliverWithKeepAliveWidget'
       Tried to use context.select inside a SliverList/SliderGridView.
       ```
     - **Regla Estricta**: Para utilizar `context.select` dentro de un `itemBuilder`, es **obligatorio** extraer el contenido del elemento a un `StatelessWidget` dedicado (ej. `_SearchMixItem`, `_CommunityMixItem`, `_UserMixItem`) o envolver el retorno en un `Builder(builder: (context) { ... })` para proveer un `BuildContext` hijo aislado.

## ⚡ Manejo Seguro de Asincronía y Ciclo de Vida (`use_build_context_synchronously`)

### Async Gaps y Guardas con `context.mounted` (Regla de Oro)

- **Problema**: Cuando una operación asíncrona (`await`) se ejecuta (ej. peticiones a Supabase, `Future.delayed`, login, navegación), el hilo cede el control. Si el usuario sale de la pantalla durante ese tiempo y luego el código invoca `context` (en `Navigator`, `AppToast`, o `context.read<T>()`), Flutter lanza la excepción:
  `Unhandled Exception: Looking up a deactivated widget's ancestor is unsafe`.
  Asimismo, en Flutter 3.7+, si una función o closure recibe `BuildContext context` como argumento (o en el método `build`), comprobar únicamente `if (!mounted) return;` genera la advertencia estática `unrelated 'mounted' check`, ya que `this.mounted` pertenece a la clase `State` y no garantiza que el `BuildContext` local específico siga montado.
- **Solución Arquitectónica**:
  1. **Guarda obligatoria con `context.mounted`**: Tras cualquier `await`, siempre se debe verificar el montaje del contexto antes de consumirlo:
     ```dart
     final result = await _repository.fetchData();
     if (!context.mounted) return;
     AppToast.showSuccess(context, 'Operación exitosa');
     ```
  2. **Combinación en `StatefulWidget`**: Si tras el `await` se actualiza el estado local mediante `setState` Y además se utiliza el contexto, la guarda recomendada es:
     ```dart
     if (!mounted || !context.mounted) return;
     setState(() => _isLoading = false);
     Navigator.of(context).pop();
     ```
  3. **Callbacks en `initState` (`Future.microtask`)**: En inicializaciones diferidas, nunca se debe leer el contexto directamente sin proteger la ejecución:
     ```dart
     Future.microtask(() {
       if (!mounted) return;
       final provider = context.read<MyProvider>();
       if (!provider.isLoaded) provider.load();
     });
     ```
  4. **Defensa en Profundidad en Utilidades Globales**: Componentes utilitarios globales que reciben un `BuildContext` (ej. `AppToast._show`) deben incorporar su propia guarda defensiva (`if (!context.mounted) return;`) al inicio, evitando que errores de invocación de terceros crasheen la app.

## 🏛️ Estados de Carga y Errores en UI (Sealed Classes vs Booleans Fragmentados)

### Migración a Clases Selladas con Dart 3 (Regla de Oro)

- **Problema**: El manejo de estados mediante múltiples booleanos y variables fragmentadas (`bool _isLoading`, `bool _isLoaded`, `String? _error`) genera espacios de estados imposibles e inconsistencias en memoria:
  1. `_isLoading == true` y `_error != null`: Ambigüedad para la UI (¿mostrar spinner o mensaje de error?).
  2. Hacks de sincronización como `if (isLoading && !isLoaded)` para distinguir primera carga de recargas.
  3. Pérdida silenciosa de excepciones al limpiar listas sin emitir un estado de fallo explícito.
  4. Falta de exhaustividad en tiempo de compilación: `if-else` frágiles no advierten si se agregan nuevos estados (`Reconnecting`, `Empty`, etc.).
- **Solución Arquitectónica (Dart 3 Sealed Classes)**:
  1. **Definición Inmutable**:
     ```dart
     sealed class FeatureState {
       const FeatureState();
     }
     class FeatureInitial extends FeatureState { const FeatureInitial(); }
     class FeatureLoading extends FeatureState { const FeatureLoading(); }
     class FeatureLoaded extends FeatureState {
       const FeatureLoaded({required this.data, this.isRefreshing = false});
       final List<Item> data;
       final bool isRefreshing;
     }
     class FeatureError extends FeatureState {
       const FeatureError(this.message);
       final String message;
     }
     ```
  2. **Única Fuente de Verdad en Provider**:
     - Sustituir los booleanos privados por `FeatureState _state = const FeatureInitial();`.
     - Exponer `FeatureState get state => _state;`.
     - Mantener getters de conveniencia transitorios/delegados (`bool get isLoading => _state is FeatureLoading;`) para evitar breaking changes en widgets periféricos.
  3. **Consumo Exhaustivo en UI con Switch Expressions**:
     - Eliminar cadenas `if-else` y evaluar `provider.state` con pattern matching nativo:
     ```dart
     return switch (provider.state) {
       FeatureInitial() || FeatureLoading() => const Center(child: CircularProgressIndicator()),
       FeatureError(:final message) => _buildErrorView(context, message),
       FeatureLoaded(:final data) when data.isEmpty => _buildEmptyView(context),
       FeatureLoaded(:final data) => _buildDataView(context, data),
     };
     ```
  4. **Propagación Segura de Errores**:
     - No silenciar excepciones con `catch(e) { return []; }` dentro de sub-métodos de búsqueda o carga. Permitir que la excepción burbujee hasta el método principal del provider para registrarla en `AppLogger.error()` y transitar limpiamente a `FeatureError`.

## 🍏 Compilación en iOS y CocoaPods

### Error de "Target Integrity: The iOS deployment target is set to X, but the range of supported deployment target versions is 15.0 to..."

- **Problema**: Al compilar para un dispositivo físico o simulador en versiones modernas de Xcode (Xcode 16+), el compilador rechaza cualquier target con versión de despliegue inferior a iOS 15.0. Múltiples dependencias de CocoaPods tienen versiones mínimas heredadas (`9.0`, `12.0`, `13.0`, `14.0`), provocando el fallo del build con el error `Target Integrity (Xcode): The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to...`.
- **Solución Arquitectónica (`ios/Podfile`)**:
  1. Fijar `platform :ios, '15.0'` en la parte superior del `Podfile`.
  2. Forzar que todos los pods dependientes eleven su `IPHONEOS_DEPLOYMENT_TARGET` a mínimo `15.0` en el bloque `post_install`:
     ```ruby
     post_install do |installer|
       installer.pods_project.targets.each do |target|
         flutter_additional_ios_build_settings(target)
         target.build_configurations.each do |config|
           if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 15.0
             config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
           end
         end
       end
     end
     ```
  3. Ejecutar `pod install` dentro del directorio `ios/` para regenerar `Pods.xcodeproj` con los nuevos targets.

## 🚀 Migración y Resolución de Deprecaciones (Flutter 3.27+ & Dependencias Modernas)

### 1. Inicialización de Supabase (`publishableKey`)

- **Problema**: El parámetro `anonKey:` en `Supabase.initialize()` está marcado como `@Deprecated` en favor de `publishableKey:`.
- **Solución**: En `main.dart`, utilizar `await Supabase.initialize(url: url, publishableKey: anonKey)`. Esto sigue el estándar unificado de Supabase para clientes frontend.

### 2. Compartir Contenido con `share_plus` (v13+)

- **Problema**: La clase utilitaria estática `Share` y su método `Share.share(text)` están obsoletos.
- **Breaking Change en API v13+**: `SharePlus.instance.share` no acepta un `String` posicional simple, sino una instancia del objeto `ShareParams(text: ...)`.
- **Patrón Correcto**:

  ```dart
  // ✅ Correcto
  SharePlus.instance.share(ShareParams(text: 'Texto a compartir'));

  // ❌ Incorrecto (deprecado o error de tipos en v13+)
  Share.share('Texto a compartir');
  SharePlus.instance.share('Texto a compartir'); // Error de tipos: espera ShareParams
  ```

### 3. Serialización de Color en Flutter 3.27+ (`toARGB32`)

- **Problema**: El getter `Color.value` fue deprecado en Flutter 3.27+ para dar soporte a espacios de color Wide Gamut.
- **Solución**: Al serializar un `Color` a formato numérico entero (para base de datos o modelos JSON), utilizar `color.toARGB32()`. Para la deserialización, `Color(map['color'] as int)` sigue siendo completamente funcional y retrocompatible.

## 🏛️ Clean Architecture y Modularización por Features (Regla Estricta)

### Estructura Canónica de Tres Capas

- **Regla Estricta**: Toda funcionalidad dentro de `lib/features/<feature_name>/` debe estructurarse obligatoriamente bajo las tres capas de Clean Architecture:
  ```
  feature_name/
  ├── data/        # Data sources, repositorios de red o persistencia local (ej. SharedPreferences/Supabase)
  ├── domain/      # Contratos/interfaces abstractas (ej. FavoritesRepository), entidades puras y filtros
  └── presentation/# Páginas (UI Widgets), componentes visuales y Providers (ChangeNotifier)
  ```
- **Prohibición de Archivos en la Raíz de la Feature**: Ningún archivo `.dart` debe residir directamente en la raíz de una carpeta feature (ej. `features/favorites/favorites_page.dart` ❌). Las vistas y providers van en `presentation/`, los repositorios concretos en `data/`, y los contratos/modelos en `domain/`.
- **Inversión de Dependencias (DIP)**: Los providers en `presentation/` (ej. `FavoritesProvider`, `UserMixesProvider`) deben depender de la abstracción/interfaz definida en `domain/` (ej. `FavoritesRepository`), permitiendo desacoplamiento total y tests con mocks limpios.

## 🧠 Gestión de Memoria y Ciclo de Vida de Widgets (Memory Leaks)

### Prohibición Estricta de Instanciación de Controladores en `build()` (Regla de Oro)

- **Problema**: Instanciar controladores (`TextEditingController`, `ScrollController`, `AnimationController`, `PageController`, etc.) directamente dentro del método `build(BuildContext context)` provoca fugas de memoria críticas (*Memory Leaks*). Cada vez que la vista se reconstruye (por tecleo en cualquier campo, cambios de foco `FocusNode`, validaciones reactivas o cambios de tema), se aloja una nueva instancia en el Heap de Dart sin invocar `dispose()` sobre las anteriores. Esto acumula escuchadores nativos y genera alta presión sobre el Garbage Collector.
- **Regla Estricta**:
  1. **Declaración en el `State`**: Todo controlador debe declararse obligatoriamente como miembro del `State` de un `StatefulWidget` o gestionarse a través de un `ChangeNotifierProvider` si corresponde.
  2. **Liberación en `dispose()`**: Es **mandatorio** invocar `.dispose()` sobre cada controlador dentro del `@override void dispose()` de la clase `State`, antes de llamar a `super.dispose()`.
  3. **Actualización Reactiva de Valores**: Si el valor mostrado en el campo depende de un evento asíncrono o selector externo (como un `showDatePicker`), se debe actualizar la propiedad `.text` del controlador persistente (`_controller.text = ...`) dentro del `setState()` o callback correspondiente, en lugar de recrear el controlador.

### Optimización de Indicadores de Borde en Scroll (Aislamiento de Rebuilds con ValueNotifier)

- **Problema**: Utilizar `_controller.addListener(() => setState(() => _offset = _controller.offset))` para actualizar indicadores visuales periféricos (como degradados laterales/fades, sombras de cabecera o botones flotantes de scroll-to-top) ejecuta `setState()` en cada micro-desplazamiento de píxel a 60/120 fps. Esto fuerza la reconstrucción continua de todo el widget contenedor (`LayoutBuilder`, cálculos de dimensiones geométricas, lista/carrusel y todas las tarjetas hijas), provocando caída masiva de frames (*jank*) y consumo desmedido de CPU/batería para variables que sólo cambian de estado booleano en los límites de desplazamiento.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Prohibición de `setState()` en listeners de scroll**: No invocar jamás `setState()` dentro de un listener de `ScrollController` para renderizar efectos periféricos que dependan de umbrales discretos.
  2. **Uso de `ValueNotifier<bool>` reactivo atómico**: Utilizar notificadores primitivos (ej. `_showLeft`, `_showRight`) y mutar su valor **estrictamente cuando cambie el booleano**:
     ```dart
     final canScrollLeft = pos.pixels > 2;
     if (_showLeft.value != canScrollLeft) {
       _showLeft.value = canScrollLeft;
     }
     ```
     De este modo, se reducen los rebuilds de miles a solo 1 o 2 durante todo el recorrido del scroll.
  3. **Aislamiento de reconstrucción con `ValueListenableBuilder`**:
     - Mantener el `SingleChildScrollView` / `ListView` y sus hijos estáticos fuera del builder del notificador.
     - Envolver **únicamente** los indicadores visuales periféricos (ej. dentro de un `Positioned`) en `ValueListenableBuilder<bool>`.
     - Reutilizar la instancia gráfica pasando el `Container` o `Decoration` como argumento `child` del `ValueListenableBuilder`, evitando instanciar nuevos objetos gráficos en memoria:
     ```dart
     Positioned(
       left: 0,
       top: 0,
       bottom: 0,
       child: ValueListenableBuilder<bool>(
         valueListenable: _showLeft,
         builder: (context, show, child) {
           if (!show) return const SizedBox.shrink();
           return child!;
         },
         child: IgnorePointer(
           key: const Key('quick_access_fade_left'),
           child: Container(width: 24, decoration: ...),
         ),
       ),
     )
     ```
  4. **Ciclo de vida estricto**: Desregistrar el listener del controlador (`removeListener`) y liberar todos los `ValueNotifier` en `@override void dispose()`.

