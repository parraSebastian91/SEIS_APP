# HU-40 — Referencia de Seguridad y Cumplimiento

*Tipo: documento de referencia permanente | No es una tarea de implementación incremental*
*Aplica a: todos los proyectos del monorepo | Contexto normativo: CMF (Comisión para el Mercado Financiero) — Chile*
*Consultar antes de implementar auth, RBAC, subida de documentos, o cualquier operación que toque datos financieros o PII*

---

## Propósito

Factor opera en el dominio financiero chileno y está sujeto a la supervisión de la CMF. La seguridad no es una capa adicional — es un requerimiento estructural desde el inicio. Este documento centraliza las decisiones de seguridad y cumplimiento: autenticación PKCE, gestión de sesión, RBAC, OWASP Top 10, rate limiting, controles anti-fraude, auditoría y privacidad.

---

## 1. Autenticación y Gestión de Sesión

### Flujo PKCE cross-app

El flujo PKCE se distribuye entre `app-login` (genera el challenge, captura credenciales) y el Shell del Portal (ejecuta el callback que establece la sesión).

**Mecanismo de traspaso del `code_verifier`**: ms-auth lo almacena **server-side** vinculado al `sessionId` generado por `app-login`. El Portal no lo recibe — ms-auth lo recupera internamente al llamar al callback.

> **Cambio de backend requerido**: `POST /security/callback` actualmente exige `codeVerifier` en el body. Con el enfoque server-side, este campo debe volverse opcional: si está ausente, ms-auth lo recupera desde Redis usando `sessionId`; si está presente, se usa directamente (compatibilidad con flujos directos).

```
app-login (login.factor.cl)                    Portal (app.factor.cl)

1. Genera sessionId (UUID)
   Genera code_verifier + code_challenge

2. POST /security/authenticate
   { username, password,
     code_challenge, typeDevice: "WEB",
     sessionId }                              ms-auth guarda:
                                              Redis[sessionId] = code_verifier
   ← { data: [redirect_url?code=ABC] }

3. window.location.href =
   app.factor.cl/auth/callback
   ?code=ABC&sid={sessionId}
                                         4. /auth/callback recibe code + sid

                                         5. POST /security/callback
                                            { code: "ABC",
                                              sessionId: sid,
                                              typeDevice: "WEB" }
                                            (sin codeVerifier — ms-auth lo
                                             recupera desde Redis[sid])

                                         6. ← Cookies: auth.session + auth.refresh

                                         7. GET /usuario/profile → leer rol
                                            Redirigir a /publicador o /ofertador
```

**URL del callback**: `app.{APP_DOMAIN}/auth/callback` — ruta dedicada en el Shell que no renderiza layout, solo ejecuta el paso 2 PKCE y redirige. No debe ser indexable ni accesible directamente sin parámetros válidos.

**Recovery de contraseña**: los enlaces del email apuntan a `login.{APP_DOMAIN}/reset-password?token=...&uuid=...`. Esta ruta vive en `app-login`. El portal no maneja este flujo.

**Logout**: `GET /security/logout` puede llamarse desde cualquier app. Ambas deben redirigir a `login.{APP_DOMAIN}` al detectar sesión expirada (`401` del BFF).

### Cookies de sesión

| Cookie | Flags | TTL | Descripción |
|--------|-------|-----|-------------|
| `auth.session` | `HttpOnly; SameSite=Lax` | 1 hora (TTL Redis) | ID de sesión vinculado a los tokens internos de ms-auth |
| `auth.refresh` | `HttpOnly; SameSite=Lax; Secure en HTTPS` | 7 días (rotante) | Refresh token; cada uso emite uno nuevo, el anterior queda inválido |

> El JWT es **interno a ms-auth**. El frontend nunca lo ve ni lo almacena.

### Consideración CSRF

`SameSite=Lax` bloquea cookies en cross-site POST desde navegadores modernos, cubriendo los vectores CSRF más comunes. Para operaciones críticas (aceptar oferta, confirmar depósito) se recomienda añadir `X-CSRF-TOKEN` como segunda línea de defensa. ⬜ Post-MVP v1.

### Reglas de sesión

