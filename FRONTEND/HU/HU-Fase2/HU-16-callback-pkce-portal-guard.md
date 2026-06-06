# HU-16 — Login: Callback PKCE Paso 2 + Guard de Rutas (Portal)

---

## Historia de Usuario

**Yo como** usuario que acaba de autenticarse en `app-login`,
**Quiero** que el Portal complete el intercambio PKCE al recibir el redirect y establezca mi sesión automáticamente,
**Para** acceder a las funcionalidades del portal según mi rol sin ninguna acción adicional de mi parte.

**Yo como** desarrollador del Shell,
**Quiero** un guard de rutas que verifique si hay sesión activa antes de permitir el acceso a cualquier ruta del portal,
**Para** que los usuarios no autenticados sean redirigidos a `app-login` automáticamente y los autenticados no puedan volver a `/auth/callback`.

---

## Contexto técnico

Este es el **Paso 2 del flujo PKCE cross-app**. El Portal recibe el `code` y el `sessionId` desde `app-login` vía redirect. Ms-auth tiene el `code_verifier` almacenado en Redis bajo esa clave `sessionId`, por lo que el Portal no necesita enviarlo.

```
Portal (/auth/callback?code=ABC&sid=UUID)      ms-auth (:3000 via Kong)

1. Extrae code y sid de query params
2. POST /api/auth/security/callback
   { code: "ABC",
     sessionId: "UUID",
     typeDevice: "WEB" }
                                         ms-auth recupera Redis[UUID] = verifier
                                         Valida PKCE internamente
                                         ← Set-Cookie: auth.session; auth.refresh
                                         ← { data: { ... user info ... } }

3. GET /api/core/usuario/profile
   (con la cookie auth.session recién seteada)
   ← { data: { rol, ... } }

4. SessionService.setSession(user, null)

5. Redirigir a /publicador o /ofertador según rol
```

---

## Criterios de Aceptación

### CA-01 · Ruta `/auth/callback` en el Shell

- La ruta `/auth/callback` debe existir en `app.routes.ts` del Shell.
- No debe cargar ningún MFE remoto — es una ruta local del Shell.
- No renderiza layout (no muestra navbar lateral ni top-bar). Solo un spinner centrado mientras procesa.
- Si se accede sin parámetros `code` o `sid` válidos: redirigir inmediatamente a la URL de `app-login`.

```ts
{ path: 'auth/callback', component: AuthCallbackComponent, canActivate: [noAuthGuard] }
```

### CA-02 · `AuthCallbackComponent` — lógica de intercambio

El componente debe ejecutar en `ngOnInit` (o en el `resolver`):

1. Leer `code` y `sid` de `ActivatedRoute.queryParams`.
2. Si alguno está ausente o vacío → redirect a `app-login`.
3. Llamar a `POST /api/auth/security/callback` con `{ code, sessionId: sid, typeDevice: "WEB" }`.
4. Si la respuesta es exitosa:
   a. Las cookies `auth.session` y `auth.refresh` ya están seteadas por el navegador (ms-auth las emite con `Set-Cookie`).
   b. Llamar a `GET /api/core/usuario/profile` para obtener el perfil y rol del usuario.
   c. Llamar a `SessionService.setSession(user, null)`.
   d. Redirigir según rol (tabla en CA-04).
5. Si la respuesta falla (código inválido, expirado, ya usado):
   - Mostrar error breve: `"El enlace de acceso ha expirado. Inicia sesión nuevamente."`.
   - Después de 3 segundos, redirigir a `app-login`.

### CA-03 · `authGuard` — protege todas las rutas autenticadas

Aplicado a todas las rutas del Shell excepto `/auth/callback`:

```ts
export const authGuard: CanActivateFn = () => {
  const session = inject(SessionService);
  const router  = inject(Router);

  if (session.isAuthenticated()) return true;

  // Intentar recuperar sesión consultando al backend
  // antes de redirigir (ver CA-03b)
  return inject(SessionRestoreService).tryRestore().pipe(
    map(ok => ok ? true : router.createUrlTree(['/auth/redirect-to-login']))
  );
};
```

### CA-03b · Restauración de sesión en recarga de página (`SessionRestoreService`)

Si el usuario recarga la página (`F5`), los Signals de `SessionService` se resetean a `null`. El guard debe intentar recuperar la sesión antes de redirigir:

