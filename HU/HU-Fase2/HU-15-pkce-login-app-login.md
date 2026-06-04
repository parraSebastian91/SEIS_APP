# HU-15 — Login: Flujo PKCE Paso 1 (`app-login`)

---

## Historia de Usuario

**Yo como** usuario de la plataforma (cualquier rol),
**Quiero** ingresar mi nombre de usuario y contraseña en la pantalla de login,
**Para** iniciar el flujo de autenticación PKCE y ser redirigido automáticamente al portal con mi sesión activa.

---

## Contexto técnico

`app-login` es una aplicación Angular **standalone e independiente** (`app-login-erp-seis/`). No usa Module Federation ni `shared-utils`. Maneja el Paso 1 del flujo PKCE cross-app:

```
app-login                                  ms-auth (:3000 via Kong)

1. Genera sessionId (UUID v4)
   Genera code_verifier (32 bytes aleatorios, base64url)
   Genera code_challenge = BASE64URL(SHA-256(code_verifier))

2. POST /api/auth/security/authenticate
   { username, password,
     code_challenge,
     typeDevice: "WEB",
     sessionId }
                                      ms-auth guarda en Redis:
                                      Redis[sessionId] = code_verifier
   ← { data: { redirect_url: "...?code=ABC" } }

3. window.location.href =
   http://localhost:8083/auth/callback
   ?code=ABC&sid={sessionId}
```

El `code_verifier` **nunca sale del navegador** hacia el Portal. ms-auth lo recupera desde Redis usando el `sessionId` cuando el Portal hace el callback.

---

## Criterios de Aceptación

### CA-01 · Layout de dos paneles

- En `md+` (≥ 768px): panel izquierdo de branding (2/5 ancho) + panel derecho con formulario (3/5 ancho). Ambos a altura completa de viewport.
- En `xs–md` (< 768px): solo el panel derecho a pantalla completa. El panel de branding desaparece.
- Panel izquierdo: logo `{APP_NAME}`, tagline `"Financiamiento para empresas que no esperan."`, ilustración o patrón abstracto en tonos navy/teal.

### CA-02 · Formulario de login

Campos requeridos:
- **Nombre de usuario** — input de tipo `text`, autocomplete `username`.
- **Contraseña** — input de tipo `password` con toggle de visibilidad `[👁]` que alterna `type="password"` / `type="text"`.

Comportamiento del botón "Iniciar sesión":
- Muestra spinner y se deshabilita mientras la petición está en curso.
- Se vuelve a habilitar si la petición falla (para permitir reintentar).

Validación:
- Ambos campos requeridos. Error inline `"Este campo es obligatorio"` si el usuario intenta enviar vacío.
- Validaciones solo al intentar submit — no en tiempo real mientras el usuario escribe.

### CA-03 · Generación del par PKCE antes de llamar al backend

Antes de hacer la petición a ms-auth, el `LoginService` debe:

1. Generar `sessionId`: `crypto.randomUUID()`.
2. Generar `code_verifier`: 32 bytes aleatorios con `crypto.getRandomValues()`, codificados en base64url (sin `=`, sin `+`, sin `/`).
3. Generar `code_challenge`: `SHA-256(code_verifier)` con Web Crypto API (`crypto.subtle.digest`), resultado codificado en base64url.

```ts
// Pseudocódigo
const sessionId = crypto.randomUUID();
const verifierBytes = crypto.getRandomValues(new Uint8Array(32));
const code_verifier = base64url(verifierBytes);
const hashBuffer = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(code_verifier));
const code_challenge = base64url(new Uint8Array(hashBuffer));
```

- Usar exclusivamente la **Web Crypto API nativa** del navegador. No instalar librerías externas para este cálculo.
- `code_verifier` y `sessionId` se almacenan **solo en memoria** (variable local del servicio) durante el flujo. No se guardan en `localStorage` ni en `sessionStorage`.

### CA-04 · Llamada al endpoint `POST /security/authenticate`

```
POST {API_BASE_URL}{API_AUTH_URL}/security/authenticate
Content-Type: application/json

{
  "username": "...",
  "password": "...",
  "code_challenge": "...",
  "typeDevice": "WEB",
  "sessionId": "..."
}
```

Variables de entorno disponibles en `app-login`:
- `API_BASE_URL` = `http://localhost:8000`
- `API_AUTH_URL` = `/api/auth`

Respuesta esperada en éxito: objeto con `data` que contiene la URL de redirect con el `code` como query param.

### CA-05 · Redirect al Portal tras autenticación exitosa

- Extraer el `code` de la URL devuelta por ms-auth.
- Redirigir con `window.location.href` (hard navigation, no Angular Router) a:
  ```
  http://localhost:8083/auth/callback?code={code}&sid={sessionId}
  ```
- La URL base del Portal (`http://localhost:8083`) debe ser configurable (environment o variable de entorno inyectada). No hardcodeada en el servicio.

### CA-06 · Manejo de errores

| Escenario | Comportamiento |
|-----------|---------------|
| Credenciales incorrectas (401/403) | Mensaje inline genérico: `"Nombre de usuario o contraseña incorrectos."` No limpiar formulario. |
| Sesión activa en otro dispositivo (respuesta especial del backend) | Continuar el login normalmente. Mostrar toast: `"Se cerró tu sesión anterior en otro dispositivo."` |
| Error de red / timeout | Mensaje inline: `"No se pudo conectar. Verifica tu conexión e intenta nuevamente."` |
| Cualquier otro error 5xx | Mensaje inline: `"Error del servidor. Intenta más tarde."` |

- Los mensajes de error **no deben revelar** si el nombre de usuario existe en el sistema.
- El formulario nunca se limpia ante un error — el usuario puede corregir sin volver a escribir todo.

### CA-07 · Link de registro y de recuperación

- `"¿Olvidaste tu contraseña?"` → navega (Angular Router) a la ruta `/forgot-password` (Pantalla A del flujo de recovery, HU-17).
- `"¿No tienes cuenta? Regístrate →"` → navega a `/register` (fuera de scope de esta HU).

---

## Casos de Borde

| # | Escenario | Decisión / Pregunta |
|---|-----------|---------------------|
| EB-01 | **Tab cerrado antes del redirect** | Si el usuario cierra el tab después del authenticate pero antes de llegar al callback del Portal, la operación queda incompleta. La sesión Redis del verifier expira sola. No requiere manejo especial. |
| EB-02 | **Botón atrás del navegador desde el Portal** | El usuario vuelve a `app-login` después del redirect. El formulario debe estar vacío (sin estado persistido). |
| EB-03 | **Usuario ya autenticado llega al login** | Si el usuario navega a `app-login` teniendo una sesión activa en el portal, ¿se redirige automáticamente al portal o se muestra el login igual? Definir comportamiento. |
| EB-04 | **Timeout de la petición** | ¿Cuántos segundos antes de considerar la petición como timeout y mostrar el error de red? Sugerencia: 15 segundos. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- `app-login` **no usa** `HttpClient` de Angular con interceptores — puede implementar las llamadas con `fetch` nativo o con `HttpClient` sin `provideHttpClient` complejo, ya que no hay sesión que manejar en este punto.
- La URL del Portal (para el redirect) debe provenir de `environment.portalUrl` o equivalente. En desarrollo: `http://localhost:8083`. En producción: `https://app.{APP_DOMAIN}`.
- No usar `localStorage` ni `sessionStorage` para `code_verifier`. El verifier vive en Redis (ms-auth) y no necesita persistirse en el cliente.
- El par `sessionId` / `code_verifier` se genera **en cada intento de login**, no se reutiliza.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 2 — Autenticación*
