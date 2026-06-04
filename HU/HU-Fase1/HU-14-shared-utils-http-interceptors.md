# HU-14 — `shared-utils`: Interceptores HTTP y Renovación Silenciosa de Sesión

---

## Historia de Usuario

**Yo como** desarrollador del frontend,
**Quiero** que todas las llamadas HTTP al backend incluyan automáticamente las cookies de sesión y que los errores 401 disparen una renovación silenciosa del token antes de reintentar la petición fallida,
**Para** que ningún MFE necesite manejar manualmente la autenticación en sus propios servicios HTTP, y para que el usuario no sea redirigido al login mientras su `auth.refresh` sea válido.

---

## Contexto técnico

La autenticación usa **cookies HttpOnly** (`auth.session` + `auth.refresh`) emitidas por ms-auth y manejadas por el navegador. El frontend nunca lee ni almacena tokens — solo envía `withCredentials: true` en cada petición para que el navegador adjunte las cookies automáticamente.

Flujo de renovación:
```
Petición HTTP → 401 (auth.session expirada)
  → interceptor llama POST /api/auth/security/session/refresh
      → ms-auth rota auth.refresh y emite nuevo auth.session
  → reintento de la petición original con la nueva cookie
  → si el refresh también falla (401/403) → clearSession + redirect a app-login
```

Los interceptores se definen en `shared-utils` y se registran en el `appConfig` del Shell y de `app-login`.

---

## Criterios de Aceptación

### CA-01 · `CredentialsInterceptor` — adjunta cookies en todas las peticiones

```ts
// libs/shared-utils/src/lib/interceptors/credentials.interceptor.ts
export const credentialsInterceptor: HttpInterceptorFn = (req, next) => {
  return next(req.clone({ withCredentials: true }));
};
```

- Se aplica a **todas** las peticiones HTTP del frontend, sin excepciones por URL.
- No modifica headers ni body.

### CA-02 · `AuthRefreshInterceptor` — renovación silenciosa en 401

Comportamiento esperado:

1. Cualquier petición al backend devuelve **401**.
2. El interceptor hace `POST {API_BASE_URL}/api/auth/security/session/refresh` (con `withCredentials: true`).
3. Si el refresh es exitoso (ms-auth emite nuevas cookies):
   - Reintenta la petición original **exactamente una vez**.
   - El usuario no ve ninguna interrupción.
4. Si el refresh falla (401 o 403):
   - Llama a `SessionService.clearSession()`.
   - Redirige al usuario a `{app-login-url}` (la URL de `app-login` debe ser configurable, no hardcodeada).
   - Cancela la petición original.

Restricciones:
- El interceptor **no debe** intentar renovar si la petición que falló es ya el endpoint de refresh (`/security/session/refresh`). Esto evita un loop infinito.
- Si múltiples peticiones fallan con 401 simultáneamente, el interceptor debe hacer **una sola llamada de refresh** y todas las peticiones en cola deben esperar y reintentarse con la nueva cookie. Usar un observable compartido (`shareReplay(1)` o similar) para serializar el refresh.

```ts
// Estructura conceptual
export const authRefreshInterceptor: HttpInterceptorFn = (req, next) => {
  return next(req).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status === 401 && !isRefreshRequest(req)) {
        return refreshSession().pipe(
          switchMap(() => next(req.clone({ withCredentials: true }))),
          catchError(() => {
            sessionService.clearSession();
            redirectToLogin();
            return EMPTY;
          })
        );
      }
      return throwError(() => error);
    })
  );
};
```

### CA-03 · `ErrorInterceptor` — manejo de errores globales

| Status | Comportamiento |
|--------|---------------|
| `403` | Log en consola + emitir un evento/signal de "acceso denegado". El componente que recibe el error puede mostrar un mensaje. No redirigir automáticamente. |
| `404` | Propagar el error al servicio que hizo la petición (sin interceptar). |
| `500`, `502`, `503` | Log en consola + signal de "error de servidor". El componente puede mostrar un toast de error genérico. |
| Timeout / `0` | Tratarlo como error de red. Signal de "sin conexión". |

- El interceptor **no debe** usar `alert()` ni `window.location.reload()`.
- Los mensajes de error al usuario son responsabilidad de los componentes, no del interceptor.

### CA-04 · Interceptores registrados en `appConfig` del Shell

En `projects/seis-portal/src/app/app.config.ts`:

