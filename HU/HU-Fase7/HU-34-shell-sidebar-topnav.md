# HU-34 — Shell: Sidebar + Top-Navbar + Navegación Global

> **Fase**: 7 — `seis-portal` (Shell) | **Ruta**: layout raíz del portal | **Rol**: todos los usuarios autenticados

---

## Historias de Usuario

- **`US-SH01`** — Como usuario, quiero colapsar el sidebar para ganar espacio en pantalla al trabajar con contenido denso.
- **`US-SH02`** — Como usuario, quiero navegar entre módulos desde el sidebar con un máximo de 2 clics, para no perderme en la navegación.
- **`US-SH03`** — Como usuario con múltiples organizaciones, quiero cambiar la organización activa desde la top-navbar, para operar en el contexto correcto sin cerrar sesión.
- **`US-SH04`** — Como usuario, quiero que todos los MFEs reflejen automáticamente el cambio de organización activa, para no recibir datos de una organización incorrecta.
- **`US-SH05`** — Como usuario en mobile, quiero navegar desde la barra inferior sin que el sidebar ocupe espacio en pantalla pequeña.
- **`US-SH06`** — Como usuario en desktop, quiero cerrar sesión desde el bloque de perfil en la parte inferior del sidebar.
- **`US-SH07`** — Como usuario en mobile, quiero cerrar sesión desde mi página de perfil.

---

## Contexto técnico

El Shell (`seis-portal`, puerto 8083) define el layout global del portal: sidebar lateral, top-navbar y área de contenido principal donde se montan los MFEs. No tiene lógica de negocio propia — es el contenedor de navegación y estado global compartido.

**State global compartido** (accesible por todos los MFEs vía `SessionService` del `shared-utils`):

| Señal | Tipo | Cuándo se actualiza |
|-------|------|---------------------|
| `currentUser` | `User` | Al iniciar sesión y al cambiar datos de perfil |
| `activeOrganizationId` | `string` | Al cambiar la selección en el `OrganizationSelector` |
| `activeOrganizationName` | `string` | Al cambiar la selección |
| `unreadNotificationsCount` | `number` | En tiempo real vía WebSocket |

- Ningún MFE deriva el usuario o la organización de otra fuente que no sea `SessionService`.
- Al cambiar `activeOrganizationId`, todos los MFEs activos deben reaccionar y recargar sus datos con el nuevo contexto (escuchando el signal reactivo).

---

## Criterios de Aceptación

### CA-01 · Layout raíz del portal

```
┌─────────────────────────────────────────────────┐
│  SIDEBAR  │  TOP-NAVBAR (sticky)                │
│           │─────────────────────────────────────│
│           │                                     │
│           │   ÁREA DE CONTENIDO (MFE)           │
│           │                                     │
└─────────────────────────────────────────────────┘
```

- El sidebar ocupa el lado izquierdo a altura completa (`100vh`).
- La top-navbar es `position: sticky; top: 0` dentro del área de contenido principal.
- El contenido del MFE activo se renderiza bajo la top-navbar.
- En `xs–md`: sidebar oculto, reemplazado por barra inferior (CA-06).

### CA-02 · Sidebar — Estructura

El sidebar contiene, de arriba hacia abajo:
1. **Encabezado**: nombre/logo de la app + botón de colapso `SidebarToggleButton`.
2. **Menú de navegación** `SidebarNavMenu`: lista de ítems de 2 niveles.
3. **Bloque de usuario** `SidebarUserBlock` (solo visible en modo expandido, solo en `md+`).

**Menú de 2 niveles:**
- **Nivel 1** (`SidebarNavItem`): ítem con ícono. Puede tener o no subniveles.
  - Sin subniveles: clic navega directamente al path.
  - Con subniveles: clic expande/colapsa los subniveles en línea.
- **Nivel 2** (`SidebarNavSubItem`): sin ícono, con path. Clic navega directamente.
- El ítem activo (o el padre del subnivel activo) tiene estado visual destacado.

**Modo colapsado** (solo ícono):
- El sidebar muestra únicamente los íconos de nivel 1.
- Hover o clic en un ítem con subniveles: despliega un **flyout** lateral con los subniveles.
- Hover o clic en un ítem sin subniveles: navega directamente.
- El nombre de la app en el encabezado se oculta (solo logo).
- El `SidebarUserBlock` se oculta completamente en modo colapsado.

**Menú de navegación por rol:**

| Rol | Ítems de nivel 1 |
|-----|-----------------|
| Cedente | Mis Facturas (`/publicador`), Dashboard (`/dashboard`) |
| Ejecutivo | Marketplace (`/ofertador`), Mis Ofertas (`/dashboard/mis-ofertas`), Dashboard (`/dashboard`) |

### CA-03 · Top-Navbar

```
┌─────────────────────────────────────────────────────────────┐
│  [🏢]  Constructora ABC S.A.  ▾          [🔔]  [👤]        │
└─────────────────────────────────────────────────────────────┘
  ← OrganizationSelector ──────────→  ← acciones rápidas ──→
```

