# HU-21 — Gestor de Organización (Administración Interna)

---

## Historia de Usuario

**Yo como** usuario con rol `admin` dentro de una organización,
**Quiero** administrar los miembros, grupos de trabajo y configuración de mi organización desde un panel centralizado,
**Para** mantener el control operativo de mi equipo y los datos institucionales sin depender de soporte.

---

## Contexto técnico

Esta pantalla vive en `mfe-gestion-usuario` bajo la ruta `/usuario/organizaciones/:id/gestor`. Es la vista de administración interna — separada del perfil público de la organización (§9.4 / HU-20).

El Shell muestra esta ruta solo si el usuario autenticado tiene rol `admin` dentro de la organización. Si un `miembro` intenta navegar directamente a la URL, recibe un error 403 o es redirigido al perfil de la org.

Endpoints base: todos bajo `/api/core/organizacion/:id/`

---

## Criterios de Aceptación

### CA-01 · Estructura de la página

```
┌─────────────────────────────────────────────────────────────┐
│  [← Volver al perfil]     Gestionar: Razón Social S.A.     │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│  [ Miembros ]   [ Grupos de trabajo ]   [ Configuración ]  │
└─────────────────────────────────────────────────────────────┘
│  [contenido de la pestaña activa]                          │
```

- Enlace `"← Volver al perfil"` navega a `/usuario/organizaciones/:id`.
- El título muestra la razón social de la organización.
- Tres pestañas. La pestaña activa se determina por el hash de la URL (ej. `/gestor#miembros`, `/gestor#grupos`, `/gestor#configuracion`). Por defecto: `#miembros`.
- **Guard de acceso**: si `session().user.rolEnOrg !== 'admin'`, redirigir al perfil de la org con toast `"Acceso restringido a administradores."`.

### CA-02 · Pestaña Miembros — Sub-sección: Miembros activos

```
┌──────────────────────────────────────────────────────────────┐
│  Miembros activos (N)             [ Invitar ] [ + Crear ]   │
├───────────┬──────────────────┬─────────────────┬────────────┤
│  [avatar] │  Nombre Apellido │  admin  [👑]    │  [···]     │
│  [avatar] │  Nombre Apellido │  miembro         │  [···]     │
└───────────┴──────────────────┴─────────────────┴────────────┘
```

- **Lista de miembros activos**: avatar, nombre completo, rol (`miembro` / `admin`), badge `👑` para el creador de la organización.
- Al hacer clic en nombre o avatar: navega al perfil público del usuario (nueva pestaña o drawer lateral).
- **Menú `[···]`** por fila (ver CA-03 para reglas de negocio):
  - `"Promover a admin"` — visible si el miembro tiene rol `miembro`.
  - `"Degradar a miembro"` — visible si el miembro tiene rol `admin`.
  - `"Remover de la organización"` — disponible para todos excepto el creador `👑`.
- La fila del creador `👑` no tiene menú de acciones (o el menú aparece sin opciones destructivas).

### CA-03 · Reglas de negocio — Gestión de roles y membresías

| Acción | Condición para permitir |
|--------|------------------------|
| Promover a admin | El usuario tiene rol `miembro`. No hay restricción de número máximo de admins. |
| Degradar a miembro | El usuario tiene rol `admin` **Y** quedará al menos 1 admin activo después de la degradación. Bloquear si solo hay 1 admin. |
| Remover de la organización | El usuario no es el creador `👑`. Al remover: abre confirmación con campo de motivo opcional. El usuario removido recibe notificación in-app + email. |
| Cualquier acción sobre el creador | **Bloqueada**. El creador `👑` no puede ser removido ni degradado por ningún otro admin. |

- Todas las acciones de cambio de rol y remoción requieren confirmación con un modal o panel inline con descripción de la acción.

### CA-04 · Pestaña Miembros — Sub-sección: Solicitudes pendientes

```
┌──────────────────────────────────────────────────────────────┐
│  Solicitudes pendientes (N)                                  │
├───────────┬────────────────────────┬─────────────────────────┤
│  [avatar] │  Nombre Apellido       │  [ Aprobar ] [Rechazar] │
│           │  Hace X horas/días     │                         │
└───────────┴────────────────────────┴─────────────────────────┘
```

- Si no hay solicitudes: empty state `"No hay solicitudes pendientes."`.
- Al hacer clic en nombre/avatar: abre el perfil público del solicitante para evaluarlo antes de decidir.
- **Aprobar**: llama a `POST /api/core/organizacion/:id/miembro/solicitud/:solicitudId/aprobar` → el solicitante se convierte en `OrganizationMember` activo → notificación al usuario aprobado.
- **Rechazar**: despliega un campo de motivo opcional inline → CTA `"Confirmar rechazo"` → llama a `POST /api/core/organizacion/:id/miembro/solicitud/:solicitudId/rechazar` con el motivo → notificación al usuario rechazado. Re-solicitud bloqueada por 30 días.

