# HU-18 — Perfil de Usuario (Ver y Editar)

---

## Historia de Usuario

**Yo como** usuario autenticado,
**Quiero** ver y editar mi información personal (foto, banner, datos de contacto, redes sociales) desde mi perfil,
**Para** mantener mi presencia en la plataforma actualizada y controlar qué información es visible para otros usuarios.

---

## Contexto técnico

Esta pantalla vive en `mfe-gestion-usuario` bajo la ruta `/usuario/perfil`. El Shell la carga vía Module Federation (`remoteName: 'mfeGestionUsuario'`).

Los datos se leen del `SessionService` (`shared-utils`) para el usuario autenticado y del backend para los datos completos:
- `GET /api/core/usuario/profile` — datos del usuario y config de visibilidad
- `PUT /api/core/usuario/profile` — actualizar datos
- `GET /api/core/usuario/profile/img` — URLs de avatar y banner
- Subida de archivos (avatar/banner) vía presigned URL MinIO: `GET /api/core/object/presigned-url/USER_AVATAR`, luego `PUT` a la URL generada

---

## Criterios de Aceptación

### CA-01 · Layout de la página

- **Banner**: franja horizontal a ancho completo. Fondo default: gradiente azul/gris. Reemplazable por imagen custom.
- **Avatar**: imagen circular superpuesta al borde inferior izquierdo del banner. Placeholder: silueta gris genérica si no hay foto.
- **Indicador de estado**: punto verde en la esquina inferior derecha del avatar (online).
- En `xs–md`: botón `"Cerrar sesión"` en esquina superior derecha del banner (ver CA-02). En `md+`: oculto.
- Layout de 2 columnas debajo del banner (en `lg+`): columna izquierda (1/3) con tarjetas de info + redes sociales; columna derecha (2/3) con panel de actividad.

### CA-02 · Botón "Cerrar sesión" en banner (solo mobile)

- Visible **únicamente en `xs–md`**. En `md+` el logout está en el sidebar — no renderizar este botón.
- Estilo: botón delineado semitransparente sobre el banner.
- Al pulsar: `GET /api/auth/security/logout` → `SessionService.clearSession()` → `window.location.href = {loginAppUrl}`.

### CA-03 · Vista del perfil propio vs. perfil ajeno

Cuando el usuario ve **su propio perfil**:
- Muestra botón `"Editar perfil"` en el bloque de identidad.
- Muestra email, teléfono y dirección en la tarjeta de Información General.
- El lápiz de edición está visible en las tarjetas.

Cuando un usuario ve **el perfil de otro usuario** (`/usuario/u/{username}`):
- Muestra botones `"+ Conectar"` y `"✉ Mensaje"` (no funcionales en MVP — renderizar deshabilitados o con tooltip `"Próximamente"`).
- Email, teléfono y dirección **no se muestran** (privados).
- El lápiz de edición no aparece.

Tabla de visibilidad según el spec:

| Campo | Sin sesión | Autenticado externo | El propio usuario |
|-------|:----------:|:-------------------:|:-----------------:|
| Nombre, username, avatar | ✅ | ✅ | ✅ |
| Org activa y tipo | ✅ | ✅ | ✅ |
| Redes sociales | ✅ | ✅ | ✅ |
| Actividad Social-Financiera | ❌ | ✅ | ✅ |
| Email, teléfono, dirección, RUT | ❌ | ❌ | ✅ |

### CA-04 · Tarjeta "Información General" — modo lectura y edición

Modo lectura: filas con ícono + valor para email (`✉`), dirección (`📍`), teléfono (`📞`). Ícono de lápiz `✏` alineado a la derecha del encabezado.

Al hacer clic en `✏`:
- Los valores se convierten en campos editables inline (no navegar a otra página).
- CTA: `"Guardar cambios"` y `"Cancelar"`.
- Al guardar: `PUT /api/core/usuario/profile` con los campos modificados.
- Validaciones:
  - Email: formato válido (RFC 5322 básico).
  - Teléfono: formato `+56 9 XXXX XXXX` o libre si el backend lo acepta así.
  - Dirección: campo de texto libre, máximo 200 caracteres.
- Si el backend devuelve error de validación: mostrar error inline por campo.
- Al guardar exitosamente: `SessionService` actualiza `user.nombre` / `user.apellido` si fueron modificados → navbar y sidebar reflejan el cambio en tiempo real.

### CA-05 · Upload de foto de perfil

