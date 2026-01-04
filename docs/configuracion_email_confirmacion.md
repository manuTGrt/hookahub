# Configuración de Confirmación de Email en Supabase

## Problema
El enlace de confirmación de email redirige a `localhost:3000`, que no funciona en dispositivos móviles.

## Solución Implementada

### 1. Deep Link Configurado
Ya tienes configurado el esquema `io.supabase.flutter://login-callback/` en:
- **Android**: `android/app/src/main/AndroidManifest.xml` (intent-filter)
- **iOS**: `ios/Runner/Info.plist` (CFBundleURLTypes)

### 2. Código Actualizado
- `SupabaseService.signUpWithEmail()` ahora usa `emailRedirectTo: 'io.supabase.flutter://login-callback/'`
- OAuth también redirige al mismo esquema para consistencia

## Configuración Requerida en Supabase Dashboard

### Paso 1: Configurar URLs de Redirección
Ve a tu **Supabase Dashboard** → **Authentication** → **URL Configuration**:

1. **Site URL**: `https://tu-dominio.com` (o deja la actual si es temporal)

2. **Additional Redirect URLs**: Añade estas líneas:
   ```
   io.supabase.flutter://login-callback/
   io.supabase.flutter://login-callback/**
   ```

### Paso 2: Plantilla de Email (Opcional)
En **Authentication** → **Email Templates** → **Confirm signup**:

Cambia la URL del botón de confirmación de:
```
{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=signup
```

A:
```
{{ .RedirectTo }}?token_hash={{ .TokenHash }}&type=signup
```

Esto hará que use tu deep link en lugar del Site URL.

## Cómo Funciona

1. **Usuario se registra** → Supabase envía email con link que apunta a `io.supabase.flutter://login-callback/`
2. **Usuario toca el link** → Se abre tu app automáticamente (gracias al intent-filter/URL scheme)
3. **Supabase SDK maneja** → La confirmación se procesa automáticamente
4. **AuthProvider reacciona** → Se crea el perfil y el usuario queda logueado

## Validación

Para probar que funciona:

1. Regístrate con un email nuevo
2. Ve al email de confirmación
3. Toca el enlace → Debería abrir tu app directamente
4. La app debería confirmar automáticamente y loguearte

## Alternativa (Si no funciona el deep link)

Si tienes problemas, puedes usar una página web intermedia:

1. Crea una página web simple en tu dominio: `https://tu-dominio.com/auth/confirm`
2. Esta página detecta si está en móvil y redirige a tu app
3. Configura esa URL como redirect en Supabase

¿Necesitas ayuda con alguno de estos pasos o quieres que implemente la página web intermedia?