### CA-05 · Pestaña Miembros — Sub-sección: Invitaciones enviadas

```
┌──────────────────────────────────────────────────────────────┐
│  Invitaciones enviadas (N)                   [ + Invitar ]  │
├─────────────────┬───────────────┬───────────────┬───────────┤
│  email@ejemplo  │  Enviada ayer │  Expira en X  │ [Reenviar]│
│                 │               │  días         │ [Revocar] │
└─────────────────┴───────────────┴───────────────┴───────────┘
```

- Si no hay invitaciones: empty state `"No hay invitaciones pendientes."`.
- **`[ + Invitar ]`**: abre un formulario inline sobre la tabla:
  - Campo de email.
  - Botón `"Enviar invitación"`.
  - Validación: email válido + no debe ser un miembro activo ya.
  - Endpoint: `POST /api/core/organizacion/:id/invitacion` con `{email}`.
  - El backend envía un email con un enlace de invitación que expira en 7 días.
  - Si el email no tiene cuenta, el enlace redirige al registro pre-vinculado.
- **Reenviar**: `POST /api/core/organizacion/:id/invitacion/:invId/reenviar` → nueva fecha de expiración (7 días desde ahora).
- **Revocar**: `DELETE /api/core/organizacion/:id/invitacion/:invId` → confirmación inline. Si el usuario intenta usar el enlace después de revocar, ve un error con CTA para solicitar nueva invitación.

### CA-06 · Modal "Crear usuario directamente" — Flujo C

Al hacer clic en `[ + Crear ]`:

```
┌────────────────────────────────────────────────────────────┐
│  Crear nuevo usuario                                  [✕]  │
│  ──────────────────────────────────────────────────────   │
│  Nombre       [ ________________________ ]                 │
│  Apellido     [ ________________________ ]                 │
│  Correo       [ ________________________ ]                 │
│                                                            │
│  El usuario recibirá un correo para establecer             │
│  su contraseña. El enlace expira en 48 horas.              │
│                                                            │
│  [ Cancelar ]                    [ Crear usuario ]         │
└────────────────────────────────────────────────────────────┘
```

- Validaciones: nombre y apellido no vacíos, email con formato válido.
- Endpoint: `POST /api/auth/security/crear-usuario` (o el endpoint equivalente en ms-auth) → crea usuario en la plataforma + envía email de activación → al activar, queda como miembro activo de la organización.
- Al éxito: modal se cierra + la lista de invitaciones o miembros se actualiza.

### CA-07 · Pestaña Grupos de Trabajo

```
┌──────────────────────────────────────────────────────────────┐
│  Grupos de trabajo (N)                    [ + Nuevo grupo ]  │
├──────────────────────────────────────────────────────────────┤
│  ▾ [Nombre Grupo]               [ Editar ]  [ Eliminar ]    │
│    Líder: [Nombre Líder]                                     │
│    Miembros: [Nombre] · [Nombre] · [Nombre]  (N)            │
├──────────────────────────────────────────────────────────────┤
│  ▸ [Nombre Grupo 2]             [ Editar ]  [ Eliminar ]    │
└──────────────────────────────────────────────────────────────┘
```

- Acordeones expandibles. Colapsado: nombre del grupo, líder, conteo de miembros.
- **`+ Nuevo grupo`** y **Editar**: abre el `WorkgroupFormModal` (CA-08).
- **Eliminar**:
  - Si el grupo tiene miembros: confirmación con aviso `"Al eliminar este grupo, X miembros recibirán una notificación."`.
  - Si el grupo está vacío: confirmación simple.
  - Endpoint: `DELETE /api/core/organizacion/:id/grupo/:grupoId`.
- Un miembro puede pertenecer a múltiples grupos simultáneamente.

### CA-08 · Modal de grupo (Crear / Editar)

```
┌────────────────────────────────────────────────────────────┐
│  [Crear / Editar] grupo de trabajo                   [✕]  │
│  ──────────────────────────────────────────────────────   │
│  Nombre del grupo  [ ________________________ ]           │
│                                                            │
│  Líder             [ SearchableCardSelect ▼ ]             │
│                    [Buscar por nombre...]                  │
│                    [● Ana García]  [● Luis Mora]           │
│                                                            │
│  Miembros          [ Selección múltiple ▼ ]               │
│                    [Buscar por nombre...]                  │
│                    [ ✓ Ana ]  [ ✓ Luis ]  [   María ]      │
│                                                            │
│  [ Cancelar ]                    [ Guardar ]               │
└────────────────────────────────────────────────────────────┘
```

