# HU-17 — Recuperación de Contraseña (`app-login`)

---

## Historia de Usuario

**Yo como** usuario que olvidé mi contraseña,
**Quiero** poder solicitar un enlace de recuperación a mi correo registrado y establecer una nueva contraseña,
**Para** recuperar el acceso a mi cuenta sin necesidad de contactar soporte.

---

## Contexto técnico

El flujo vive íntegramente en `app-login`. Tiene 3 pantallas/estados que se renderizan en el panel derecho del mismo layout que el login (panel izquierdo de branding permanece fijo):

```
Pantalla A (/forgot-password)
  → POST /api/auth/security/password-reset/request
  → Pantalla B (mismo componente, estado distinto)

Pantalla C (/reset-password?token=...&uuid=...)
  → GET  /api/auth/security/password-reset/validate?token=&uuid=
  → POST /api/auth/security/password-reset/reset
  → Redirect a /login con toast de confirmación
```

Las pantallas A y B son estados del mismo componente (`PasswordRecoveryPage`). La pantalla C es una ruta separada (`/reset-password`).

---

## Criterios de Aceptación

### CA-01 · Pantalla A — Solicitar recuperación (`/forgot-password`)

Ruta accesible desde el link `"¿Olvidaste tu contraseña?"` del `LoginForm`.

Campos:
- **Correo electrónico** — input `type="email"`, autocomplete `email`.

Comportamiento:
- Link `← Volver al login` navega a `/login`.
- Validación de formato de email al hacer clic en "Enviar enlace". Si es inválido: error inline `"Ingresa un correo electrónico válido."`.
- Al enviar: `POST /api/auth/security/password-reset/request` con body `{ correo: "..." }`.
- **La respuesta es siempre positiva**, sin importar si el correo existe en el sistema. No revelar si el email está registrado.
- Tanto en éxito como en error 404: transicionar a Pantalla B con el mensaje estándar.
- Solo en error de red o 5xx: mostrar error inline `"No se pudo procesar. Intenta más tarde."` y permanecer en Pantalla A.
- El botón se deshabilita y muestra spinner durante la petición.

### CA-02 · Pantalla B — Confirmación de envío (estado del mismo componente)

Mostrada inmediatamente tras el submit de Pantalla A (incluso si el correo no existe).

Contenido:
```
✅ Revisa tu correo

Enviamos un enlace de recuperación a
{correo ingresado en Pantalla A}

El enlace expira en 30 minutos.

[Reenviar enlace]  (deshabilitado, muestra countdown: "Reenviar en 58s")

← Volver al login
```

Comportamiento:
- El correo mostrado es exactamente el que el usuario ingresó en Pantalla A (no enmascarar).
- Botón "Reenviar enlace" deshabilitado por **60 segundos** desde que se renderiza Pantalla B. Muestra countdown en formato `"Reenviar en Xs"`. Al terminar el countdown, el botón se habilita.
- Al hacer clic en "Reenviar": ejecuta la misma petición de Pantalla A. Reinicia el countdown.
- `← Volver al login` navega a `/login`.

### CA-03 · Pantalla C — Nueva contraseña (`/reset-password`)

Ruta accesible **exclusivamente desde el enlace del email**. El enlace contiene `?token=...&uuid=...` (ambos requeridos).

**Validación previa al mostrar el formulario:**

Al cargar la ruta, antes de renderizar el formulario:
1. Leer `token` y `uuid` de los query params.
2. Si alguno está ausente: mostrar error directamente (sin llamada al backend) con CTA a Pantalla A.
3. Llamar a `GET /api/auth/security/password-reset/validate?token={token}&uuid={uuid}`.
4. Si la validación es exitosa: mostrar el formulario de nueva contraseña.
5. Si falla (token expirado, ya usado, inválido): mostrar estado de error (no el formulario):
   ```
   ❌ Este enlace ya no es válido.
   
   El enlace expiró o ya fue utilizado.
   
   [Solicitar nuevo enlace]  → navega a /forgot-password
   ```

**Formulario (solo si la validación fue exitosa):**

Campos:
- **Nueva contraseña** — `type="password"` con toggle de visibilidad `[👁]` + medidor de fortaleza de 4 niveles (ver CA-04).
- **Confirmar contraseña** — `type="password"` con toggle de visibilidad `[👁]`.

