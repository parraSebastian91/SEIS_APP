# HU-20 — Perfil de Organización (Vista Institucional)

---

## Historia de Usuario

**Yo como** usuario autenticado,
**Quiero** ver el perfil institucional de una organización (mis datos legales, grupos de trabajo, colaboradores y presencia digital),
**Para** tener visibilidad completa del perfil de mi empresa y que otros usuarios puedan conocer su estructura operativa.

---

## Contexto técnico

Esta pantalla vive en `mfe-gestion-usuario` bajo la ruta `/usuario/organizaciones/:id`. Se accede desde:
- El selector de organizaciones del top-navbar (la org actualmente seleccionada).
- Cualquier enlace a un perfil de organización desde otros contextos de la plataforma.

La pantalla es **pública** — un usuario sin sesión puede ver el perfil de una organización, con la misma restricción que el perfil de usuario (sin datos privados).

Endpoints:
- `GET /api/core/organizacion/:id` — datos de la organización
- `GET /api/core/organizacion/:id/grupos` — lista de grupos de trabajo con líder y miembros
- `PATCH /api/core/organizacion/:id` — actualizar descripción / links del ecosistema digital (solo admins)
- `PATCH /api/core/organizacion/:id/grupo/:grupoId/lider` — reasignar líder de un grupo (solo admins)

---

## Criterios de Aceptación

### CA-01 · Layout de la página

```
[ Banner corporativo ancho completo ]
  [logo]  Razón Social S.A.
          [badge: CEDENTE / FINANCIERA]
          [botón Gestionar organización — visible solo para admins]

[ Bloque de descripción institucional — ancho completo ]

[ Columna 1/3 ]              [ Columna 2/3 ]
  Tarjeta: Datos              Panel: Grupos de trabajo y
  de la Empresa               Colaboradores
  ──────────────
  Tarjeta: Ecosistema
  Digital

[ Panel: Publicaciones — ancho completo — No MVP ]
```

- En `xs–md`: layout de columna única. Los paneles se apilan verticalmente: Datos empresa → Ecosistema Digital → Grupos de trabajo → Publicaciones.
- En `lg+`: layout de dos columnas como el diagrama.

### CA-02 · Cabecera corporativa

- **Banner**: imagen institucional a ancho completo. Si no hay imagen cargada: fondo con gradiente corporativo (azul/gris). Altura mínima: 200px.
- **Logo**: imagen circular o cuadrada con bordes redondeados, superpuesta al borde inferior izquierdo del banner. Placeholder: siglas de la razón social si no hay logo.
- **Razón social** en tipografía H1.
- **Badge de tipo**: chip con el texto del `tipoOrganizacion` (`CEDENTE` / `FINANCIERA` / `BROKER`). Colores diferenciados por tipo.
- **Botón de edición de banner** (ícono de cámara `📷` en la esquina superior izquierda del banner): visible solo para admins de la organización.
- **Botón `"Gestionar organización"`**: posicionado en la esquina superior derecha del banner. Visible solo para usuarios con rol `admin` dentro de la org. Navega a `/usuario/organizaciones/:id/gestor`.

### CA-03 · Bloque de descripción institucional

- Bloque de texto libre, ancho completo, debajo del banner.
- Muestra el texto de presentación de la empresa (misión, descripción del negocio, etc.).
- **Admin**: hover sobre el bloque muestra ícono de lápiz `✏` en la esquina superior derecha. Al clicar: convierte el bloque en un `textarea` editable con CTA `"Guardar"` / `"Cancelar"`.
- **No admin / sin sesión**: solo lectura.
- **Empty state** (si no hay descripción y el usuario es admin): bloque con borde punteado + texto `"Agrega una descripción para presentar tu organización."` + botón `"Agregar descripción"`.
- **Empty state** (para no admins): el bloque no se renderiza — no mostrar espacio vacío.

### CA-04 · Tarjeta "Datos de la Empresa"

| Ícono | Campo | Fuente |
|-------|-------|--------|
| 🪪 | RUT con formato `XX.XXX.XXX-X` | `Organization.rut` |
| 💼 | Razón social completa | `Organization.razonSocial` |
| 📍 | Dirección comercial | Primera dirección de tipo `TRIBUTARIA` o `CASA_MATRIZ` |

- Solo lectura — los datos legales no se editan desde esta vista (la edición de razón social, RUT y direcciones está en el Gestor §9.5 pestaña Configuración).

### CA-05 · Tarjeta "Ecosistema Digital"

- Lista de chips/botones con ícono de la plataforma y texto del link (ej. `[🔗 LinkedIn]`, `[🌐 Sitio web]`).
- Cada chip es clicable y abre el link en una nueva pestaña.
- **Admin**: botón `"+ Agregar link"` al final de la lista. Abre un inline form:
  - Select: tipo de link (LinkedIn, Twitter/X, sitio web, otro).
  - Input: URL.
  - Validación: URL debe comenzar con `https://`.
  - Al guardar: `PATCH /api/core/organizacion/:id` con el array de links actualizado.
- **Admin**: hacer clic en un chip existente muestra opciones `"Editar URL"` / `"Eliminar"`.