- **Nombre del grupo**: texto, requerido, máximo 100 caracteres.
- **Líder**: `SearchableCardSelect` sobre los miembros activos de la org. Requerido. Muestra avatar + nombre + cargo.
- **Miembros**: selección múltiple sobre los miembros activos de la org. Muestra avatares con checkbox. El líder puede o no estar también en la lista de miembros.
- Al crear: `POST /api/core/organizacion/:id/grupo` con `{nombre, liderId, miembrosIds[]}`.
- Al editar: `PATCH /api/core/organizacion/:id/grupo/:grupoId` con los campos modificados.

### CA-09 · Pestaña Configuración

**Tarjeta: Información de la organización**
- Campos editables: razón social, descripción, logo, banner, links del ecosistema digital.
- Los campos de logo y banner usan el mismo flujo de presigned URL que HU-20 CA-08.
- Al guardar razón social: `SessionService` actualiza el nombre de la org activa → el `OrganizationSelector` del top-navbar refleja el cambio en tiempo real.
- Endpoint: `PATCH /api/core/organizacion/:id`.

**Tarjeta: Acceso por código**
- Muestra el código actual de 8 caracteres (formato `XXXX-XXXX`).
- Botón `"Rotar código"`:
  - Confirmación inline: `"El código anterior quedará inválido de inmediato."` + CTA `"Rotar"` / `"Cancelar"`.
  - Endpoint: `POST /api/core/organizacion/:id/rotar-codigo`.
  - Al éxito: nuevo código mostrado en la tarjeta.

**Tarjeta: Zona de riesgo** *(visible solo para el creador `👑`)*
- Botón `"Desactivar organización"` en rojo.
- Al hacer clic: modal de confirmación destructiva:
  - Texto de advertencia: `"Esta acción es irreversible. Todos los miembros perderán el acceso. Las operaciones en curso no se cancelarán automáticamente."`.
  - Campo de texto: `"Escribe el nombre exacto de la organización para confirmar."`.
  - El botón `"Desactivar"` se habilita solo cuando el texto coincide exactamente con la razón social.
  - Endpoint: `DELETE /api/core/organizacion/:id` (o `PATCH` con `{estado: 'INACTIVA'}`).
  - Al éxito: logout del usuario de la org activa + redirect al listado de organizaciones del usuario.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **El último admin intenta degradarse a sí mismo** | Bloquear con mensaje inline `"No puedes degradarte. Debes haber al menos un administrador activo. Promueve a otro miembro primero."` |
| EB-02 | **Invitar a un email que ya es miembro activo** | Validar en frontend antes de llamar al backend. Mostrar `"Este correo ya pertenece a un miembro activo de la organización."` |
| EB-03 | **Org sin miembros en un grupo** | El modal de edición del grupo permite guardar sin miembros. El grupo queda vacío (solo tiene líder). Válido. |
| EB-04 | **Admin accede al gestor desde la URL pero ya fue degradado a miembro** | El guard verifica el rol al cargar la página. Si el rol cambió desde la última carga (ej. otro admin lo degradó), la verificación debe hacerse contra el backend, no solo desde `SessionService`. |
| EB-05 | **Usuario invitado por email no tiene cuenta en la plataforma** | El enlace de invitación debe incluir un parámetro para pre-vincular el registro a la organización. Confirmar con ms-auth cómo manejar el flow de registro + activación de membresía. |
| EB-06 | **Desactivación de org con operaciones abiertas** | La spec dice "no se cancelan automáticamente". El modal de confirmación debe reflejar esto con un aviso explícito. El equipo de negocio debe definir si se muestra el número de operaciones abiertas. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- Las 3 pestañas comparten el mismo contexto de organización (`:id` en la URL). Usar un `OrgManagerStateService` local al MFE que cargue los datos de la org una sola vez y los comparta entre las pestañas, para evitar N peticiones duplicadas.
- El `SearchableCardSelect` en el modal de grupos es el mismo componente descrito en §3.1 del spec. Debe vivir en `shared-utils`. Si aún no está disponible en esta fase, el equipo debe decidir entre: (a) implementarlo aquí y moverlo luego, o (b) esperar la Fase 7 y usar un select nativo temporal.
- El guard de acceso al Gestor debe llamar a `GET /api/core/organizacion/:id/mi-rol` o confiar en `SessionService.session().user.rolEnOrg` (que debe ser actualizado cuando el usuario navega entre orgs). Confirmar con el equipo qué fuente es la de verdad.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 3 — mfe-gestion-usuario*