Validaciones:
- Contraseña mínima: 8 caracteres, al menos 1 mayúscula, 1 minúscula, 1 número. (Mismas reglas que en registro).
- Confirmación debe coincidir con la contraseña. Error inline si no coincide: `"Las contraseñas no coinciden."`.
- Validaciones en tiempo real mientras el usuario escribe (distinto al login, donde se valida solo al submit).

Al enviar:
```
POST /api/auth/security/password-reset/reset
{ token, uuid, newPassword, confirmPassword }
```

- Si es exitoso: navegar a `/login` con toast `"Contraseña actualizada. Puedes iniciar sesión."`.
- Si el token expiró entre la validación y el submit (raro pero posible): mostrar estado de error con CTA a Pantalla A.
- El botón "Actualizar contraseña" se deshabilita y muestra spinner durante la petición.

### CA-04 · Medidor de fortaleza de contraseña

El medidor se muestra debajo del campo "Nueva contraseña" y se actualiza en tiempo real:

| Nivel | Condición | Color | Texto |
|-------|-----------|-------|-------|
| 1 — Muy débil | < 8 caracteres | Rojo | "Muy débil" |
| 2 — Débil | ≥ 8 chars, sin mayúscula o sin número | Naranja | "Débil" |
| 3 — Aceptable | ≥ 8 chars, tiene mayúscula + número | Amarillo | "Aceptable" |
| 4 — Fuerte | ≥ 12 chars, mayúscula + número + símbolo | Verde | "Fuerte" |

- El medidor es **visual** (barra segmentada o progreso). No bloquea el submit si la contraseña cumple el mínimo requerido (nivel ≥ 2).
- El nivel 1 sí bloquea el submit (contraseña demasiado corta).

### CA-05 · Prevención de enumeración de usuarios

- Pantalla A siempre muestra Pantalla B, sin distinguir si el correo existe.
- El tiempo de respuesta entre correo existente y no existente no debe ser perceptiblemente distinto desde el frontend (no hay timing attack mitigation explícita en el frontend, pero no agregar delays artificiales tampoco).
- El mensaje de Pantalla B es idéntico en ambos casos.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **Token válido, contraseña ya usada anteriormente** | ¿Ms-auth valida historial de contraseñas? Si es así, el backend devuelve error específico. El frontend debe mostrar: `"No puedes reutilizar una contraseña anterior."` Sin CTA adicional (el formulario permanece abierto para intentar otra contraseña). |
| EB-02 | **Usuario activo en otra pestaña durante el reset** | No hay implicación especial — el reset no invalida la sesión activa (ms-auth define este comportamiento). El usuario puede estar logueado y resetear la contraseña simultáneamente. |
| EB-03 | **Enlace del email clicado desde cliente de correo móvil** | El enlace apunta a `login.{APP_DOMAIN}/reset-password?token=...&uuid=...`. `app-login` responde correctamente en mobile (diseño responsive). Sin implicaciones especiales. |
| EB-04 | **Múltiples solicitudes de recovery activas** | Si el usuario solicita el enlace 3 veces, ¿ms-auth invalida los anteriores o son todos válidos hasta su expiración? Definir con el backend. El frontend no necesita manejar esto explícitamente. |
| EB-05 | **Correo con caracteres especiales** | Emails como `usuario+filtro@empresa.cl` son válidos. La validación de formato en Pantalla A debe aceptarlos (RFC 5322 básico, no regex restrictivo). |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- Las 3 pantallas se implementan con **2 rutas Angular en `app-login`**: `/forgot-password` (Pantallas A y B como estados de un componente) y `/reset-password` (Pantalla C como componente separado).
- La lógica del medidor de fortaleza debe vivir en el propio componente `ResetPasswordForm` — no en `shared-utils`, ya que `app-login` no comparte el shared scope de Module Federation del monorepo del portal.
- La validación previa del token en Pantalla C (`GET /validate`) debe hacerse en el `resolver` de la ruta, no en `ngOnInit`, para que Angular espere la respuesta antes de renderizar el componente. Así se evita el flash del formulario antes de mostrar el error.
- Usar `HttpClient` de Angular con `provideHttpClient()` en `app-login` (sin los interceptores de `shared-utils` — esta app no tiene sesión activa que mantener).
- El toast de confirmación tras resetear la contraseña se pasa como `state` de la navegación: `router.navigate(['/login'], { state: { toast: 'password-updated' } })`. El `LoginPage` lee el state y muestra el toast si existe.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 2 — Autenticación*