### CA-06 · Panel "Grupos de Trabajo y Colaboradores"

Cada grupo se renderiza como un acordeón expandible:

**Estado colapsado:**
```
▸ [Nombre del Grupo]   · [N miembros]
```

**Estado expandido:**
```
▾ [Nombre del Grupo]
  ┌──────────────────────────────────────────────────────┐
  │  [avatar]  Juan Pérez  — Líder de Grupo  [👑]       │
  │            [Cargo del líder]                         │
  │  [Admin → campo SearchableCardSelect para cambio]    │
  └──────────────────────────────────────────────────────┘
  [ Ana García ] [ Luis Mora ] [ María Sun ] [ +2 más ]
```

- La tarjeta del líder tiene fondo visualmente diferenciado y badge `👑`.
- **Admin**: junto a la tarjeta del líder, aparece un enlace/botón `"Cambiar líder"` que despliega un `SearchableCardSelect` con los colaboradores activos de la organización. Al seleccionar → `PATCH /api/core/organizacion/:id/grupo/:grupoId/lider`.
- Los miembros se muestran como avatares con nombre y cargo en formato grid. Si hay más de 6, mostrar `"+ N más"` con opción de expandir.
- Hacer clic en el nombre/avatar de un miembro o del líder navega al perfil público de ese usuario.
- **Admin**: botón `"Gestionar grupos"` que navega al Gestor (§9.5 pestaña Grupos) para CRUD completo.
- Si no hay grupos: empty state `"Esta organización aún no tiene grupos de trabajo."` (con CTA para admins).

### CA-07 · Panel "Publicaciones" — No MVP

- Renderizado al final de la página, ancho completo.
- Estado actual: icono de documento gris + texto `"No hay publicaciones de esta organización."`.
- Sin funcionalidad real. Marcado visualmente en el código con comentario `// TODO: MVP siguiente fase`.

### CA-08 · Upload de banner y logo (admins)

- Al hacer clic en el botón de cámara del banner: input `type="file"`, acepta `image/*`, máximo 5 MB.
- Subida vía presigned URL:
  1. `GET /api/core/object/presigned-url/ORG_BANNER` (con `orgId` como param)
  2. `PUT {presignedUrl}` con el archivo (sin `withCredentials` — URL externa a la app).
  3. `PATCH /api/core/organizacion/:id` con `bannerUrl`.
- Misma mecánica para el logo (`objectType = ORG_LOGO`).
- Mientras sube: overlay de progreso sobre el banner/logo.

### CA-09 · Comportamiento según nivel de sesión

| Sección | Sin sesión | Miembro / externo | Admin de la org |
|---------|:----------:|:-----------------:|:---------------:|
| Banner, logo, razón social, badge | ✅ | ✅ | ✅ |
| Descripción institucional | ✅ | ✅ | ✅ + editar |
| Datos de la empresa | ✅ | ✅ | ✅ |
| Ecosistema Digital | ✅ | ✅ | ✅ + CRUD |
| Grupos de trabajo y colaboradores | ✅ | ✅ | ✅ + cambiar líder |
| Publicaciones | ✅ (empty) | ✅ (empty) | ✅ (empty) |
| Botón "Gestionar organización" | ❌ | ❌ | ✅ |
| Botón de cámara para editar banner/logo | ❌ | ❌ | ✅ |

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **Organización sin grupos** | Mostrar empty state en el panel de grupos con texto descriptivo. Para admins, CTA que lleva al Gestor para crear el primer grupo. |
| EB-02 | **`SearchableCardSelect` para cambiar líder** | El selector debe filtrar sobre los miembros activos de la org (no sobre todos los usuarios de la plataforma). La llamada al backend para obtener candidatos debe ser `GET /api/core/organizacion/:id/miembros`. |
| EB-03 | **Org con muchos grupos (>20)** | El acordeón de grupos debe hacer scroll interno o paginación. No cargar todos los grupos al mismo tiempo. |
| EB-04 | **Badge de tipo: `BROKER`** | El sistema tiene el rol pero el badge de `BROKER` no estaba descrito en §9.4. Usar el mismo estilo de chip con color diferenciado (ej. verde). Confirmar con diseño. |
| EB-05 | **Dirección de org no registrada** | Si la organización fue creada pero aún no tiene dirección (caso raro post-wizard), la tarjeta de Datos debe mostrar `"Dirección no registrada."` en lugar de un espacio vacío. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- Esta pantalla tiene doble función: es el perfil público de la org Y el panel de gestión ligera (cambiar líder). El CRUD completo de grupos y configuración de org está en el Gestor (HU-21). Ambas rutas deben estar activas en el MFE.
- El componente `SearchableCardSelect` mencionado en §3.1 de la spec es transversal a toda la app. Aunque se necesita primero en HU-20, debe ser creado en `shared-utils` para que otros MFEs lo puedan usar. Considerar crear el componente como parte de la Fase 7 (Shell transversales) o como una dependencia explícita de esta HU.
- La ruta del perfil de org admite acceso sin sesión. El MFE debe verificar si `SessionService.session()` existe antes de mostrar los controles de admin, sin hacer redirect al login.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 3 — mfe-gestion-usuario*