- **Logout activo**: `GET /security/logout` destruye la sesión en Redis e invalida ambas cookies.
- **No sesiones simultáneas**: el nuevo login invalida la sesión anterior en Redis.
- **Inactividad**: cuando `auth.session` expira, el interceptor HTTP intenta refresh silencioso. Si `auth.refresh` también expiró, redirige al login con mensaje `"Tu sesión expiró"`.
- **2FA**: ⬜ Post-MVP v1 — TOTP / SMS. Los roles `ADMIN_*` y `SUPER_ADMIN` serán los primeros en requerirlo.

---

## 2. Control de Acceso (RBAC)

- **Validación dual**: el frontend oculta elementos según el rol (UX), pero el **backend valida en cada request** (seguridad real). Una respuesta `403` nunca debe provocar pantalla en blanco — mostrar estado de acceso denegado controlado.
- **Principio de mínimo privilegio**: cada rol solo recibe los permisos que necesita. Sin herencia implícita entre roles.
- **Pertenencia a organización**: el backend verifica que el usuario sea miembro activo de la organización afectada en operaciones sobre recursos de org (facturas, miembros, configuración).
- **Separación de contextos**: un `EJECUTIVO_FINANCIADORA` no puede ver facturas ni datos de otras organizaciones financieras, aunque compartan la plataforma.

---

## 3. Protección contra Ataques Comunes (OWASP Top 10)

| Amenaza | Mitigación |
|---------|-----------|
| **A01 — Broken Access Control** | RBAC estricto en backend. Validación de org membership en cada operación de recurso. |
| **A02 — Cryptographic Failures** | HTTPS / TLS 1.2+ obligatorio. Datos sensibles en reposo cifrados (contraseñas con bcrypt/argon2). No transmitir datos sensibles en query params. |
| **A03 — Injection** | ORM con queries parametrizados. Validación y sanitización de todos los inputs en backend. Nunca concatenar SQL/queries. |
| **A04 — Insecure Design** | Flujos de negocio con controles anti-fraude (§5). Validación de estado de factura antes de cada transición. |
| **A05 — Security Misconfiguration** | CORS estricto (solo dominios autorizados). Headers: `Strict-Transport-Security`, `X-Content-Type-Options`, `X-Frame-Options: DENY`, `Content-Security-Policy`. |
| **A06 — Vulnerable Components** | Dependencias auditadas con `npm audit` / `snyk` en CI/CD. Sin librerías abandonadas o con CVEs activos. |
| **A07 — Auth Failures** | Rate limiting en login (§4). Mensajes de error genéricos (anti-enumeración de usuarios). |
| **A08 — Software Integrity Failures** | Verificación de integridad en CI/CD. Subresource Integrity (SRI) para assets externos. |
| **A09 — Logging Failures** | Audit log de operaciones críticas (§6). Logs de autenticación con IP y User-Agent. |
| **A10 — SSRF** | La llamada al SII se realiza desde el backend con URL hardcodeada. Sin endpoints que acepten URLs arbitrarias del cliente. |

---

## 4. Rate Limiting y Protección Anti-Fuerza Bruta

| Endpoint | Límite | Acción al superar |
|----------|--------|------------------|
| `POST /security/authenticate` | 5 intentos fallidos en 10 min por IP+username | Bloqueo temporal 15 min + notificación al usuario |
| `POST /security/session/refresh` | 30 req/min por IP | `429 Too Many Requests` |
| `POST /security/password-reset/request` | 3 solicitudes en 15 min por correo | Anti-enumeración: siempre responde `200` |
| Endpoints de API general | 100 req/min por usuario autenticado | `429` con header `Retry-After` |
| Subida de documentos | 10 documentos/hora por org | `429` con mensaje descriptivo |

---

## 5. Controles de Negocio Anti-Fraude

Específicos del dominio de factoring:

- **Validación de RUT con SII** antes de activar una organización — verifica que el RUT exista, esté activo y tenga habilitada la emisión de facturas electrónicas (ver HU-22).
- **Unicidad de factura**: una factura no puede publicarse dos veces (control por folio + RUT emisor).
- **Trazabilidad de estados**: cada transición de estado de una factura queda registrada con timestamp, userId y origen (UI, webhook, sistema). No existen transiciones retroactivas.
- **Confirmación doble en aceptación de oferta**: el cliente debe confirmar explícitamente antes de que la oferta sea vinculante (modal de doble confirmación — ver HU-30).
- **Firma de operaciones críticas**: aceptar oferta y confirmar depósito requieren sesión vigente (sin tokens cercanos a expirar sin refresh previo).