```ts
export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(APP_ROUTES),
    provideHttpClient(
      withInterceptors([
        credentialsInterceptor,
        authRefreshInterceptor,
        errorInterceptor,
      ])
    ),
  ],
};
```

- El orden importa: `credentials` primero (todas las peticiones), luego `authRefresh` (maneja 401), luego `errorInterceptor` (maneja el resto).
- Los MFEs **no registran** los interceptores — heredan los del Shell vía el shared scope de Angular.

### CA-05 · Verificación de no-loop en refresh

Prueba de regresión:
1. Simular que tanto la petición original como el endpoint de refresh devuelven 401.
2. El interceptor debe llamar al endpoint de refresh **exactamente una vez**.
3. Al fallar el refresh, debe llamar `clearSession()` y redirigir — sin llamadas adicionales.

### CA-06 · Peticiones concurrentes con sesión expirada

Prueba de concurrencia:
1. Simular que 3 peticiones HTTP se disparan simultáneamente y todas reciben 401.
2. El interceptor debe hacer **una sola llamada** a `/security/session/refresh`.
3. Las 3 peticiones originales deben reintentarse tras el refresh exitoso.

---

## Casos de Borde

| # | Escenario | Pregunta a resolver |
|---|---|---|
| EB-01 | **URL de redirect a app-login** | ¿Cuál es la URL exacta a la que redirigir cuando la sesión expira completamente? ¿Es siempre `http://localhost:8082` en dev y `https://login.{APP_DOMAIN}` en prod? Esta URL debe venir de una constante configurable (environment o injection token). |
| EB-02 | **Peticiones de app-login** | `app-login` también usa `provideHttpClient`. ¿Debe registrar los mismos interceptores? El interceptor de refresh no tendría sentido en `app-login` (no hay sesión que renovar). Definir si `shared-utils` exporta subconjuntos separados de interceptores para cada contexto. |
| EB-03 | **Refresh en background tab** | Si el usuario tiene la app en una pestaña inactiva, las cookies pueden expirar. Al volver a la pestaña y hacer cualquier acción, ¿el interceptor maneja el 401 correctamente o hay un edge case con el estado del Service Worker (si lo hay)? |
| EB-04 | **Peticiones a MinIO / S3 (presigned URLs)** | En el entorno actual (desarrollo), las subidas van a `localhost` — mismo dominio, `withCredentials: true` no genera problemas CORS. En producción las URLs apuntarán a un bucket de **AWS S3** (dominio externo: `*.s3.amazonaws.com`). En ese escenario adjuntar `withCredentials: true` en la petición a S3 causará un error CORS (`credentials flag is 'true', but the CORS header 'Access-Control-Allow-Origin' does not match`). El `credentialsInterceptor` debe detectar si la URL de destino es del dominio propio o externo y omitir `withCredentials` para URLs externas. La lógica de detección puede basarse en comparar el hostname de la petición contra `window.location.hostname` o contra una lista de dominios confiables inyectada como token. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- Usar `HttpInterceptorFn` (functional interceptors, Angular 15+). No usar la API de clase con `implements HttpInterceptor`.
- La serialización de refreshes concurrentes se puede implementar con una variable de instancia en el interceptor que almacena el observable de refresh en curso (`isRefreshing$`), usando `shareReplay(1)`.
- La URL de `app-login` debe provenir de un `InjectionToken<string>` (`LOGIN_APP_URL`) definido en `shared-utils` e inyectado en el `appConfig` del Shell. Nunca hardcodeada en el interceptor.
- Si ya existen interceptores en el proyecto con clase (`implements HttpInterceptor`), migrarlos a funciones (`HttpInterceptorFn`) antes de registrarlos con `withInterceptors`.
- **Presigned URLs (S3 en producción)**: el `credentialsInterceptor` debe omitir `withCredentials` para peticiones cuyo hostname no sea el propio. Patrón recomendado:
  ```ts
  export const credentialsInterceptor: HttpInterceptorFn = (req, next) => {
    const isSameDomain = req.url.startsWith('/') || req.url.includes(window.location.hostname);
    return next(isSameDomain ? req.clone({ withCredentials: true }) : req);
  };
  ```
  Esto funciona tanto en desarrollo (`localhost`) como en producción sin cambios, y es seguro cuando las URLs de S3 sean externas.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 1 — Infraestructura base*