- **Lado izquierdo**: `OrganizationSelector` (instancia del `SearchableCardSelect` — ver HU-35). Muestra el nombre de la organización activa con ícono de edificio.
- **Lado derecho**: `NotificationsButton` (🔔, con badge — ver HU-36) + `ProfileQuickAccessButton` (👤, navega a `/perfil`). Espacio reservado para botones futuros.
- Sticky en la parte superior del área de contenido, debajo del sidebar en `lg+`.

### CA-04 · Bloque de usuario (`SidebarUserBlock`)

Visible **solo en modo sidebar expandido** y **solo en `md+`**.

Muestra:
- Avatar circular del usuario (o iniciales si no hay imagen).
- Nombre completo.
- Correo electrónico.
- Al hacer clic: se abre un **popover** `SidebarUserMenu` con opciones:
  1. `"Ver perfil"` → navega a `/perfil`.
  2. `"Configuración"` → navega a `/configuracion` (si aplica al MVP).
  3. Separador visual.
  4. `"Cerrar sesión"` en `--color-error` (rojo).

**Flujo de cierre de sesión:**
1. El usuario hace clic en `"Cerrar sesión"`.
2. `POST /api/auth/logout` — invalida el token en el backend y limpia las cookies `auth.session` + `auth.refresh`.
3. El `SessionService` limpia el state global.
4. Redirección a `app-login` (puerto 8082 / URL del login).
- Si el `POST` falla: mostrar toast de error y mantener la sesión activa.

### CA-05 · Responsivo — Top-Navbar en `xs–md`

En pantallas `xs–md` la top-navbar se expande a **2 filas**:
- **Fila 1**: `OrganizationSelector` a ancho completo.
- **Fila 2**: botones de acción rápida (`🔔` y `👤`) centrados horizontalmente. Área de toque ≥ 44×44px.

### CA-06 · Responsivo — Bottom Nav Bar (`xs–md`)

En pantallas `xs–md`:
- El sidebar lateral desaparece completamente.
- Se muestra una **barra de navegación inferior** `BottomNavBar` fija en la parte baja de la pantalla.
- La barra muestra los ítems de nivel 1 del menú como **iconos** únicamente (sin etiquetas).
- Al tocar un ítem **sin subniveles**: navega directamente.
- Al tocar un ítem **con subniveles**: despliega un **panel hacia arriba** `BottomNavSubMenu` (bottom sheet o menú emergente) con los subniveles como lista con ícono + etiqueta.
- El ítem activo tiene estado visual destacado en la barra.
- El `SidebarUserBlock` **no se renderiza** en `xs–md`.

### CA-07 · Cambio de organización activa

Al seleccionar una organización diferente en el `OrganizationSelector`:
1. `activeOrganizationId` y `activeOrganizationName` en el `SessionService` se actualizan.
2. Todos los MFEs activos escuchan el signal y recargan sus datos con el nuevo `activeOrganizationId`.
3. El MFE activo puede mostrar un estado de carga transitorio mientras recarga.
4. La selección persiste en la sesión (no se reinicia al navegar entre MFEs).

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **El usuario solo tiene una organización** | El `OrganizationSelector` se muestra igualmente pero el panel de selección tiene un solo ítem. No se oculta — mantiene consistencia visual y permite futura expansión. |
| EB-02 | **El usuario no tiene ninguna organización** | `NoOrganizationGate` (HU-38 / post-registro): se muestra una pantalla intermedia antes del portal. El layout normal del shell no se renderiza. |
| EB-03 | **El sidebar está colapsado y el usuario navega por URL directa** | El ítem padre del subnivel activo recibe el estado destacado en el ícono. El flyout no se abre automáticamente. |
| EB-04 | **Cierre de sesión falla por error de red** | Toast de error `"No se pudo cerrar la sesión. Intenta nuevamente."`. La sesión permanece activa. No limpiar el state global ni redirigir. |

---

## Componentes

| Componente | Descripción |
|------------|-------------|
| `PortalShellComponent` | Componente raíz del layout global |
| `AppSidebarComponent` | Sidebar colapsable con encabezado, menú y bloque de usuario |
| `SidebarToggleButtonComponent` | Botón de colapso/despliegue |
| `SidebarNavMenuComponent` | Menú de 2 niveles, configurado por rol |
| `SidebarNavItemComponent` | Ítem de nivel 1 (con ícono, con o sin subniveles) |
| `SidebarNavSubItemComponent` | Ítem de nivel 2 (sin ícono, con path) |
| `SidebarUserBlockComponent` | Bloque avatar + nombre + correo (solo `md+` expandido) |
| `SidebarUserMenuComponent` | Popover con opciones: Ver perfil / Configuración / Cerrar sesión |
| `TopNavbarComponent` | Barra superior fija del área de contenido |
| `ProfileQuickAccessButtonComponent` | Botón 👤 de acceso rápido al perfil |
| `BottomNavBarComponent` | Barra inferior de navegación para `xs–md` |
| `BottomNavSubMenuComponent` | Panel emergente hacia arriba con subniveles |

> `OrganizationSelector` y `NotificationsButton` son componentes de la top-navbar documentados en HU-35 y HU-36 respectivamente.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 7 — seis-portal (Shell)*