1. Llamar a `GET /api/core/usuario/profile` (la cookie `auth.session` puede seguir activa).
2. Si responde 200: llamar a `SessionService.setSession(user, null)` → devolver `true` (acceso permitido).
3. Si responde 401: el interceptor `authRefreshInterceptor` intentará renovar con `auth.refresh`.
   - Si el refresh funciona: el reintento del profile responde 200 → sesión restaurada → `true`.
   - Si el refresh también falla: `clearSession()` → devolver `UrlTree` hacia redirect a login.
4. Mostrar un spinner global mientras el restore está en curso (no pantalla en blanco).

### CA-04 · Redirect según rol tras login exitoso

| Rol | Ruta de destino |
|-----|----------------|
| `CLIENTE_CEDENTE` | `/publicador` |
| `EJECUTIVO_FINANCIADORA` | `/ofertador` |
| `ADMIN_FINANCIADORA` | `/ofertador` |
| `ADMIN_CEDENTE` | `/publicador` |
| `ADMIN_BROKER` | `/ofertador` |
| `EJECUTIVO_BROKER` | `/ofertador` |
| `SUPER_ADMIN`, `ADMIN` | `/dashboard` |
| `USR_STD`, `SUPERVISOR`, `READ_ONLY` | `/dashboard` |

- Si el rol no está en la tabla (inesperado): redirigir a `/dashboard` como fallback.

### CA-05 · `noAuthGuard` — evita acceder a `/auth/callback` con sesión activa

- Si el usuario ya tiene sesión activa e intenta navegar a `/auth/callback`: redirigir directamente a la ruta según su rol (tabla CA-04).
- Evita que el código PKCE sea reusado si el usuario ya está logueado.

### CA-06 · Ruta de redirect a login

El Shell debe tener una ruta interna `/auth/redirect-to-login` que solo hace `window.location.href = {loginAppUrl}`. No es navegable directamente — solo la usa el guard para hacer una hard navigation al dominio de `app-login`.

La URL de `app-login` debe venir de un `InjectionToken<string>` (`LOGIN_APP_URL`) definido en `shared-utils`, no hardcodeada.

### CA-07 · Spinner de carga durante el callback

- Mientras `AuthCallbackComponent` procesa (pasos 2–4 del flujo), mostrar un spinner centrado en pantalla.
- No mostrar ningún layout de la app (navbar, sidebar) durante el callback.
- Si el proceso tarda más de 10 segundos sin respuesta: mostrar mensaje de error y opción de "Volver al login".

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **`code` ya fue usado** | Ms-auth devuelve error. El Portal muestra mensaje de expiración y redirige a login. El código PKCE es de un solo uso. |
| EB-02 | **`sid` no existe en Redis** | Ms-auth no puede recuperar el verifier → error 400/401. Mismo tratamiento: mensaje + redirect. |
| EB-03 | **Usuario navega directamente a una ruta del portal sin sesión** | El `authGuard` ejecuta `SessionRestoreService.tryRestore()`. Si no hay sesión recuperable, redirect a login con la URL original como `returnUrl` en query param (para retornar tras login exitoso). |
| EB-04 | **`returnUrl` tras login** | Si el guard redirige con `?returnUrl=/publicador/factura/123`, tras el callback exitoso el Portal debe navegar a esa URL en lugar del destino por defecto del rol. |
| EB-05 | **Perfil no disponible inmediatamente** | Si `GET /usuario/profile` falla después de un callback exitoso (error 5xx del BFF), ¿se muestra error o se redirige a dashboard sin perfil? Definir comportamiento. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- `AuthCallbackComponent` debe ser un componente **standalone** del Shell, no de ningún MFE.
- No usar `ActivatedRoute.snapshot` para leer los query params del callback — usar el observable `queryParams` para compatibilidad con el router.
- El `SessionRestoreService` puede ser parte de `shared-utils` si se usa también en `app-login` en el futuro, o del Shell si es exclusivo del portal.
- Para el spinner global durante el restore de sesión, usar el mecanismo de loading del Shell (no un overlay en el componente guard).
- La llamada a `/usuario/profile` tras el callback sirve también como primer "health check" de la sesión — confirma que las cookies fueron seteadas correctamente por el navegador.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 2 — Autenticación*