---

## 6. Trazabilidad y Auditoría

Requerido por buenas prácticas CMF para plataformas financieras.

### Operaciones que generan registro de auditoría

| Categoría | Operaciones |
|-----------|------------|
| **Autenticación** | Login exitoso, login fallido, logout, refresh de token, cambio de contraseña |
| **Facturas** | Creación, publicación, rechazo, aceptación de oferta, confirmación de depósito, denuncia |
| **Ofertas** | Creación, modificación, aceptación, rechazo, Match & Beat |
| **Organización** | Creación, activación, desactivación, cambio de datos |
| **Membresía** | Ingreso (con método), remoción, cambio de rol (promote/demote) |
| **Acceso** | Aprobación/rechazo de solicitudes de membresía, invitaciones enviadas/revocadas |
| **Admin de plataforma** | Cambios realizados por `SUPER_ADMIN` / `ADMIN` sobre cualquier recurso |

### Estructura del registro de auditoría

| Campo | Descripción |
|-------|-------------|
| `timestamp` | Fecha y hora exacta (UTC) |
| `actorUserId` | Usuario que realizó la acción |
| `actorRole` | Rol del usuario en el momento de la acción |
| `action` | Código de acción (ej. `invoice.offer.accepted`) |
| `resourceType` | Tipo de recurso afectado (`invoice`, `organization`, `member`, etc.) |
| `resourceId` | ID del recurso |
| `organizationId` | Org del contexto (si aplica) |
| `ip` | IP del cliente |
| `userAgent` | User-Agent del cliente |
| `metadata` | JSON adicional según tipo de acción (ej. motivo de rechazo, rol anterior/nuevo) |

- Los registros de auditoría son **inmutables** — no pueden modificarse ni eliminarse por ningún rol, incluido `SUPER_ADMIN`.
- Retención mínima recomendada: **5 años** (alineado con normativas contables/financieras chilenas).

---

## 7. Privacidad y Datos Personales

Chile está en transición hacia una nueva Ley de Protección de Datos Personales (reemplazo de Ley 19.628). Se diseña bajo los principios de la nueva ley desde el inicio.

| Principio | Aplicación en Factor |
|-----------|---------------------|
| **Finalidad** | Los datos se recopilan solo para los fines de la plataforma (factoring). No se comparten con terceros sin consentimiento. |
| **Minimización** | Se solicitan solo los datos necesarios para cada flujo. El perfil público no expone email, teléfono ni RUT. |
| **Transparencia** | Términos y Condiciones visibles antes de publicar una factura (HU-25). Política de privacidad accesible desde el footer. |
| **Seguridad** | Datos PII cifrados en reposo. Contraseñas hasheadas con bcrypt/argon2 (nunca en texto plano). |
| **Derecho de acceso/cancelación** | El usuario puede exportar o solicitar eliminación de sus datos personales (funcionalidad de backoffice — fuera de scope MVP de UI). |

---

## 8. Seguridad en el Frontend (Angular)

- Angular sanitiza automáticamente el DOM — **no usar `bypassSecurityTrust*`** salvo casos excepcionales documentados y revisados en PR.
- **No almacenar datos sensibles en `localStorage` ni `sessionStorage`** — estado de sesión solo en memoria (`SessionService`) o httpOnly cookie.
- El state global (Module Federation singleton) **no debe incluir** el JWT ni datos PII completos. Solo lo mínimo necesario para la UI (nombre, rol, `unreadCount`).
- Variables de entorno con URLs de API y claves públicas gestionadas por CI/CD — **no hardcodear** en código fuente.
- Content Security Policy restrictiva: bloquear inline scripts, evaluar solo fuentes propias y CDNs explícitamente listados.
- `X-Correlation-Id` en todas las requests mutantes — permite correlacionar logs entre ms-auth y BFF.
