# Endpoints de Supabase para Hookahub

Este documento resume cómo descubrir y consumir los endpoints REST generados automáticamente por Supabase (PostgREST) para tu proyecto. También incluye una lista de endpoints basada en tu esquema actual y ejemplos de uso.

## 1) Dónde verlos en el panel de Supabase
- Dashboard → Project Settings → API
  - REST URL base
  - GraphQL URL (si lo usas)
  - Claves (anon, service_role)
  - Documentación y ejemplos por tabla

## 2) Descubrir los endpoints vía OpenAPI (automático)
Puedes obtener el esquema OpenAPI completo (todas las rutas) directamente desde tu instancia:

```bash
# Sustituye variables por tu proyecto
# Requiere cabeceras: apikey y Authorization si la RLS lo exige
curl -s \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Accept: application/openapi+json" \
  "$SUPABASE_URL/rest/v1/" | jq .
```

Notas:
- El header `Accept: application/openapi+json` hace que PostgREST devuelva la especificación OpenAPI 3 con todas las rutas y esquemas de modelos.
- Según tu RLS, puede que necesites un JWT de usuario en `Authorization: Bearer <jwt>` para ver recursos protegidos.

## 3) Regla general de rutas REST
Cada tabla o vista en tu esquema público expone un recurso REST en:

```
GET/POST/PATCH/DELETE  $SUPABASE_URL/rest/v1/<nombre_tabla_o_vista>
```

- Filtros: `?col=eq.valor`, `?col=ilike.*texto*`, etc.
- Proyección: `?select=campo1,campo2,relacion(*)`
- Orden: `&order=campo.asc` (o `desc`)
- Paginación: `&limit=20&offset=0`

Referencias: https://postgrest.org/en/stable/api.html

## 4) Listado de endpoints según tu esquema actual
Basado en `supabase_schema.sql`, tus tablas públicas son:

- profiles
- mixes
- mix_components
- favorites
- reviews
- notifications
- user_settings
- tobaccos
- activity_log

Para cada una, los endpoints básicos son:

### profiles
- GET    /rest/v1/profiles
- POST   /rest/v1/profiles
- PATCH  /rest/v1/profiles
- DELETE /rest/v1/profiles

Ejemplo (obtener mi perfil):
```bash
curl -s \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $JWT_USUARIO" \
  "$SUPABASE_URL/rest/v1/profiles?id=eq.$USER_ID&select=*"
```

### mixes
- GET    /rest/v1/mixes
- POST   /rest/v1/mixes
- PATCH  /rest/v1/mixes
- DELETE /rest/v1/mixes

Ejemplo (últimas 10 mezclas):
```bash
curl -s -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $JWT_USUARIO" \
  "$SUPABASE_URL/rest/v1/mixes?select=*&order=created_at.desc&limit=10"
```

### mix_components
- GET    /rest/v1/mix_components
- POST   /rest/v1/mix_components
- PATCH  /rest/v1/mix_components
- DELETE /rest/v1/mix_components

Ejemplo (componentes de una mezcla):
```bash
curl -s -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $JWT_USUARIO" \
  "$SUPABASE_URL/rest/v1/mix_components?mix_id=eq.$MIX_ID&select=*"
```

### favorites
- GET    /rest/v1/favorites
- POST   /rest/v1/favorites
- PATCH  /rest/v1/favorites
- DELETE /rest/v1/favorites

Ejemplo (mis favoritos):
```bash
curl -s -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $JWT_USUARIO" \
  "$SUPABASE_URL/rest/v1/favorites?user_id=eq.$USER_ID&select=*"
```

### reviews
- GET    /rest/v1/reviews
- POST   /rest/v1/reviews
- PATCH  /rest/v1/reviews
- DELETE /rest/v1/reviews

### notifications
- GET    /rest/v1/notifications
- POST   /rest/v1/notifications
- PATCH  /rest/v1/notifications
- DELETE /rest/v1/notifications

### user_settings
- GET    /rest/v1/user_settings
- POST   /rest/v1/user_settings
- PATCH  /rest/v1/user_settings
- DELETE /rest/v1/user_settings

### tobaccos
- GET    /rest/v1/tobaccos
- POST   /rest/v1/tobaccos
- PATCH  /rest/v1/tobaccos
- DELETE /rest/v1/tobaccos

### activity_log
- GET    /rest/v1/activity_log
- POST   /rest/v1/activity_log
- PATCH  /rest/v1/activity_log
- DELETE /rest/v1/activity_log

## 5) RPC (funciones)
- Si creas funciones SQL en PostgreSQL y les das `SECURITY DEFINER` (según convenga), se exponen como:
```
POST $SUPABASE_URL/rest/v1/rpc/<nombre_funcion>
```
- Actualmente, tu esquema no define funciones RPC.

## 6) Realtime (suscripciones)
- Realtime usa websockets con canales por tabla/tema, no endpoints REST.
- Con supabase-flutter:
```dart
final channel = Supabase.instance.client.channel('public:mixes')
  .on(PostgresChangeEvent.insert, ChannelFilter(event: 'INSERT'), (payload, [ref]) {
    // manejar nuevas filas
  })
  .subscribe();
```

## 7) Seguridad (RLS)
- Los endpoints existen aunque tengas RLS activa, pero la respuesta dependerá de tus políticas.
- Para pruebas con cURL, usa un JWT de usuario (no la service_role) para simular el acceso real de la app.

## 8) Clientes (recomendado sobre cURL)
Con `supabase_flutter` no necesitas construir rutas REST a mano:
```dart
final supa = Supabase.instance.client;
// Listar mixes
final res = await supa.from('mixes').select().order('created_at', ascending: false).limit(10);
// Insertar favorito
await supa.from('favorites').insert({'user_id': userId, 'mix_id': mixId});
```

---

Sugerencia: si quieres, puedo añadir un comando utilitario que haga una llamada y guarde `openapi.json` del proyecto en `docs/` para tener una referencia local actualizada de tus endpoints.