- Hacer clic sobre el avatar abre un input `type="file"` aceptando `image/*`.
- Validaciones locales antes de subir:
  - Tipo: solo `image/jpeg`, `image/png`, `image/webp`.
  - Tamaño máximo: 5 MB.
- Flujo de subida:
  1. `GET /api/core/object/presigned-url/USER_AVATAR` → obtiene URL firmada de MinIO/S3.
  2. `PUT {presignedUrl}` con el archivo (sin `withCredentials` — URL externa).
  3. `PUT /api/core/usuario/profile` con la URL del nuevo avatar.
- Mientras sube: overlay de progreso sobre el avatar. Botón de cancelar.
- Al éxito: avatar actualiza en tiempo real. `SessionService` actualiza `user.avatarUrl`.
- Al error: toast `"No se pudo subir la foto. Intenta nuevamente."`.

### CA-06 · Upload de banner

- Ícono de cámara `📷` en la esquina superior izquierda del banner.
- Mismas validaciones y flujo de subida que CA-05, con `objectType = USER_BANNER`.
- Dimensiones mínimas recomendadas: 1200×300px (mostrar hint al usuario).
- Al éxito: el banner se actualiza en tiempo real.

### CA-07 · Tarjeta "Redes Sociales"

- Chips por cada red registrada (ej. `linkedin`).
- Botón `"+ Agregar"` que abre un inline form: select de red social + input de URL.
- Al hacer clic sobre un chip existente: opción de editar URL o eliminar.
- Al guardar: `PUT /api/core/usuario/profile` con el array de redes actualizado.

> Los tipos de redes sociales disponibles deben venir de una lista configurable (idealmente desde el backend). Para MVP: LinkedIn, Twitter/X, sitio web personal.

### CA-08 · Panel "Actividad Social-Financiera"

- En esta fase: empty state con ícono gris de documento + texto `"No hay publicaciones recientes en el ecosistema."`.
- Visible solo para usuarios autenticados (propio perfil o perfil ajeno con sesión activa).
- Sin funcionalidad real. El panel existe pero no carga datos. Marcado como `⬜ Futuro`.

### CA-09 · Cambio de contraseña

- Botón / link `"Cambiar contraseña"` en la tarjeta de Información General o en una sección separada.
- Abre un formulario inline o modal con 3 campos:
  - Contraseña actual (`type="password"` + toggle `👁`).
  - Nueva contraseña (`type="password"` + toggle `👁` + medidor de fortaleza de 4 niveles).
  - Confirmar nueva contraseña (`type="password"` + toggle `👁`).
- Validaciones: nueva contraseña ≥ 8 chars, 1 mayúscula, 1 número. Confirmar debe coincidir.
- Al guardar: llamada al endpoint de cambio de contraseña del backend (endpoint por confirmar con ms-auth).
- Si la contraseña actual es incorrecta: error inline `"Contraseña actual incorrecta."`.
- Al éxito: cerrar formulario + toast `"Contraseña actualizada correctamente."`.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **Nombre actualizado no se refleja en el sidebar** | El Signal `user` en `SessionService` debe ser actualizado inmediatamente al guardar. El sidebar consume `session.user()` reactivamente y se actualiza sin recarga. |
| EB-02 | **Upload de imagen grande** | El presigned URL de MinIO puede expirar si la subida tarda demasiado. Definir TTL mínimo de la URL firmada con el equipo backend (sugerido: 5 minutos). |
| EB-03 | **Username en la URL del perfil público** | Si el usuario no tiene username asignado aún, ¿la URL de perfil público es `/u/{id}` como fallback? Confirmar con backend. |
| EB-04 | **Campo de dirección** | El spec lo describe como "campo de texto libre". ¿Es una sola línea de dirección personal (diferente al modelo de dirección de org con calle/número/comuna)? Confirmar con backend. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- El perfil público (`/usuario/u/{username}`) puede ser accedido sin sesión. El MFE debe manejar el estado de "sin sesión" mostrando solo los campos públicos — sin depender de `SessionService` para cargar el perfil de otro usuario.
- El `SessionService.setSession` debe aceptar una actualización parcial del usuario para el caso de edición de perfil (sin reemplazar el objeto completo).
- El upload a MinIO no debe incluir `withCredentials: true` (URL externa). El `credentialsInterceptor` de HU-14 ya maneja este caso comparando el hostname.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 3 — mfe-gestion-usuario*
