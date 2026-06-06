# Factor App — Definición de Producto

> Documento vivo. Actualizar a medida que el producto evoluciona.  
> Última actualización: 2026-06

---

## ⚙️ Parámetros configurables del producto

> El nombre de la aplicación está **pendiente de confirmación definitiva** — existen coincidencias de marca y puede cambiar en el corto plazo. Al renombrar, actualizar los tres parámetros siguientes y reemplazar sus valores en todo el documento.

| Parámetro | Valor actual | Descripción |
|-----------|:------------:|-------------|
| `APP_NAME` | `Factor` | Nombre de la aplicación (display, navbar, onboarding, mensajes legales) |
| `APP_DOMAIN` | `factor.cl` | Dominio base (URLs de perfil público, emails del sistema) |
| `APP_CODE_PREFIX` | `FACT` | Prefijo de 4 chars para el código de acceso rápido a organizaciones (ej. `FACT-X7K2`) |

**Ocurrencias a actualizar al renombrar:**
- Título del documento (`# {APP_NAME} App — Definición de Producto`)
- Navbar del portal: logo/nombre colapsado y expandido
- Pantalla de login: `Logo {APP_NAME}` en el panel de marca
- URL de perfil público: `{APP_DOMAIN}/u/{username}`
- Texto en mensajes SII y de error que mencionen operar "en {APP_NAME}"
- Tokens de diseño: `--{app}-brand-*` y referencias a "{APP_NAME} brand" en la paleta
- Código de acceso rápido: prefijo generado (`{APP_CODE_PREFIX}-XXXX`)

---

## 1. Visión General

Factor es una plataforma de factoring digital que conecta a **clientes** (empresas con facturas por cobrar) con **ejecutivos** (inversores individuales o representantes de financieras con capital disponible). El flujo central es: el cliente sube una factura → la valida y autoriza → ejecutivos hacen ofertas → cliente compara, negocia y acepta → financiamiento registrado.

---

## 2. Roles

### Roles de plataforma (base de datos)

Roles registrados en el sistema. Cada usuario tiene exactamente un rol de plataforma asignado.

| Nombre visible | Nombre interno (`enum`) | Descripción |
|----------------|------------------------|-------------|
| Super Administrador | `SUPER_ADMIN` | Acceso total al sistema. Solo para equipo técnico/operativo interno. |
| Administrador | `ADMIN` | Gestión general de la plataforma. Backoffice. |
| Usuario Estándar | `USR_STD` | Acceso operativo básico sin diferenciación de org. |
| Supervisor | `SUPERVISOR` | Supervisión de operaciones. Sin capacidad de modificación. |
| Solo Lectura | `READ_ONLY` | Acceso de auditoría. Sin escritura ni acción. |
| Cliente Cedente | `CLIENTE_CEDENTE` | Usuario de una org `CEDENTE`. Sube y gestiona facturas para financiamiento. |
| Ejecutivo Financiadora | `EJECUTIVO_FINANCIADORA` | Usuario de una org `FINANCIERA`. Evalúa facturas y realiza ofertas. |
| Administrador Financiadora | `ADMIN_FINANCIADORA` | Admin de una org `FINANCIERA`. Gestión interna de su organización. |
| Administrador Cedente | `ADMIN_CEDENTE` | Admin de una org `CEDENTE`. Gestión interna de su organización. |
| Ejecutivo Broker | `EJECUTIVO_BROKER` | Usuario de una org `BROKER`. Intermedia entre cedentes y financieras. ⬜ Post-MVP |
| Administrador Broker | `ADMIN_BROKER` | Admin de una org `BROKER`. Gestión interna de su organización. ⬜ Post-MVP |

> Los roles `*_BROKER` se agregan al enum ahora para no requerir migraciones posteriores, pero su comportamiento operacional se define post-MVP.

> **Estado actual en BFF (`bff_seis_app`)**: los guards activos son `USR_STD`, `CLIENTE_CEDENTE`, `ADMIN_CEDENTE`, `EJECUTIVO_FINANCIADORA`, `ADMIN_FINANCIADORA`, `SUPER_ADMIN`. Los roles `ADMIN`, `SUPERVISOR`, `READ_ONLY` y los `*_BROKER` no tienen endpoints protegidos en el BFF aún.

---

### Correspondencia rol → tipo de organización

| Rol | `tipoParticipacion` de la org | Acceso principal |
|-----|-------------------------------|-----------------|
| `CLIENTE_CEDENTE` | `CEDENTE` | `mfe-publicador` |
| `ADMIN_CEDENTE` | `CEDENTE` | `mfe-publicador` + Gestor de Org |
| `EJECUTIVO_FINANCIADORA` | `FINANCIERA` | `mfe-ofertador` |
| `ADMIN_FINANCIADORA` | `FINANCIERA` | `mfe-ofertador` + Gestor de Org |
| `EJECUTIVO_BROKER` | `BROKER` | Por definir (post-MVP) |
| `ADMIN_BROKER` | `BROKER` | Por definir (post-MVP) |
| `SUPER_ADMIN` / `ADMIN` / `SUPERVISOR` / `READ_ONLY` | — | Backoffice (fuera de scope del presente doc) |
| `USR_STD` | — | Por definir |

---

### Reglas de autenticación
- Login único con rol único asignado al perfil.
- Permite multi-dispositivo, pero **no sesiones simultáneas** en el mismo dispositivo.
- Permisos basados en rol y módulo.
- Registro y onboarding de organización por separado (pendiente de definir flujo completo).
- El rol de plataforma es distinto del rol dentro de la organización (`miembro` / `admin` — ver §9.3).

---

## 3. Arquitectura de Microfrontends

| Contenedor Docker | Nombre interno (MFE) | Tipo | Audiencia | Puerto | Estado |
|-------------------|---------------------|------|-----------|:------:|--------|
| `app_login` | `app-login` | App standalone | Anónimo | 8082 | ✅ Activo |
| `app_portal` | `shell` (Portal) | Shell app | Autenticado | 8083 | ✅ Activo |
| `app_mfe_gestion_usuario` | `mfe-gestion-usuario` | MFE | Todos | 8084 | 🔧 En desarrollo |
| `app_mfe_dashboard_facturas` | `mfe-dashboard-facturas` | MFE | Ambos | 8085 | ⬜ No iniciado |
| `app_mfe_publicador_facturas` | `mfe-publicador-facturas` | MFE | Cliente (`CEDENTE`) | 8086 | 🔧 En desarrollo |
| `app_mfe_ofertador_facturas` | `mfe-ofertador-facturas` | MFE | Ejecutivo (`FINANCIERA`) | 8087 | 🔧 En desarrollo |
| `factor_landing` | `factor-landing` | Next.js app | Público | 3010 | ✅ Activo |

> Todos los servicios están detrás de **Kong API Gateway** (`localhost:8000` en local). Las apps consumen las APIs a través de dos rutas Kong: `/api/auth` → ms-auth y `/api/core` → bff_seis_app.

> `mfe-gestion-usuario`: MFE dedicado a perfil de usuario, organizaciones y el Gestor de Org (§9.2, §9.3, §9.4, §9.5). Su alcance preciso se está definiendo.

### Shell — Portal (Layout raíz)

El shell se denomina **Portal**. Define el layout global que enmarca todos los MFEs: un sidebar izquierdo colapsable y una top-navbar flotante fija.

---

#### Sidebar izquierdo

```
┌─────────────────────┐         ┌──────┐
│  Factor        [◀]  │  ←→     │  F   │  ← colapsado (solo iconos)
├─────────────────────┤         ├──────┤
│  🏠  Inicio         │         │  🏠  │
│  📄  Publicador  ▾  │         │  📄  │
│      └ Mis facturas │         │  💼  │
│      └ Nueva        │         │  ...  │
│  💼  Ofertador   ▾  │         ├──────┤
│      └ Marketplace  │         │  👤  │
│  ...                │         └──────┘
├─────────────────────┤
│  [avatar]  Juan     │
│  Pérez García       │
│  juan@empresa.cl    │
└─────────────────────┘
```

**Encabezado del sidebar**
- Muestra el nombre de la aplicación: **"Factor"**.
- Botón adyacente que alterna entre modo expandido y colapsado.

**Menú de navegación (estructura de 2 niveles)**

| Nivel | Icono | Subniveles | Path de navegación |
|-------|:-----:|:----------:|-------------------|
| Nivel 1 sin subniveles | ✅ | ❌ | ✅ Tiene path directo |
| Nivel 1 con subniveles | ✅ | ✅ | ❌ Solo expande/colapsa el grupo |
| Nivel 2 (ítem de submódulo) | ❌ | ❌ | ✅ Tiene path directo |

- El menú soporta **múltiples secciones** (ej. "Principal", "Operaciones", "Configuración") y **múltiples módulos** dentro de cada sección.
- Al colapsar el sidebar, solo se muestran los iconos de nivel 1. Al hacer hover o clic sobre un ítem con subniveles, se despliega un tooltip/flyout con los subniveles.
- El ítem activo (ruta actual) tiene estado visual destacado.

** de usuario (parte inferior del sidebar, solo en modo expandido)**
- Avatar del usuario (imagen o iniciales).
- Nombre completo (nombre + apellidos).
- Correo electrónico.
- En modo colapsado esta sección se oculta; solo el avatar puede quedar visible como acceso al perfil.
- **Solo visible en `md+` (desktop)**. Oculto en `xs–md`.
- Al hacer clic sobre el bloque completo se abre un pequeño menú contextual (popover hacia arriba) con las siguientes opciones:
  - Ver perfil (navega a `/perfil`)
  - Configuración
  - — *(separador)*
  - **Cerrar sesión** (acción con color de alerta, ej. rojo/naranja)
- Al confirmar "Cerrar sesión": se invalida la sesión en el backend, se limpia el state global (`currentUser`, `activeOrganizationId`) y se redirige al login.

---

#### Top-navbar flotante (main)

Barra fija en la parte superior del área de contenido principal (`position: sticky top-0`). No forma parte del sidebar.

```
┌─────────────────────────────────────────────────────────────┐
│  [🏢]  Constructora ABC S.A.  ▾          [🔔]  [👤]        │
└─────────────────────────────────────────────────────────────┘
  ←── selector de organización ──→    ←── acciones rápidas ──→
```

**Lado izquierdo — Selector de organización**
- Ícono tipo edificio (`🏢`) que identifica visualmente la organización.
- Nombre de la organización actualmente seleccionada.
- Desplegable (dropdown) para cambiar entre las organizaciones asociadas al usuario.
- La organización seleccionada se almacena en el **state global compartido** del shell, accesible por todos los MFEs. Toda petición al backend debe incluir el ID de organización activa del estado global.

**Lado derecho — Acciones rápidas**
- **Botón de notificaciones** (`🔔`): abre el panel de notificaciones in-app. Badge con conteo de no leídas.
- **Botón de perfil** (`👤`): acceso directo al perfil y configuración del usuario.
- Espacio reservado para botones adicionales que se definirán en el futuro.

---

#### State global compartido entre MFEs

El shell expone un estado global que todos los MFEs consumen vía el mecanismo de Module Federation (shared service o evento de bus):

| Dato | Descripción | Cuándo se actualiza |
|------|-------------|---------------------|
| `currentUser` | ID, nombre, apellidos, correo, rol (`cliente` / `ejecutivo`), avatar | Al iniciar sesión y al cambiar datos de perfil |
| `activeOrganizationId` | ID de la organización seleccionada en el dropdown | Al cambiar la selección en la top-navbar |
| `activeOrganizationName` | Nombre de la organización activa | Al cambiar la selección |
| `unreadNotificationsCount` | Conteo de notificaciones no leídas | En tiempo real vía WebSocket |

- Ningún MFE debe derivar el usuario o la organización de otra fuente que no sea este state global.
- Al cambiar `activeOrganizationId`, todos los MFEs activos deben reaccionar y recargar sus datos con el nuevo contexto.

---

#### Modo responsivo — Mobile / Tablet

En pantallas `xs–md` el sidebar lateral desaparece y se reemplaza por una **barra de navegación inferior**:

```
┌─────────────────────────────────────────────────────┐
│                  [contenido]                        │
└─────────────────────────────────────────────────────┘
┌──────┬──────┬──────┬──────┬──────┐
│  🏠  │  📄  │  💼  │  ...  │  👤  │  ← bottom nav bar
└──────┴──────┴──────┴──────┴──────┘
```

- La bottom nav muestra **solo iconos** de los ítems de nivel 1.
- Al tocar un ítem **con subniveles**, se despliega un menú **hacia arriba** (bottom sheet o panel) con los subniveles en forma de lista con icono + etiqueta.
- Al tocar un ítem **sin subniveles**, navega directamente al path.
- La top-navbar flotante se simplifica en mobile: en pantallas `xs–md` pasa a **2 filas**:
  - **Fila 1**: selector de organización a ancho completo.
  - **Fila 2**: botones de acción rápida (notificaciones, perfil y futuros) centrados horizontalmente, con área de toque ≥ 44×44px para facilitar el acceso táctil.

---

#### Historias de usuario

- `US-SH01` — Como usuario, quiero colapsar el sidebar para ganar espacio en pantalla al trabajar con contenido denso.
- `US-SH02` — Como usuario, quiero navegar entre módulos desde el sidebar con un máximo de 2 clics, para no perderme en la navegación.
- `US-SH03` — Como usuario con múltiples organizaciones, quiero cambiar la organización activa desde la top-navbar, para operar en el contexto correcto sin cerrar sesión.
- `US-SH04` — Como usuario, quiero que todos los MFEs reflejen automáticamente el cambio de organización activa, para no recibir datos de una organización incorrecta.
- `US-SH05` — Como usuario en mobile, quiero navegar desde la barra inferior sin que el sidebar ocupe espacio en pantalla pequeña.
- `US-SH06` — Como usuario en desktop, quiero cerrar sesión desde el bloque de perfil en la parte inferior del sidebar, para salir de mi cuenta sin abandonar la navegación principal.
- `US-SH07` — Como usuario en mobile, quiero cerrar sesión desde mi página de perfil, para salir de mi cuenta desde un lugar accesible en pantallas pequeñas.

#### Criterios de aceptación

- [ ] Sidebar muestra: nombre de app + botón de colapso en el encabezado.
- [ ] Menú soporta 2 niveles: nivel 1 con icono (con o sin subniveles), nivel 2 sin icono con path.
- [ ] Modo colapsado: solo iconos visibles. Hover/clic en ítem con subniveles despliega flyout.
- [ ] Ítem activo tiene estado visual destacado en sidebar y bottom nav.
- [ ] Perfil de usuario (avatar, nombre, correo) visible en la parte inferior del sidebar solo en modo expandido.
- [ ] Top-navbar fija: selector de organización a la izquierda, acciones rápidas a la derecha.
- [ ] Al cambiar organización, el state global se actualiza y todos los MFEs recargan datos.
- [ ] Badge de notificaciones refleja conteo en tiempo real (WebSocket).
- [ ] En `xs–md`: sidebar oculto, bottom nav con iconos. Subniveles se despliegan hacia arriba.
- [ ] Top-navbar en `xs–md`: se expande a **2 filas**. Fila 1: selector de organización (ancho completo). Fila 2: botones de acción rápida centrados horizontalmente con área de toque ≥ 44×44px.
- [ ] `SidebarUserBlock` visible **solo en `md+`**. Al hacer clic muestra un popover con: Ver perfil, Configuración, separador, Cerrar sesión (color de alerta).
- [ ] Cerrar sesión desde sidebar: invalida token en backend, limpia state global y redirige al login.
- [ ] El bloque de logout del sidebar **no se renderiza** en `xs–md`.

#### Componentes

- `PortalShell` — Componente raíz del shell que define el layout global
- `AppSidebar` — Sidebar colapsable con encabezado, menú y bloque de usuario
- `SidebarToggleButton` — Botón de colapso/despliegue del sidebar
- `SidebarNavMenu` — Menú de 2 niveles con secciones configurables
- `SidebarNavItem` — Ítem de nivel 1 (con icono, con o sin subniveles)
- `SidebarNavSubItem` — Ítem de nivel 2 (sin icono, con path)
- `SidebarUserBlock` — Bloque de avatar, nombre y correo en la parte inferior
- `TopNavbar` — Barra flotante fija del área principal
- `OrganizationSelector` — Instancia del `SearchableCardSelect` configurada para organizaciones. Ícono de edificio + nombre de org activa en el trigger.
- `SearchableCardSelect` — Ver especificación completa a continuación.
- `NotificationsButton` — Botón con badge de notificaciones no leídas
- `ProfileQuickAccessButton` — Acceso directo al perfil de usuario
- `BottomNavBar` — Barra de navegación inferior para mobile
- `BottomNavSubMenu` — Panel/bottom sheet con subniveles desplegado hacia arriba
- `SidebarUserMenu` — Popover de opciones del bloque de usuario (Ver perfil, Configuración, Cerrar sesión). Solo visible en `md+`.

---

### 3.1 Componente Compartido: `SearchableCardSelect`

**Tipo**: Combobox / Select buscable avanzado. Componente reutilizable del shell; la primera instancia es el `OrganizationSelector` de la top-navbar.

#### Anatomía

```
┌─────────────────────────────────────┐  ← Trigger (siempre solo lectura)
│  [🏢]  Constructora ABC S.A.    [▾] │  ← muestra la selección activa
└─────────────────────────────────────┘
          ↓ clic abre panel flotante
┌─────────────────────────────────────┐
│  🔍 buscar organización...          │  ← input de búsqueda dentro del panel
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │  Constructora ABC S.A.      │[●] │  ← ítem seleccionado: efecto pulse
│  │  Cedente · Añadido 01/2024  │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │  Inmobiliaria XYZ           │[●] │
│  │  Cedente · Añadido 03/2024  │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
         panel / popover flotante
```

#### Anatomía de cada tarjeta (`ItemCard`)

Layout horizontal (flexbox):

| Zona | Contenido |
|------|-----------|
| Lado izquierdo | Título principal (nombre del ítem) en texto destacado. Debajo: texto secundario (meta-información, ej. tipo de org + fecha de incorporación). |
| Lado derecho | Avatar pequeño circular (logo de la org o iniciales si no hay imagen). |

#### Máquina de estados

**Trigger (estado reposo)**
- Muestra el ítem actualmente seleccionado con su ícono asociado y el nombre.
- Si no hay selección: muestra un placeholder (ej. `"Selecciona una organización"`).
- El trigger es **siempre de solo lectura**; no se convierte en input al hacer clic.

**Trigger (estado activo — click / focus)**
- Al hacer clic, abre el panel flotante.
- El foco se transfiere automáticamente al input de búsqueda dentro del panel.

**Apertura con selección previa**
- El panel se abre mostrando toda la lista.
- El ítem previamente seleccionado recibe foco automático y activa el **efecto pulse**.

**Panel flotante**
- Se despliega debajo del trigger al hacer clic.
- La primera sección del panel es un **input de búsqueda** fijo en la parte superior (sticky dentro del panel), con ícono de lupa y placeholder `"Buscar organización..."`.
- El foco se mueve automáticamente al input de búsqueda al abrir el panel.
- Debajo del input, la lista de tarjetas scrollable.

**Filtrado en tiempo real**
- Al escribir en el input, la lista filtra dinámicamente por coincidencia parcial en el nombre principal (case-insensitive).
- Si no hay coincidencias: estado vacío con mensaje `"Sin resultados."`.

**Cierre**
- Clic fuera del componente → cierra el panel sin cambiar la selección.
- `Escape` → cierra el panel sin aplicar cambios.
- `Enter` sobre un ítem con foco → confirma selección, cierra el panel, actualiza el trigger.

#### Navegación por teclado

| Tecla | Acción |
|-------|--------|
| `ArrowDown` | Mueve el foco al siguiente ítem de la lista |
| `ArrowUp` | Mueve el foco al ítem anterior |
| `Enter` | Confirma el ítem con foco activo |
| `Escape` | Cierra el panel sin aplicar cambios |

#### Estado visual "En Foco" (pulse)

El ítem con foco activo (por teclado o por ser la selección previa) aplica una animación CSS en bucle:
- Parpadeo suave de opacidad, **o**
- Escalado sutil `scale(1.02)`, **o**
- Expansión de sombra (`box-shadow`) en bucle.

El objetivo es indicar inequívocamente el foco sin ser intrusivo.

#### Criterios de aceptación

- [ ] El trigger es siempre de solo lectura: muestra la selección activa o placeholder.
- [ ] Al hacer clic en el trigger, se abre el panel flotante y el foco se transfiere automáticamente al input de búsqueda dentro del panel.
- [ ] El input de búsqueda está fijo en la parte superior del panel (sticky). La lista de tarjetas hace scroll por debajo.
- [ ] Si había selección previa, el ítem correspondiente recibe foco y activa efecto pulse al abrir.
- [ ] Filtrado en tiempo real por nombre principal al escribir (coincidencia parcial, case-insensitive).
- [ ] Estado vacío en el panel cuando ningún ítem coincide con el texto ingresado.
- [ ] Navegación completa por teclado: `ArrowUp`, `ArrowDown`, `Enter`, `Escape`.
- [ ] `Enter` confirma selección y cierra el panel. `Escape` cierra sin cambios.
- [ ] Clic fuera del componente cierra el panel sin cambiar la selección.
- [ ] Cada tarjeta muestra: nombre, meta-información y avatar (logo o iniciales).
- [ ] El componente es genérico y reutilizable: acepta una lista de ítems con estructura `{ id, name, meta, avatarUrl? }`.

**Sub-componentes**

- `SearchableCardSelect` — Componente contenedor (combobox)
- `SearchableCardTrigger` — Trigger con estado reposo/activo (input)
- `SearchableCardPanel` — Panel flotante (popover) con la lista filtrable
- `SearchableCardItem` — Tarjeta individual: nombre, meta, avatar, estado pulse

---

## 3.2 Convención Global — Comportamiento de Modales en Responsivo

Todos los modales de la plataforma siguen una regla de adaptación según el breakpoint activo:

| Tipo de modal | Desktop (`md+`) | Mobile / Tablet (`xs–md`) |
|---------------|:---------------:|:-------------------------:|
| **Adaptativo** | Ventana centrada con overlay oscuro | Misma ventana, ancho `~95%`, centrada verticalmente. Aplicar a modales de confirmación y lectura pasiva (ej. T\&C). |
| **Full Screen** | Ventana centrada con overlay oscuro | Ocupa el 100% del viewport (`position: fixed; inset: 0`). Sin overlay. Aplicar a modales con formularios largos, steppers o tablas complejas. |

**Reglas generales**
- Todos los modales en `xs–md` incluyen un botón `[✕]` o swipe-down como gesto de cierre.
- Los botones de acción (footer) en `xs–md` ocupan el ancho completo con área de toque ≥ 44×44px.
- En Full Screen, el header del modal actúa como barra de navegación (título centrado, `[✕]` a la izquierda).
- En Adaptativo, el alto máximo del modal en `xs–md` es `85vh`; el cuerpo hace scroll interno si supera ese límite.

**Aplicación por modal**

| Modal | Tipo responsivo |
|-------|:---------------:|
| `TermsAndConditionsModal` | Adaptativo |
| `InvoiceUploadModal` | Full Screen |
| `OfferCompareModal` | Full Screen |

---

## 3.3 Sistema de Diseño — Tokens, Tipografía y Temas

### Modelo de temas

Factor soporta **dos temas base** (dark / light) con posibilidad de personalización por organización. El sistema se implementa en tres capas de CSS custom properties:

| Capa | Quién la define | Personalizable |
|------|----------------|:--------------:|
| **Capa 1 — Paleta de referencia** | Factor (inmutable) | ❌ |
| **Capa 2 — Tokens semánticos** | Tema activo (dark / light) | ❌ (excepto por el tema) |
| **Capa 3 — Tokens de organización** | Organización activa | ✅ (3 tokens de acento) |

Los componentes **solo consumen tokens semánticos**, nunca la paleta de referencia directamente. Esto garantiza que el sistema de diseño sea coherente, accesible y extensible sin modificar componentes.

---

### ¿Es costoso el sistema de personalización por org?

**No, si se mantiene disciplinado:**
- La arquitectura de CSS custom properties es nativa del navegador — costo cero en runtime.
- Dark/Light toggle: costo **bajo** (cambio de `data-theme` en el elemento raíz + 2 sets de tokens).
- Per-org customization: costo **medio** solo al añadir la UI de color picker + persistencia en backend. Puede postergarse al post-MVP sin impacto si la arquitectura de tokens está bien planteada desde el inicio.
- La clave es limitar las variables personalizables a **3 tokens de acento**. Los colores de estado (error, warning, success, info) y los neutros de fondo **nunca son personalizables**.

---

### Fases de implementación

| Fase | Alcance | Costo |
|------|---------|:-----:|
| **MVP** | Tema dark fijo (consistente con la landing). Sin toggle visible. | Muy bajo |
| **Post-MVP v1** | Toggle dark/light en preferencias de usuario. Persiste en `currentUser`. | Bajo |
| **Post-MVP v2** | Per-org: selector de 3 tokens con validación de contraste WCAG AA. Persiste en el perfil de organización. | Medio |

---

### Paleta de referencia (Brand — inmutable)

| Token | Valor hex | Descripción |
|-------|-----------|-------------|
| `--ref-navy-deep` | `#0D1655` | Fondo más profundo |
| `--ref-navy` | `#1A237E` | Superficie intermedia |
| `--ref-navy-mid` | `#1E2A8A` | Variante sidebar |
| `--ref-teal` | `#00BFA5` | Acento primario brand |
| `--ref-teal-dim` | `#00897B` | Acento primario oscurecido |
| `--ref-teal-bright` | `#64FFDA` | Highlight / shimmer |
| `--ref-white` | `#FFFFFF` | Texto sobre fondos oscuros |
| `--ref-ink` | `#0A0D1A` | Texto sobre fondos claros |
| `--ref-surface-light` | `#F5F5F0` | Fondo claro base |
| `--ref-gray-100` | `#F0F2F5` | |
| `--ref-gray-300` | `#C7CDD8` | |
| `--ref-gray-500` | `#8E97A8` | |
| `--ref-gray-700` | `#4A5568` | |

---

### Tokens semánticos (por tema)

Los componentes consumen estos tokens. Se redefinen al cambiar el `data-theme`.

| Token semántico | Dark | Light |
|----------------|------|-------|
| `--color-bg-base` | `#0D1655` | `#F0F2F5` |
| `--color-bg-surface` | `#1A237E` | `#FFFFFF` |
| `--color-bg-elevated` | `#1E2A8A` | `#FFFFFF` |
| `--color-text-primary` | `#FFFFFF` | `#0A0D1A` |
| `--color-text-secondary` | `rgba(255,255,255,0.55)` | `#4A5568` |
| `--color-text-disabled` | `rgba(255,255,255,0.25)` | `#C7CDD8` |
| `--color-border` | `rgba(255,255,255,0.08)` | `rgba(0,0,0,0.10)` |
| `--color-brand-primary` | `#00BFA5` | `#00897B` |
| `--color-brand-primary-dim` | `#00897B` | `#1A237E` |
| `--color-brand-on-primary` | `#0A0D1A` | `#FFFFFF` |

---

### Tokens de estado (constantes en ambos temas)

| Token | Valor | Uso |
|-------|-------|-----|
| `--color-success` | `#22C55E` | Confirmaciones, estados completados |
| `--color-warning` | `#F59E0B` | Alertas, notas OCR pendientes |
| `--color-error` | `#EF4444` | Errores, logout, acciones destructivas |
| `--color-info` | `#3B82F6` | Notificaciones informativas |

---

### Tokens de organización (capa de personalización)

La organización puede sobreescribir **solo estos 3 tokens**. El sistema aplica validación de contraste mínimo WCAG AA antes de persistir los valores; si un color seleccionado no pasa el umbral, se rechaza y se muestra un aviso al usuario.

| Token | Default (Factor brand) | Descripción |
|-------|----------------------|-------------|
| `--org-brand-primary` | `var(--ref-teal)` | Color institucional principal |
| `--org-brand-primary-dim` | `var(--ref-teal-dim)` | Variante oscurecida del principal |
| `--org-brand-on-primary` | `var(--ref-ink)` | Texto sobre el color principal |

> `--color-brand-primary` referencia `--org-brand-primary`. El override de organización afecta el sistema de forma controlada sin romper los tokens semánticos restantes.

---

### Tipografía

#### Fuente de UI — Plus Jakarta Sans

- Variable: `--font-sans`
- Pesos cargados: 300, 400, 500, 700, 800
- Uso: todo texto de interfaz (labels, body, headings, botones, inputs)
- En contextos de datos: activar `font-feature-settings: "tnum" 1` para dígitos tabulares uniformes

#### Fuente de datos — JetBrains Mono

- Variable: `--font-mono`
- Pesos cargados: 400, 500, 700
- Carga: diferida (solo módulos con datos financieros densos — code splitting)
- Uso exclusivo:
  - Importes y tasas en la calculadora de liquidación
  - Columnas de montos en tablas del dashboard
  - Montos comparativos en `OfferCompareModal`
  - RUTs y folios en formularios y vistas de factura

#### Escala tipográfica

| Rol | Tamaño | Peso | Fuente |
|-----|--------|:----:|:------:|
| `display` | `clamp(2rem, 4vw, 3rem)` | 800 | Sans |
| `heading-1` | `clamp(1.75rem, 3vw, 2.25rem)` | 800 | Sans |
| `heading-2` | `1.5rem` | 700 | Sans |
| `heading-3` | `1.25rem` | 700 | Sans |
| `body-lg` | `1rem` | 400 | Sans |
| `body` | `0.875rem` | 400 | Sans |
| `body-sm` | `0.75rem` | 400 | Sans |
| `label` | `0.75rem` | 700 | Sans — uppercase, `letter-spacing: 0.06em` |
| `data-lg` | `1.25rem` | 700 | Mono — `tnum` |
| `data` | `0.875rem` | 500 | Mono — `tnum` |
| `data-sm` | `0.75rem` | 400 | Mono — `tnum` |

---

## 4. Modelo de Datos — Factura

| Campo | Fuente | Notas |
|-------|--------|-------|
| Número de folio / Folio SII | OCR + validación usuario | |
| RUT emisor | OCR + validación usuario | Empresa cliente |
| RUT receptor (deudor) | OCR + validación usuario | Empresa que debe pagar |
| Nombre deudor | OCR + validación usuario | |
| Monto total | OCR + validación usuario | En CLP |
| Fecha de emisión | OCR + validación usuario | |
| Fecha de vencimiento | OCR + validación usuario | Plazo determinante para el ejecutivo |
| PDF original adjunto | Upload directo | |
| Estado | Sistema | Ver sección 5 |

---

## 5. Estados de una Factura

### Flujo de ingreso

Existen tres caminos de ingreso, todos crean el registro en BD directamente en `PENDIENTE_AUTORIZACION`:

```
[Caso 1: Formulario manual SIN respaldo PDF]
  └─► Cliente completa formulario → frontend crea registro en estado PROCESANDO (solo UI)
        └─► POST al backend → registro creado en BD en PENDIENTE_AUTORIZACION
              └─► Backend responde con éxito → frontend levanta modal T&C
                    ├─► Cliente acepta T&C → PATCH al backend → PUBLICADA
                    └─► Cliente cierra modal → factura queda en PENDIENTE_AUTORIZACION
                                               (puede retomar desde factura-view)

[Caso 2: Formulario manual CON respaldo PDF]
  └─► Cliente completa formulario + sube PDF → frontend crea registro en estado PROCESANDO (solo UI)
        └─► POST al backend → registro creado en BD en PENDIENTE_AUTORIZACION
              └─► PUT respaldo PDF al backend → PDF enlazado al registro
                    └─► Backend procesa OCR y emite evento (SSE/WS) con datos + notas
                          └─► factura-view sale del skeleton → muestra datos y notas OCR
                                └─► Cliente revisa y valida datos (puede reemplazar respaldo)
                                      └─► Cliente hace clic en footer → modal T&C
                                            ├─► Acepta → PATCH al backend → PUBLICADA
                                            └─► Cancela → factura permanece en PENDIENTE_AUTORIZACION

[Caso 3: Subida automática por OCR (PDF drag & drop)]
  └─► Cliente sube PDF → frontend crea registro en estado PROCESANDO (solo UI)
        └─► POST al backend → registro + PDF → backend procesa OCR
              └─► Evento SSE/WS con datos extraídos + notas → registro en PENDIENTE_AUTORIZACION
                    └─► factura-view sale del skeleton → muestra datos y notas OCR
                          └─► (botón "Subir respaldo" DESHABILITADO — PDF ya adjunto vía OCR)
                                └─► Cliente revisa y valida datos
                                      └─► Cliente hace clic en footer → modal T&C
                                            ├─► Acepta → PATCH al backend → PUBLICADA
                                            └─► Cancela → factura permanece en PENDIENTE_AUTORIZACION
```

> **Cambio clave respecto al diseño anterior**: el estado `PENDIENTE_VALIDACION` ya no existe como estado persistido en BD. El registro se crea directamente en `PENDIENTE_AUTORIZACION`. La validación de datos por el cliente ocurre mientras la factura ya está en ese estado. `PROCESANDO` sigue siendo solo un estado de UI (no persistido).

### Flujo de estados completo

```
PENDIENTE_AUTORIZACION
  └─► PUBLICADA           (cliente aceptó T&C → backend habilita lectura a ejecutivos)
              └─► OFERTADA      (al menos 1 oferta recibida)
                    └─► FINANCIADA   (cliente aceptó una oferta → negociación cerrada)
                          └─► PENDIENTE_VERIFICACION_PAGO  (ejecutivo/financiera notifica depósito)
                                └─► PAGADA   (cliente confirma la recepción en su banco)

Estados terminales:
  VENCIDA       ← sistema automático al llegar a fechaVencimiento sin financiar
  CANCELADA     ← cliente retira la factura voluntariamente (hasta OFERTADA)
  RECHAZADA     ← OCR detecta discrepancias totales al subir respaldo (⚠️ pendiente revisión)
  DENUNCIADA    ← ejecutivo o admin reporta irregularidad grave (desde cualquier estado activo)
```

### Definición de estados

| Estado | Persiste en BD | Visible cliente | Visible ejecutivo | Descripción |
|--------|:--------------:|:---------------:|:-----------------:|-------------|
| `PROCESANDO` | ❌ (solo front) | ✅ | ❌ | El backend está procesando el PDF/OCR. Estado transitorio de UI mientras se espera respuesta SSE/WS del backend. |
| `PENDIENTE_AUTORIZACION` | ✅ | ✅ | ❌ | Registro creado en BD. El cliente puede estar revisando datos OCR o pendiente de aceptar T&C. Estado único de espera antes de publicar. |
| `PUBLICADA` | ✅ | ✅ | ✅ | Factura abierta a ofertas. Visible en el marketplace de ejecutivos. |
| `OFERTADA` | ✅ | ✅ | ✅ (propias) | La factura recibió al menos una oferta activa. |
| `FINANCIADA` | ✅ | ✅ | ✅ (propias) | Cliente y ejecutivo/financiera cerraron la negociación. Oferta aceptada. |
| `PENDIENTE_VERIFICACION_PAGO` | ✅ | ✅ | ✅ (propias) | El ejecutivo o la financiadora notificó que realizó el depósito. El cliente debe verificarlo en su banco y confirmar la recepción. |
| `PAGADA` | ✅ | ✅ | ✅ (propias) | Cliente confirmó la recepción del depósito en su banco. Operación completada. |
| `VENCIDA` | ✅ | ✅ | ❌ | Sistema automático: `fechaVencimiento` superada y la factura nunca alcanzó `FINANCIADA`. La factura se archiva. El cliente puede publicar una nueva si el documento sigue vigente en el SII. |
| `RECHAZADA` | ✅ | ✅ | ❌ | Criterios confirmados: (a) factura duplicada (mismo folio + RUT emisor ya existente); (b) el RUT del cedente o cliente no coincide con ningún RUT detectado por OCR en el PDF. ⚠️ Pueden existir criterios adicionales por definir. |
| `CANCELADA` | ✅ | ✅ | ❌ | Cliente retira voluntariamente la factura. Disponible desde `PENDIENTE_AUTORIZACION`, `PUBLICADA` u `OFERTADA`. **No disponible desde `FINANCIADA` en adelante** (compromiso ya adquirido). Si estaba en `OFERTADA`, se notifica a los ejecutivos con oferta activa. |
| `DENUNCIADA` | ✅ | ✅ | ✅ | Ejecutivo o admin reporta irregularidad grave (fraude, documento falso, cedente en litigio, deudor fallido). Congela la operación desde cualquier estado activo. Solo un admin puede resolver el estado. |

---

## 6. Pantallas — MFE Publicador (Cliente)

### 6.1 Subida de Factura

**Descripción**: Modal con dos pestañas que permite al cliente elegir entre detección automática por OCR o ingreso manual por formulario.

**Comportamiento responsivo**: Full Screen en `xs–md` (100% viewport). En `md+` ventana centrada con overlay.

#### Estructura de UI

```
[ Modal: Nueva Factura ]
  ┌─────────────────────────────┐
  │  [ Automática ] [ Manual ]  │  ← pestañas
  ├─────────────────────────────┤
  │  Pestaña Automática:        │
  │  DropzoneUploader (PDF)     │
  │  → al subir: modal se cierra│
  │  → factura-view aparece en  │
  │    skeleton loading         │
  │    esperando evento SSE/WS  │
  │    del backend              │
  ├─────────────────────────────┤
  │  Pestaña Manual (Stepper):  │
  │  Paso 1: Formulario datos   │
  │  Paso 2: Subir PDF respaldo │
  │          (opcional)         │
  └─────────────────────────────┘
```

#### Flujo — Pestaña Automática (Caso 3)

1. Cliente sube PDF por drag & drop o file picker.
2. Modal se cierra inmediatamente.
3. En la lista aparece `factura-view` en **skeleton loading** (estado `PROCESANDO` en UI).
4. Frontend envía el PDF al backend → backend crea el registro en BD en `PENDIENTE_AUTORIZACION` y procesa OCR.
5. Al completar, el backend emite evento SSE/WS con datos extraídos + notas de discrepancia.
6. La tarjeta sale del skeleton. El botón **"Subir respaldo"** queda deshabilitado (el PDF ya fue adjuntado vía OCR).
7. Cliente revisa y valida datos → clic en footer → modal T&C → acepta → `PUBLICADA`.

#### Flujo — Pestaña Manual sin respaldo (Caso 1)

1. **Paso 1 — Datos**: cliente completa el formulario (folio, RUTs, nombre deudor, monto, fechas) y confirma **sin adjuntar PDF**.
2. Frontend envía los datos al backend → backend crea el registro en BD en `PENDIENTE_AUTORIZACION`.
3. Al recibir la respuesta exitosa del backend, el frontend levanta directamente el **modal de T&C** (no hay datos OCR que revisar).
4. Cliente acepta T&C → `PUBLICADA`. Si cancela, la factura queda en `PENDIENTE_AUTORIZACION` y puede retomarse desde `factura-view`.

#### Flujo — Pestaña Manual con respaldo (Caso 2)

1. **Paso 1 — Datos**: cliente completa el formulario.
2. **Paso 2 — Respaldo PDF**: cliente adjunta el PDF.
3. Frontend envía datos al backend → registro creado en `PENDIENTE_AUTORIZACION` → luego sube el PDF → backend procesa OCR y emite evento SSE/WS con datos + notas.
4. La tarjeta sale del skeleton mostrando datos y notas OCR. Botón **"Subir respaldo"** habilitado para reemplazar el PDF si el cliente detecta que subió uno incorrecto.
5. Cliente revisa, resuelve notas → clic en footer → modal T&C → acepta → `PUBLICADA`.

**Historias de usuario**

- `US-P01` — Como cliente, quiero subir un PDF en la pestaña automática y que el modal se cierre solo, para no interrumpir mi flujo mientras el backend procesa la detección.
- `US-P02` — Como cliente, quiero ver la factura en skeleton loading mientras se procesa el OCR, para saber que la operación está en curso sin bloquearme.
- `US-P03` — Como cliente, quiero ingresar los datos manualmente si no tengo el PDF disponible, para no quedar bloqueado por la falta del archivo.
- `US-P04` — Como cliente, quiero adjuntar un PDF de respaldo en el paso 2 del formulario manual, para que el sistema compare los datos y me alerte de discrepancias.
- `US-P05` — Como cliente, quiero recibir feedback inmediato si el PDF no es legible, para poder corregirlo o cambiar a ingreso manual.

**Criterios de aceptación**

- [ ] El modal tiene dos pestañas: "Automática" y "Manual".
- [ ] **Caso 3 — Automática**: drag & drop o file picker → modal se cierra → `factura-view` en skeleton → evento SSE/WS del backend resuelve el skeleton → registro en `PENDIENTE_AUTORIZACION`. Botón "Subir respaldo" deshabilitado.
- [ ] **Caso 1 — Manual sin respaldo**: formulario completo → confirmar → POST al backend → al recibir respuesta exitosa se levanta modal T&C directamente. Si el cliente cancela el T&C, la factura queda en `PENDIENTE_AUTORIZACION`.
- [ ] **Caso 2 — Manual con respaldo**: formulario + PDF → POST datos + PUT PDF → evento SSE/WS con OCR → `factura-view` sale del skeleton con notas. Botón "Subir respaldo" habilitado para reemplazar.
- [ ] En todos los casos el registro se crea en BD en `PENDIENTE_AUTORIZACION` (nunca en `PENDIENTE_VALIDACION`).
- [ ] PDF ilegible → error descriptivo con opción de reintentar o saltar el paso (Caso 2 y 3).
- [ ] El evento del backend que resuelve el skeleton puede ser éxito (`PENDIENTE_AUTORIZACION` + datos OCR) o error (`RECHAZADA` con motivo).

**Componentes**

- `InvoiceUploadModal` — Modal contenedor con sistema de pestañas
- `DropzoneUploader` — Área de drag & drop con validación de tipo/tamaño (reutilizado en ambas pestañas)
- `FacturaViewSkeleton` — Tarjeta skeleton que representa la factura mientras el OCR procesa (estado `PROCESANDO`)
- `InvoiceFormStepper` — Stepper de 2 pasos para la vía manual
- `InvoiceDataForm` — Formulario de datos de la factura (Paso 1)
- `PdfBackupStep` — Paso de carga de respaldo PDF con notas de discrepancia (Paso 2)
- `OcrDiscrepancyNote` — Nota inline de discrepancia OCR vs dato ingresado
- `TermsAndConditionsModal` — Ver especificación en sección 6.1.1

---

#### 6.1.1 Componente: `TermsAndConditionsModal`

**Descripción**: Modal de aceptación de Términos y Condiciones que se levanta antes de cambiar una factura a estado `PUBLICADA`. Reemplaza la implementación actual con SweetAlert2 por un diseño propio alineado al sistema de diseño del Portal.

**Comportamiento responsivo**: Adaptativo — ventana centrada en ambos breakpoints. En `xs–md` ocupa ~95% del ancho y hasta `85vh` de alto; el cuerpo del T\&C hace scroll interno. Los botones del footer ocupan el ancho completo con área de toque ≥ 44×44px.

> Este modal se dispara en los **3 casos** de publicación. La diferencia es el momento del disparo: en el Caso 1 se levanta inmediatamente al crear el registro; en los Casos 2 y 3 se levanta cuando el cliente hace clic en el botón del footer de `factura-view`.

#### Estructura del modal

```
┌─────────────────────────────────────────────────────┐
│  Términos y Condiciones de Publicación         [✕]  │
│  ─────────────────────────────────────────────────  │
│                                                     │
│  [Título del T&C — obtenido desde el backend]       │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │                                               │  │
│  │  Texto completo de los T&C...                 │  │
│  │  (contenedor con scroll si el texto           │  │
│  │   excede el alto del modal)                   │  │
│  │                                               │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  [ Revisar publicación ]   [ Aceptar términos ]     │
└─────────────────────────────────────────────────────┘
```

#### Comportamiento

| Elemento | Comportamiento |
|----------|---------------|
| Título | Texto dinámico obtenido desde el backend junto con el contenido de los T&C |
| Cuerpo scrollable | Si el texto es largo, el contenedor tiene `overflow-y: auto` con altura máxima. El botón "Aceptar" siempre visible sin hacer scroll. |
| Botón **"Revisar publicación"** | Cierra el modal. La factura permanece en `PENDIENTE_AUTORIZACION`. El cliente puede volver a abrir el modal desde el footer de `factura-view`. |
| Botón **"Aceptar términos"** | Muestra spinner → envía PATCH al backend para cambiar estado a `PUBLICADA` → al éxito: cierra el modal, actualiza el badge de estado en `factura-view` con animación pulse. |
| `[✕]` / `Escape` | Equivalente a "Revisar publicación": cierra sin aceptar. |
| Error en el PATCH | Mensaje de error dentro del modal con opción de reintentar. |

**Fuente del contenido**: el título y texto de los T&C se obtienen del backend (no están hardcodeados en el frontend). Esto permite actualizar los T&C sin despliegue de frontend.

**Criterios de aceptación**

- [ ] El modal muestra título y cuerpo de T&C obtenidos del backend.
- [ ] El cuerpo del T&C tiene scroll interno si supera la altura máxima. Los botones siempre son visibles.
- [ ] "Revisar publicación" cierra el modal sin cambios. La factura permanece en `PENDIENTE_AUTORIZACION`.
- [ ] "Aceptar términos" muestra spinner → PATCH al backend → éxito: cierra modal + badge de `factura-view` actualizado con animación pulse.
- [ ] Error en el PATCH: mensaje dentro del modal, botón rehabilitado para reintentar.
- [ ] `Escape` y `[✕]` equivalen a "Revisar publicación".
- [ ] En el Caso 1 (formulario sin respaldo), el modal se levanta automáticamente al recibir la respuesta exitosa del POST de creación.
- [ ] En los Casos 2 y 3, el modal se levanta al hacer clic en el botón del footer de `factura-view` (solo habilitado cuando el formulario está validado).

**Componentes**

- `TermsAndConditionsModal` — Modal contenedor
- `TcContentScroll` — Contenedor scrollable del texto de T&C
- `TcActionButtons` — Botones "Revisar publicación" / "Aceptar términos" con estado de spinner

---

### 6.2 Lista de Facturas (Cliente)

**Descripción**: Vista principal del cliente. Lista de `factura-view` en expansion panels, una por factura.

**Historias de usuario**

- `US-P06` — Como cliente, quiero ver todas mis facturas como tarjetas colapsadas con su estado de un vistazo, para saber en qué etapa está cada operación sin necesidad de abrir cada una.
- `US-P07` — Como cliente, quiero filtrar mis facturas por estado, para encontrar rápidamente las que necesitan mi atención.
- `US-P08` — Como cliente, quiero ver cuántas ofertas tiene cada factura publicada, para priorizar mi atención.
- `US-P09` — Como cliente, quiero expandir una factura para editar sus datos y tomar acciones, para gestionar la operación sin salir de la lista.

**Criterios de aceptación**

- [ ] Lista de `factura-view` en expansion panels, orden por defecto: más reciente primero.
- [ ] Filtros por estado (múltiple selección).
- [ ] Factura recién procesada por OCR aparece como skeleton hasta que el backend emite el evento de resolución.
- [ ] Estado vacío amigable con CTA para subir primera factura.

**Componentes**

- `InvoiceList` — Contenedor de la lista de `factura-view`
- `FacturaView` — Ver sección 6.2.1
- `FacturaViewSkeleton` — Estado de carga mientras el OCR procesa (estado `PROCESANDO`)
- `EmptyStateInvoices` — Estado vacío con CTA

---

#### 6.2.1 Componente: `factura-view`

**Descripción**: Expansion panel que representa una factura en la lista del cliente. Tiene dos estados visuales: colapsado (resumen) y expandido (detalle completo con formulario editable y acciones).

---

##### Estado colapsado (header del panel)

```
┌─────────────────────────────────────────────────────────┐
│  ● PUBLICADA   #00123   Razón Social Deudor   [🔔]  [▼] │
└─────────────────────────────────────────────────────────┘
```

- **Badge de estado** (`InvoiceStatusBadge`): color dinámico según estado. Hace un **pulse animado** cuando cambia de estado. Pulsa de forma continua mientras está en `PROCESANDO`.
- **Número de factura**
- **Razón social del deudor**
- **Icono de notificación de ofertas** (`OfferNotificationIcon`): indica si existen ofertas nuevas no revisadas. Oculto si no hay ofertas.

---

##### Estado expandido

**Encabezado del panel expandido:**
```
  Factura: #00123   │   Nombre cliente · RUT cliente · Gestor: [nombre_usuario]
```
- Muestra el número de factura, el nombre del cliente, su RUT, y el gestor (usuario que subió la factura).

**Layout en pantalla grande (cuando la foto está activa):**
```
┌──────────────────────┬──────────────────────────────────┐
│                      │  Datos de la factura             │
│   Foto / imagen      │  ─────────────────────────────── │
│   de la factura      │  N° Factura    [campo editable]  │
│                      │  RUT Deudor    [campo/mask RUT]  │
│                      │  Razón Social  [campo editable]  │
│                      │  Monto Total   [campo/mask num]  │
│                      │  Fecha Venc.   [datepicker]      │
└──────────────────────┴──────────────────────────────────┘
```

**Sección de datos (derecha o pantalla completa si la foto está oculta):**

La tabla de datos incluye una **columna de acción** por fila. Cada fila puede estar en uno de tres modos: lectura, edición en curso, o confirmada.

| Campo | Tipo de control | Comportamiento especial | Acción de fila |
|-------|----------------|-------------------------|----------------|
| N° Factura | Input texto | — | Botón guardar/cancelar al editar |
| RUT Deudor | Input con máscara | Valida formato RUT chileno | Botón guardar/cancelar al editar |
| Razón Social | Input texto | — | Botón guardar/cancelar al editar |
| Monto Total | Input con máscara | Solo numérico, formato CLP | Botón guardar/cancelar al editar |
| Fecha Vencimiento | Datepicker | — | Botón guardar/cancelar al editar |

- Si el backend retorna más de un valor posible para un campo (ej: `dato1;dato2`), el control se convierte en un **select** para que el cliente elija el valor correcto.
- Las filas que tienen una **nota OCR pendiente** se destacan con un color de fondo distintivo (ej: amarillo suave) para indicar que requieren atención.
- Mientras una fila está en modo edición, el botón de acción cambia a estado "guardando" (spinner) al confirmar, y vuelve a modo lectura al completarse.
- Los campos son re-editables mientras la factura esté en estado `PENDIENTE_VALIDACION`, `PENDIENTE_AUTORIZACION` o `RECHAZADA`.

**Sección de Notas OCR (debajo del formulario de datos):**

Lista de notas generadas por el backend OCR al procesar la factura. Cada nota está asociada a un campo específico y describe la incongruencia detectada.

Ejemplos de notas:
- `Campo "RUT Deudor"` — El sistema detectó múltiples valores: `12.345.678-9` / `98.765.432-1`. Selecciona el correcto.
- `Campo "Número Factura"` — El formulario indica `123` pero el sistema detectó `456`. Verifica el valor.
- `Campo "Monto Total"` — No se pudo detectar el valor. Ingreso manual requerido.

Las notas desaparecen individualmente cuando el cliente modifica el campo asociado (independientemente del valor ingresado), ya que el OCR puede cometer errores y no se puede bloquear el flujo por eso. El ejecutivo podrá hacer una segunda evaluación de los datos al revisar la factura para ratificar que la información sea correcta. Cuando no quedan notas pendientes, la sección se oculta y el botón de footer se habilita.

**Footer del panel — Botón de acción principal:**

| Estado de la factura | Texto del botón | Habilitado cuando | Acción |
|----------------------|-----------------|:-----------------:|--------|
| `PENDIENTE_AUTORIZACION` (con notas OCR pendientes) | Validar y publicar | ❌ Deshabilitado | — |
| `PENDIENTE_AUTORIZACION` (formulario validado, sin notas pendientes) | Validar y publicar | ✅ | Levanta `TermsAndConditionsModal` |
| `RECHAZADA` | Corregir y reenviar | ✅ | Rehabilita edición de campos → al confirmar, reingresa al flujo |
| Otros estados | — | — | Botón oculto |

> **Nota**: el Caso 1 (formulario sin respaldo) levanta el modal T&C automáticamente desde el flujo de creación, sin necesidad de que el cliente haga clic en el footer. El footer en `PENDIENTE_AUTORIZACION` aplica a los Casos 2 y 3 donde el cliente debe revisar primero los datos OCR.

- El botón está **deshabilitado** mientras existan notas OCR no atendidas (campos aún no tocados por el usuario).
- El botón está **habilitado** cuando todos los campos del formulario tienen valor y no quedan notas OCR pendientes.

**Acciones (3 botones bajo el panel):**

| # | Botón | Acción | Habilitado cuando |
|---|-------|--------|-------------------|
| 1 | Ver foto | Divide la vista en 2 (foto + formulario) en pantalla grande / muestra la imagen en pantalla pequeña | Siempre (si existe imagen) |
| 2 | Subir respaldo | Abre dropzone para adjuntar PDF de respaldo | Solo si la factura fue subida por **formulario** o por **agente** (futuro). Deshabilitado si fue subida por OCR automático. |
| 3 | Notificaciones | Abre un **sidebar lateral** con las notificaciones y actividad asociadas a esta factura (ofertas recibidas, mensajes de chat, cambios de estado, etc.) | Siempre visible; badge con conteo si hay notificaciones no leídas |

**Historias de usuario**

- `US-P11` — Como cliente, quiero ver y editar los datos de la factura dentro del panel expandido, para corregir incongruencias detectadas por el OCR.
- `US-P12` — Como cliente, quiero que las filas con notas OCR pendientes se destaquen visualmente, para identificar de un vistazo qué campos requieren mi atención.
- `US-P13` — Como cliente, quiero que el botón de acción de cada fila cambie de estado mientras guardo un dato, para saber que el cambio está siendo procesado.
- `US-P14` — Como cliente, quiero ver la lista de notas OCR debajo del formulario, para entender exactamente qué incongruencias detectó el sistema y en qué campo.
- `US-P15` — Como cliente, quiero que las notas desaparezcan al modificar el campo asociado (sin importar el valor), para que el flujo no quede bloqueado si el OCR cometió un error que ya conozco.
- `US-P16` — Como cliente, quiero un botón de acción principal en el footer que cambie según el estado de la factura, para saber exactamente cuál es el siguiente paso sin ambigüedad.
- `US-P17` — Como cliente, quiero que los campos sean re-editables cuando la factura está rechazada, para poder corregir y reenviar sin tener que subir la factura de nuevo.
- `US-P18` — Como cliente, quiero que los campos con múltiples valores detectados por OCR me muestren un selector, para elegir el dato correcto sin escribirlo manualmente.
- `US-P19` — Como cliente, quiero ver la imagen de la factura junto al formulario, para validar los datos visualmente.
- `US-P20` — Como cliente, quiero subir un PDF de respaldo si ingresé la factura manualmente, para adjuntar el documento original cuando lo tenga disponible.
- `US-P21` — Como cliente, quiero abrir un panel lateral de notificaciones desde la factura, para ver toda la actividad asociada a esa operación sin perder el contexto de la lista.

**Criterios de aceptación**

- [ ] Panel colapsado muestra: badge de estado (pulsante), número de factura, razón social del deudor, icono de notificación de ofertas (si aplica).
- [ ] Badge de estado hace animación pulse al cambiar de estado.
- [ ] Panel expandido muestra encabezado con: "Factura: #N°", nombre cliente, RUT cliente, gestor.
- [ ] Formulario editable con los 5 campos. Máscaras activas para RUT y monto.
- [ ] Campo con múltiples valores del OCR (`dato1;dato2`) renderiza un `<select>` en lugar de un input.
- [ ] Fecha de vencimiento usa datepicker.
- [ ] Cada fila del formulario tiene una columna de acción: al activar edición aparecen botones guardar/cancelar; al guardar muestra spinner; al completar vuelve a modo lectura.
- [ ] Filas con nota OCR pendiente tienen color de fondo distintivo (alerta) que desaparece cuando el usuario modifica el campo, independientemente del valor ingresado.
- [ ] Los campos son editables mientras la factura esté en `PENDIENTE_VALIDACION`, `PENDIENTE_AUTORIZACION` o `RECHAZADA`. En otros estados el formulario es de solo lectura.
- [ ] Sección **Notas OCR** visible debajo del formulario mientras haya notas no atendidas. Cada nota indica el campo afectado y describe la incongruencia. La nota se descarta visualmente en cuanto el usuario modifica el campo asociado (el valor no necesita ser "correcto" — el ejecutivo hará una segunda evaluación). La sección se oculta cuando no quedan notas pendientes.
- [ ] **Footer — botón de acción principal**:
  - `PENDIENTE_VALIDACION`: muestra "Confirmar validación". Deshabilitado si hay notas pendientes.
  - `PENDIENTE_AUTORIZACION`: muestra "Autorizar publicación". Siempre habilitado.
  - `RECHAZADA`: muestra "Corregir y reenviar". Rehabilita edición.
  - Otros estados: botón oculto.
- [ ] Botón 1 (foto): divide la pantalla en 2 columnas si hay imagen disponible; deshabilitado si no hay imagen.
- [ ] Botón 2 (respaldo): habilitado solo si la factura fue subida por formulario o agente; deshabilitado si fue por OCR automático.
- [ ] Botón 3 (notificaciones): abre un sidebar lateral asociado a la factura. El botón muestra un badge con el conteo de notificaciones no leídas cuando las hay.
- [ ] El sidebar muestra secciones organizadas por tipo de actividad (ver `InvoiceNotificationSidebar` más abajo).
- [ ] Al abrir el sidebar, las notificaciones de esa factura se marcan como leídas.

**Sub-componentes de `factura-view`**

- `InvoiceStatusBadge` — Badge de estado con animación pulse en cambio de estado
- `OfferNotificationIcon` — Icono de notificación de ofertas nuevas
- `InvoicePanelHeader` — Encabezado del panel expandido (folio, cliente, RUT, gestor)
- `InvoiceDataForm` — Tabla-formulario editable con columna de acción por fila
- `InvoiceDataRow` — Fila individual del formulario: modo lectura / edición / guardando. Color de fondo distintivo cuando tiene nota OCR pendiente.
- `SmartField` — Control adaptable: input texto/numérico con máscara, select si hay múltiples valores OCR, o datepicker para fechas
- `OcrNotesList` — Sección de notas OCR debajo del formulario. Lista de `OcrNoteItem`; se oculta cuando no hay notas pendientes.
- `OcrNoteItem` — Nota individual con campo afectado y descripción de la incongruencia
- `InvoiceFooterAction` — Botón de acción principal en el footer del panel. Texto y comportamiento dinámico según estado de la factura.
- `InvoiceImagePanel` — Panel con la foto/imagen extraída de la factura
- `UploadBackupButton` — Botón de subida de respaldo (con lógica de habilitación según origen)
- `InvoiceNotificationSidebar` — Panel lateral deslizante con la actividad de la factura. Se organiza en secciones:
  - **Ofertas** — lista de ofertas recibidas con estado y datos resumidos (ejecutivo, monto, tasa)
  - **Mensajes** — hilo de chat/negociación asociado a cada oferta
  - **Actividad** — historial de cambios de estado de la factura (timeline)
- `NotificationBadge` — Badge numérico sobre el botón 3 indicando notificaciones no leídas

---

### 6.3 Detalle de Factura y Ofertas (Cliente)

**Descripción**: Vista dedicada de una factura accesible desde el sidebar de notificaciones o como ruta directa. Muestra los datos completos de la factura, la lista de ofertas recibidas con acciones, y el chat de negociación por oferta. Es la contraparte del cliente a la vista de detalle del ejecutivo (sección 7.2).

> El acceso principal del cliente es vía el **sidebar de notificaciones** del `factura-view`. Esta vista existe también como pantalla completa para casos de acceso directo (link desde notificación, etc.).

**Historias de usuario**

- `US-P11` — Como cliente, quiero ver los datos completos de mi factura, para tener contexto al evaluar las ofertas.
- `US-P12` — Como cliente, quiero ver todas las ofertas que han hecho ejecutivos sobre mi factura, para comparar condiciones.
- `US-P13` — Como cliente, quiero comparar ofertas lado a lado (monto, tasa, gastos), para tomar una decisión informada.
- `US-P14` — Como cliente, quiero negociar en un chat libre con el ejecutivo antes de aceptar, para ajustar las condiciones.
- `US-P15` — Como cliente, quiero aceptar una oferta específica, para formalizar el financiamiento.
- `US-P16` — Como cliente, quiero rechazar una oferta, para descartarla sin afectar las demás.

**Criterios de aceptación**

- [ ] Datos de factura visibles en la parte superior (folio, deudor, monto, fechas).
- [ ] Lista de ofertas con: ejecutivo (nombre / financiera si aplica), monto ofertado, tasa, gastos, fecha de vigencia de oferta.
- [ ] Botón "Comparar" selecciona hasta 3 ofertas para vista comparativa.
- [ ] Chat de negociación libre por oferta, en tiempo real (WebSocket/SSE).
- [ ] Botón "Aceptar oferta" → confirmación → factura pasa a `FINANCIADA` (la liquidación es externa al MVP).
- [ ] Botón "Rechazar oferta" con motivo opcional.
- [ ] Al aceptar una oferta, las demás se marcan como rechazadas automáticamente.

**Componentes**

- `InvoiceDetailCard` — Datos completos de la factura
- `OfferList` — Lista de ofertas con acciones
- `OfferCompareModal` — Modal comparativo de hasta 3 ofertas. **Full Screen en `xs–md`** (100% viewport); ventana centrada en `md+`.
- `NegotiationChat` — Ver especificación completa en sección 6.3.1
- `AcceptOfferConfirmDialog` — Confirmación de aceptación con resumen

---

### 6.3.1 Componente Compartido: `NegotiationChat`

**Descripción**: Panel de chat en tiempo real entre el cliente (cedente) y el ejecutivo, scoped a una oferta específica. Es un componente compartido consumido tanto por el MFE Publicador (§6.3) como por el MFE Ofertador (§7). Cada oferta tiene su propio hilo independiente.

> El canal de comunicación es `offer:{offerId}`. Solo los dos participantes de la oferta pueden leer y escribir en ese hilo.

---

#### Anatomía del componente

```
┌──────────────────────────────────────────────────────────┐
│  HEADER DEL CHAT                                         │
│  ┌────────────────────────────────────────────────────┐  │
│  │  [avatar]  Ejecutivo: Carlos Soto — Financiera XYZ  │  │
│  │            Oferta: CLP $9.250.000 · Tasa 2.10%      │  │
│  │            Vigencia: 5 días restantes               │  │
│  └────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────┤
│  ÁREA DE MENSAJES (scrollable, crece hacia arriba)       │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Factura #4521 · Oferta de Carlos Soto  [▲ Ver] │   │  ← colapsada
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│   — o expandida: —                                       │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Factura #4521 · Oferta de Carlos Soto  [▼ Ocultar]│  │  ← expandida
│  │  ─────────────────────────────────────────────    │   │
│  │  Factura #4521 · Constructora ABC S.A.            │   │
│  │  Deudor: Inmobiliaria XYZ · CLP $12.400.000       │   │
│  │  Vence: 28 jun 2026 (25 días)                     │   │
│  │  ─────────────────────────────────────────────    │   │
│  │  Oferta de Carlos Soto                            │   │
│  │  Anticipo: CLP $9.250.000 (74.6%)                 │   │
│  │  Tasa: 2.10% mensual · Gastos: CLP 85.000         │   │
│  │  Líquido a recibir: CLP $9.165.000                │   │
│  │  Vigencia oferta: hasta 17 jun 2026               │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ── 12 may 2026 ──────────────────────────────────────── │
│                                                          │
│  [●] [evento] Oferta enviada por Carlos Soto             │
│                                                          │
│       ┌─────────────────────────────────────┐           │
│       │ ¿Puede mejorar la tasa a 1.95%?     │           │
│       │                          Juan P.    │           │
│       │                          10:32 · ✓✓ │           │ ← cliente (derecha)
│       └─────────────────────────────────────┘           │
│                                                          │
│  ┌────────────────────────────────────┐                  │
│  │ Puedo bajar a 2.00%, ¿cerramos?    │                  │
│  │ Carlos S.  10:45 · ✓✓              │                  │ ← ejecutivo (izq)
│  └────────────────────────────────────┘                  │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  FOOTER — ACCIONES DE OFERTA (solo cliente)              │
│  [ Rechazar oferta ]              [ Aceptar oferta → ]   │
├──────────────────────────────────────────────────────────┤
│  INPUT DE MENSAJE                                        │
│  ┌────────────────────────────────────────┐ [Enviar ▶]  │
│  │  Escribe un mensaje...                 │             │
│  └────────────────────────────────────────┘             │
└──────────────────────────────────────────────────────────┘
```

---

#### Secciones del componente

**Header del chat**
- Avatar del interlocutor (la contraparte: el ejecutivo si lo ve el cliente, el cliente si lo ve el ejecutivo).
- Nombre completo + financiera (si el ejecutivo pertenece a una).
- Resumen inline de la oferta: monto anticipado, tasa, días de vigencia restantes.
- Días de vigencia en rojo cuando quedan ≤ 2 días.

**Tarjeta de contexto (inicio del hilo) — colapsable**
- Fija al tope del área de mensajes; no forma parte del scroll.
- **Estados: expandida / colapsada.** La preferencia se persiste por `offerId` en `localStorage` para que al reabrir el chat conserve el estado elegido por el usuario.
- **Estado colapsado**: una sola línea con el resumen mínimo — `"Factura #XXXX · Oferta de [Ejecutivo]"` — y un botón/ícono `[▲ Ver]` a la derecha para expandir.
- **Estado expandido**: muestra el contenido completo en dos bloques separados por un divisor:
  - **Bloque factura**: número de factura, nombre del cliente (cedente), nombre del deudor, monto total de la factura, fecha de vencimiento + días restantes.
  - **Bloque oferta**: nombre del ejecutivo, monto anticipado (importe + porcentaje sobre el total), tasa mensual, gastos operacionales, líquido a recibir (monto anticipado − gastos), fecha de vigencia de la oferta.
  - Botón/ícono `[▼ Ocultar]` en el encabezado para colapsar.
- **Estado inicial**: expandida la primera vez que se abre el chat (sin historial previo). Colapsada si el usuario ya tiene mensajes en el hilo (el contexto ya fue leído).
- Fondo diferenciado (surface elevada, borde sutil) para distinguirla de las burbujas en ambos estados.
- Los valores monetarios usan `--font-mono` con `tnum`.
- Si la oferta fue modificada (re-oferta futura), la tarjeta muestra siempre los valores de la oferta vigente más reciente.
- La transición expandir/colapsar usa una animación de altura suave (`height` + `overflow: hidden`).

**Área de mensajes**
- Scroll interno. Los mensajes más recientes quedan al fondo (convención chat).
- Al abrir, el scroll se posiciona automáticamente en el mensaje más reciente.
- Mensajes propios alineados a la derecha; mensajes del interlocutor a la izquierda.
- Separador de fecha entre grupos de mensajes de días distintos.
- Mensajes de sistema (eventos de oferta) centrados, sin burbuja, con estilo sutil.
- Si no hay mensajes aún: bajo la tarjeta de contexto se muestra el texto sutil `"Sin mensajes aún. Inicia la negociación."`.

**Footer de acciones (solo visible para el cliente)**
- Botones "Rechazar oferta" y "Aceptar oferta" fijos encima del input.
- El ejecutivo no ve este footer; en su lugar el footer solo contiene el input.
- "Aceptar oferta" → abre `AcceptOfferConfirmDialog`.
- "Rechazar oferta" → abre confirmación inline con motivo opcional.
- Ambos botones se deshabilitan si la oferta ya no está en estado `ACTIVA`.

**Input de mensaje**
- Textarea autoexpandible (hasta 4 líneas; luego scroll interno del textarea).
- Botón "Enviar" o `Enter` para enviar (Shift+Enter hace salto de línea).
- Estado `disabled` + placeholder `"Chat cerrado"` cuando la oferta está en estado `ACEPTADA`, `RECHAZADA` o `VENCIDA`.

---

#### Tipos de mensaje

| Tipo | Quién lo genera | Visualización |
|------|----------------|---------------|
| `context_card` | Sistema (1 por hilo) | Tarjeta fija al tope con datos de factura + oferta. No es un mensaje; no tiene hora ni autor. |
| `text` | Cliente o ejecutivo | Burbuja con texto, autor, hora y estado de lectura |
| `system:offer_sent` | Sistema | Evento centrado: `"Oferta enviada por [Ejecutivo]"` |
| `system:offer_accepted` | Sistema | Evento centrado destacado (color success): `"Oferta aceptada por [Cliente]"` |
| `system:offer_rejected` | Sistema | Evento centrado (color error): `"Oferta rechazada"` + motivo si lo hay |
| `system:offer_expired` | Sistema | Evento centrado (color warning): `"Esta oferta venció sin ser aceptada"` |

---

#### Estado de lectura de mensajes

| Ícono | Significado |
|-------|-------------|
| `✓` (un check) | Mensaje enviado al servidor |
| `✓✓` (dos checks, gris) | Mensaje entregado / visto por el servidor |
| `✓✓` (dos checks, color acento) | Mensaje leído por el interlocutor |

---

#### Tiempo real — WebSocket

- El canal del chat es `offer:{offerId}`.
- Al abrir el componente, el cliente se suscribe al canal.
- Nuevo mensaje del interlocutor: aparece en el área con animación de entrada suave.
- Si el usuario está en el chat cuando llega un mensaje, se marca como leído automáticamente → se emite evento `read` al servidor.
- Si el usuario **no** está en el chat, el mensaje se cuenta como no leído → badge en la tarjeta de oferta y en la notificación.

---

#### Dónde se muestra

| Contexto | Cómo se muestra |
|----------|----------------|
| **Cliente — §6.3** (Detalle de Factura y Ofertas) | Panel lateral derecho al seleccionar una oferta de la lista. En `xs–md`: Full Screen desde bottom sheet al tocar una oferta. |
| **Ejecutivo — §7** (Ofertador) | Panel lateral derecho que reemplaza la Calculadora (Sección 4) cuando el ejecutivo selecciona "Ver chat" sobre una factura donde tiene oferta activa. En `xs–md`: Full Screen. |

---

#### Comportamiento responsivo

| Breakpoint | Comportamiento |
|------------|---------------|
| `md+` (desktop) | Panel lateral fijo dentro del layout de la pantalla, con altura completa. |
| `xs–md` (mobile) | Se abre como pantalla Full Screen (posición `fixed; inset: 0`). Barra de navegación de regreso (`← Volver`) en el header. El footer de acciones y el input quedan fijos en la parte inferior con área de toque ≥ 44×44px. El teclado virtual empuja el input hacia arriba (`env(safe-area-inset-bottom)`). |

---

#### Historias de usuario

- `US-CH01` — Como cliente, quiero enviar mensajes al ejecutivo sobre su oferta, para negociar las condiciones antes de aceptar.
- `US-CH02` — Como ejecutivo, quiero recibir mensajes del cliente en tiempo real, para responder y ajustar mi oferta de forma ágil.
- `US-CH03` — Como usuario, quiero saber si el interlocutor leyó mi mensaje, para saber si debo hacer seguimiento.
- `US-CH04` — Como cliente, quiero poder aceptar o rechazar la oferta directamente desde el chat, para no tener que salir de la conversación.
- `US-CH05` — Como usuario, quiero ver los eventos clave de la oferta (enviada, aceptada, rechazada) dentro del chat, para tener un historial unificado de la negociación.
- `US-CH06` — Como usuario en mobile, quiero que el chat sea full screen con el teclado bien gestionado, para poder escribir cómodamente desde el teléfono.

#### Criterios de aceptación

- [ ] El chat está scoped a una oferta (`offer:{offerId}`); cada oferta tiene su propio hilo.
- [ ] Header muestra: avatar + nombre del interlocutor, financiera (si aplica), monto/tasa de la oferta, días de vigencia (rojo si ≤ 2 días).
- [ ] La **tarjeta de contexto** es fija al tope del hilo (fuera del scroll) y es colapsable. Estado inicial: expandida si no hay mensajes previos; colapsada si ya hay historial.
- [ ] Estado colapsado: una línea con `"Factura #XXXX · Oferta de [Ejecutivo]"` + botón `[▲ Ver]`.
- [ ] Estado expandido: dos bloques (factura + oferta) con todos los datos. Botón `[▼ Ocultar]` para colapsar.
- [ ] La preferencia de estado (colapsada/expandida) se persiste por `offerId` en `localStorage`.
- [ ] La transición entre estados tiene animación de altura suave. Los valores monetarios usan fuente mono con `tnum`.
- [ ] Mensajes propios a la derecha; mensajes del interlocutor a la izquierda.
- [ ] Separadores de fecha entre grupos de días distintos.
- [ ] Mensajes de sistema centrados sin burbuja, con color semántico según tipo de evento.
- [ ] Empty state cuando no hay mensajes aún.
- [ ] Estados de lectura: `✓` (enviado), `✓✓` gris (entregado), `✓✓` acento (leído).
- [ ] Input autoexpandible (hasta 4 líneas). `Enter` envía; `Shift+Enter` salta línea.
- [ ] Input deshabilitado cuando la oferta está en estado `ACEPTADA`, `RECHAZADA` o `VENCIDA`.
- [ ] Footer de acciones (Aceptar / Rechazar) visible solo para el cliente.
- [ ] Mensajes nuevos llegan en tiempo real vía WebSocket sin recargar.
- [ ] Al abrir el chat el scroll se posiciona en el mensaje más reciente.
- [ ] Al recibir un mensaje con el chat abierto, se emite evento `read` automáticamente.
- [ ] En `xs–md`: se abre Full Screen con barra `← Volver` en el header, input fijo en la parte inferior respetando `safe-area-inset-bottom`.

#### Componentes

- `NegotiationChat` — Componente contenedor, gestiona suscripción WS y estado del chat
- `ChatHeader` — Header con datos del interlocutor y resumen de oferta
- `ChatContextCard` — Tarjeta colapsable fija al tope del hilo (fuera del scroll). Estado expandido/colapsado persistido por `offerId` en `localStorage`. Animación de altura suave.
- `ChatMessageList` — Área scrollable de mensajes con separadores de fecha
- `ChatBubble` — Burbuja individual: texto, autor, hora, estado de lectura
- `ChatSystemEvent` — Mensaje de sistema centrado (oferta enviada / aceptada / rechazada / vencida)
- `ChatInput` — Textarea autoexpandible + botón enviar
- `ChatOfferActions` — Footer de Aceptar / Rechazar (solo cliente, oculto si oferta no activa)

---

## 7. Pantallas — MFE Ofertador (`mfe-ofertador`)

**Título en UI**: Marketplace de Facturas

### Layout general

La pantalla se divide en **4 secciones** que trabajan en conjunto. Al cargar, solo la Columna 1 tiene contenido; las demás se activan al seleccionar una factura.

```
┌──────────┬─────────────────────────────────────────────────────┐
│          │        SECCIÓN 2 — KPIs + Cupo (Header)             │
│          ├──────────────────────────┬──────────────────────────┤
│ COL. 1   │  SECCIÓN 3              │  SECCIÓN 4               │
│ Lista    │  Visor de factura        │  Calculadora de          │
│ facturas │  + Notas OCR             │  parámetros de           │
│ (1/5)    │                          │  liquidación             │
│          │                          │                          │
└──────────┴──────────────────────────┴──────────────────────────┘
  1/5 ancho            ←————————— 4/5 ancho ——————————→
```

**Responsive**:
- `lg+`: layout de 4 secciones como se muestra arriba.
- `md`: Columna 1 colapsa a un drawer lateral; las secciones 2-4 ocupan pantalla completa.
- `xs–sm`: flujo secuencial de pantallas (lista → detalle → calculadora).

---

### 7.1 Columna 1 — Lista de Facturas del Marketplace

**Descripción**: Panel lateral izquierdo (1/5 del ancho). Lista de tarjetas compactas de facturas en estado `PUBLICADA` u `OFERTADA`, actualizadas en tiempo real vía WebSocket. Al hacer clic en una tarjeta se activan las secciones 2, 3 y 4.

#### Contenedor y altura

La columna está envuelta en una card que **no supera el alto del viewport del navegador** (`height: 100vh` menos el alto del top-navbar). El contenido de tarjetas es scrollable internamente; el encabezado con el buscador y los filtros permanece fijo (sticky) en la parte superior de la card.

```
┌─────────────────────────────────┐  ↑
│  🔍 [Buscar por deudor o folio] │  │ sticky
│  [ Preferidos ] [ Recientes ]   │  │ sticky
│  [ Alta liquidez ]              │  ↓ sticky
├─────────────────────────────────┤
│  ┌───────────────────────────┐  │  ↑
│  │ Factura #123  Deudor SA   │  │  │
│  │ CLP $10.150.413           │  │  │
│  │ [chip] 3 ofertas · 2.20%  │  │  │ scroll
│  └───────────────────────────┘  │  │ interno
│  ┌───────────────────────────┐  │  │
│  │ ...                       │  │  │
│  └───────────────────────────┘  │  ↓
└─────────────────────────────────┘
```

#### Buscador

- Input de texto en la parte superior de la card.
- Filtra en tiempo real por nombre de deudor o número de factura (coincidencia parcial, case-insensitive).
- Al escribir, la lista se filtra sin recargar desde el servidor (filtro local sobre las tarjetas ya cargadas).
- Placeholder: `"Buscar por deudor o folio..."`.

#### Filtros rápidos (chips/botones toggle)

Los filtros son acumulables (pueden activarse varios a la vez) y se aplican sobre el resultado del buscador:

| Filtro | Lógica |
|--------|--------|
| **Preferidos** | Muestra solo facturas de clientes con los que el ejecutivo ha cerrado al menos una operación anterior. |
| **Más recientes** | Ordena por fecha de publicación descendente (más nuevas primero). Activo por defecto. |
| **Alta liquidez** | Muestra facturas con ≥ N días al vencimiento (umbral configurable, p. ej. ≥ 30 días). |

- Al activar **Preferidos**, las tarjetas de clientes no preferidos se ocultan (no se eliminan del WebSocket).
- Al activar **Alta liquidez**, las tarjetas con poco tiempo al vencimiento se ocultan.
- Si la combinación de filtros no arroja resultados, se muestra estado vacío: `"No hay facturas que coincidan con los filtros activos."`.

#### Tarjeta de factura en la lista

```
┌─────────────────────────────────┐
│  Factura #123   Nombre Deudor   │
│  CLP $10.150.413                │
│  [chip] Sin ofertas activas     │
│   —o—                           │
│  [chip] 3 ofertas · Tasa: 2.20% │ ← tasa a batir
└─────────────────────────────────┘
```

- El chip cambia según si hay ofertas: `Sin ofertas activas` (neutro) o `N ofertas · Tasa: X.XX%` (destacado con la tasa más baja activa = tasa a batir).
- Tarjeta seleccionada tiene estado visual activo (borde o fondo destacado).
- Las tarjetas se actualizan en tiempo real: nueva factura publicada → aparece al tope; factura retirada → desaparece.
- Si el ejecutivo ya tiene una oferta activa sobre esa factura, la tarjeta muestra un indicador `Tu oferta activa`.
- Clientes preferidos pueden tener un indicador visual sutil (ej. ícono de estrella o borde de color) para identificarlos sin necesidad de activar el filtro.

**Historias de usuario**

- `US-O01` — Como ejecutivo, quiero ver la lista de facturas disponibles con su monto y la tasa más baja del mercado, para identificar rápidamente las mejores oportunidades sin entrar al detalle.
- `US-O02` — Como ejecutivo, quiero que la lista se actualice en tiempo real cuando aparecen nuevas facturas o desaparecen las retiradas, para trabajar siempre sobre datos vigentes.
- `US-O03` — Como ejecutivo, quiero ver en la tarjeta si ya tengo una oferta activa sobre esa factura, para no duplicar mi trabajo.
- `US-O04` — Como ejecutivo, quiero filtrar la lista para ver solo facturas de mis clientes preferidos, para priorizar relaciones de confianza establecidas.
- `US-O05` — Como ejecutivo, quiero filtrar por alta liquidez para ver solo facturas con tiempo suficiente al vencimiento, para evitar operaciones de riesgo de plazo.
- `US-O06` — Como ejecutivo, quiero buscar por nombre de deudor o número de factura, para encontrar una factura específica sin desplazarme por toda la lista.

**Criterios de aceptación**

- [ ] La card de la columna tiene `height: 100vh` menos el alto del top-navbar. El scroll es interno; el buscador y los filtros son sticky.
- [ ] Buscador filtra localmente en tiempo real por nombre deudor (parcial, case-insensitive) o número de factura.
- [ ] Filtro **Preferidos**: activo/inactivo por toggle. Cuando activo, oculta tarjetas de clientes sin historial con el ejecutivo.
- [ ] Filtro **Más recientes**: activo por defecto. Ordena lista por fecha de publicación descendente.
- [ ] Filtro **Alta liquidez**: activo/inactivo por toggle. Oculta facturas con menos de N días al vencimiento (N configurable).
- [ ] Los filtros son acumulables entre sí y con el buscador.
- [ ] Estado vacío si ninguna tarjeta pasa los filtros activos.
- [ ] Tarjeta muestra: N° factura, nombre deudor, monto CLP formateado, chip de ofertas.
- [ ] Chip con tasa a batir se actualiza en tiempo real cuando otra ejecutiva cambia su oferta.
- [ ] Al hacer clic en una tarjeta, se cargan las secciones 2, 3 y 4 con los datos de esa factura.
- [ ] Si el ejecutivo tiene oferta activa en esa factura, la tarjeta lo indica visualmente.
- [ ] Facturas retiradas desaparecen automáticamente de la lista (evento WebSocket).
- [ ] Clientes preferidos tienen indicador visual en su tarjeta (independiente del filtro activo).

**Componentes**

- `MarketplaceInvoiceList` — Card contenedora con `height: 100vh`, sticky header, scroll interno
- `InvoiceSearchInput` — Buscador local por deudor o folio
- `MarketplaceFilterBar` — Barra de chips/toggle para Preferidos, Más recientes, Alta liquidez
- `MarketplaceInvoiceCard` — Tarjeta compacta de factura
- `OfferChip` — Chip dinámico: "Sin ofertas activas" / "N ofertas · Tasa X.XX%"
- `MyActiveOfferBadge` — Indicador de oferta propia activa sobre la factura
- `PreferredClientBadge` — Indicador visual de cliente preferido en la tarjeta

---

### 7.2 Sección 2 — KPIs del Cliente y Deudor (Header)

**Descripción**: Header que aparece al seleccionar una factura. Muestra datos contextuales del cliente (cedente) y del deudor para que el ejecutivo evalúe el riesgo antes de ofertar. Se divide en dos bloques: KPIs generales y datos de cupo.

#### Bloque A — KPIs del cliente y deudor

> **Regla de privacidad**: los datos históricos y financieros del cliente son sensibles. El ejecutivo **solo puede ver métricas calculadas sobre las operaciones que él mismo ha cursado con ese cliente**, nunca datos de operaciones con otros ejecutivos.

| KPI | Fuente | Alcance | Confirmado |
|-----|--------|---------|:----------:|
| Nombre / RUT cliente | Perfil del cliente | Global | ✅ |
| Nombre / RUT deudor | Factura | Global | ✅ |
| Días al vencimiento | Fecha vencimiento factura — calculado al momento | Global | ✅ |
| Operaciones cerradas con este ejecutivo | Sistema — N° de facturas financiadas entre este ejecutivo y este cliente | Solo este ejecutivo | ✅ |
| Monto promedio financiado | Sistema — promedio de monto anticipado en esas operaciones | Solo este ejecutivo | ✅ |
| Tasa promedio pactada | Sistema — tasa promedio de esas operaciones | Solo este ejecutivo | ✅ |
| Calificación del deudor | SII / bureau de crédito | Global | ❌ Fuera del MVP |

#### Bloque B — Cupo

| Dato | Descripción |
|------|-------------|
| Cupo total asignado | Límite máximo de financiamiento habilitado para el deudor |
| Cupo disponible | Cupo total − cupo utilizado actualmente |
| Cupo utilizado | Monto total en operaciones activas con este deudor |

> ⚠️ Los criterios de asignación de cupo por deudor están pendientes de definición.

**Historias de usuario**

- `US-O04` — Como ejecutivo, quiero ver KPIs del cliente y del deudor al seleccionar una factura, para evaluar el riesgo de la operación sin consultar fuentes externas.
- `US-O05` — Como ejecutivo, quiero ver el cupo disponible del deudor, para saber si mi oferta puede superar ese límite antes de calcularla.

**Criterios de aceptación**

- [ ] Header se renderiza al seleccionar una factura; vacío o con skeleton antes de seleccionar.
- [ ] Muestra datos del cliente (nombre, RUT) y del deudor (nombre, RUT).
- [ ] Muestra días al vencimiento calculado en tiempo real.
- [ ] Muestra cupo total, disponible y utilizado del deudor.
- [ ] Si el monto anticipado calculado en la Columna 4 supera el cupo disponible, se muestra alerta en este header (vinculado con HU-05 de cupo, referenciada en HU-06).

**Componentes**

- `InvoiceContextHeader` — Contenedor del header con los dos bloques
- `ClientKpiBlock` — Bloque de KPIs del cliente y deudor
- `DeudorCupoBlock` — Bloque de cupo total / disponible / utilizado
- `CupoExceededAlert` — Alerta inline cuando el monto anticipado supera el cupo disponible

---

### 7.3 Sección 3 — Visor de Factura y Notas OCR

**Descripción**: Visualizador del PDF de respaldo subido por el cliente. Debajo del visor se muestran las notas OCR detectadas por el sistema como segunda validación para el ejecutivo.

**Historias de usuario**

- `US-O06` — Como ejecutivo, quiero ver el PDF de la factura directamente en pantalla, para verificar visualmente los datos antes de calcular mi oferta.
- `US-O07` — Como ejecutivo, quiero ver las notas OCR del sistema debajo del visor, para detectar incongruencias en los datos de la factura que el cliente pudo haber pasado por alto.

**Criterios de aceptación**

- [ ] Visor de PDF embebido (scroll interno). Si no hay PDF disponible, muestra estado vacío: `"El cliente no adjuntó respaldo PDF."`.
- [ ] Notas OCR listadas debajo del visor, identificadas por campo (mismas notas generadas en el flujo del publicador).
- [ ] Las notas son de solo lectura para el ejecutivo (no puede descartarlas).
- [ ] En pantalla pequeña, el visor y las notas se desplazan a una sección colapsable.

**Componentes**

- `InvoicePdfViewer` — Visor embebido de PDF (reutilizable)
- `OcrNotesList` — Lista de notas OCR (reutilizable desde MFE publicador, modo solo lectura)

---

### 7.4 Sección 4 — Calculadora de Parámetros de Liquidación

**Descripción**: Panel derecho para simular y enviar la oferta firme. Toda la lógica de cálculo es en el frontend con Angular Signals (sin llamadas HTTP al servidor hasta el envío). Referencia: HU-06, HU-07, HU-08, HU-09, HU-10.

#### Inputs de la calculadora (HU-06)

| Campo | Control | Rango / restricción |
|-------|---------|---------------------|
| % Anticipo | Input numérico + slider | 10% – 100%. Default: 100% |
| Tasa de interés mensual (%) | Input decimal 2 dec. + botón Match & Beat | 0% – máximo regulatorio (configurable desde backend) |
| Comisión de Estructuración | Input monto CLP | Opcional, default $0 |
| Gastos Operacionales | Input monto CLP | Opcional, default $0 |
| Gasto de Contrato | Input monto CLP | Opcional, default $0 |
| Gasto de Apertura | Input monto CLP | Opcional, default $0. Pre-llenado si el cliente es nuevo. |

- Todos los campos recalculan la pre-liquidación en < 16ms al modificarse (Angular Signals).
- Si el usuario borra un campo, el sistema restaura el valor en `$0` / `0%`.
- Al cambiar de factura, el formulario se reinicia (⚠️ confirmar según EB-04 de HU-06).

#### Botón Match & Beat (HU-08)

- Ubicado junto al campo de Tasa de Interés.
- Muestra siempre el dato de referencia: `Mejor oferta actual: X.XX%` o `Sin ofertas activas`.
- Al presionar: establece la tasa en `(mejor tasa del mercado − 0.05%)` y recalcula.
- Deshabilitado si no hay ofertas competidoras. Si la tasa ya es la más competitiva, muestra tooltip informativo.
- El diferencial de 0.05% es configurable desde el backend.

#### Pre-Liquidación explícita (HU-07)

Tarjeta de alto contraste (fondo `#0D1655` / `--navy-deep`) con actualización en tiempo real:

```
ESTRUCTURA DE LIQUIDACIÓN
───────────────────────────────────────────
Plazo de la Operación:              [N] días
───────────────────────────────────────────
Monto Anticipado ([X]%):       $XX.XXX.XXX
Excedente Retenido ([Y]%):      $X.XXX.XXX
───────────────────────────────────────────
(-) Diferencia de Precio (Interés): -$XXX.XXX
(-) Subtotal Comisiones/Gastos:     -$XX.XXX
(-) IVA (19% sobre Gastos):         -$XX.XXX
═══════════════════════════════════════════
GIRO LÍQUIDO AL CLIENTE:       $XX.XXX.XXX
───────────────────────────────────────────
Margen Bruto Operación:         $XXX.XXX
```

> Regla tributaria clave 🇨🇱: el IVA 19% aplica **solo** sobre gastos/comisiones. La Diferencia de Precio (interés) es exenta de IVA.

Estado inicial (sin factura seleccionada): `"Selecciona una factura para simular la liquidación."`

#### Alerta de interferencia en tiempo real (HU-09)

- Si el cliente modifica datos de la factura mientras el ejecutivo está simulando, se activa un **overlay bloqueante** sobre la Columna 4: `"Los datos de la factura han cambiado. Recalculando parámetros..."`.
- Al recibir los datos nuevos, el overlay se quita, se recalcula con los mismos parámetros del ejecutivo y se muestra un toast informativo.
- Si la factura fue retirada: overlay permanente `"Esta factura ya no está disponible."`, botón de oferta bloqueado, tarjeta desaparece de la Columna 1.
- Los parámetros ingresados por el ejecutivo (tasa, anticipo, comisiones) se preservan tras el recálculo.

#### Envío de oferta — Modal de doble confirmación (HU-10)

- Botón `"Enviar Oferta Firme"`: habilitado solo cuando hay factura seleccionada, formulario válido, sin alertas de interferencia ni cupo agotado.
- Al presionar → overlay oscuro + modal centrado con resumen en lenguaje humano:

> *"Vas a transferir $10.150.413 al cliente por la factura #45902 de CENCOSUD S.A. Dejarás retenidos $1.875.000 como excedente. Tu mesa ganará $373.437 en 45 días. ¿Confirmar oferta?"*

- **Botones del modal**: `"Sí, publicar oferta"` (verde, spinner al procesar) / `"Cancelar"` (neutro).
- Cancelar cierra el modal sin perder el formulario.
- Éxito → toast verde + tarjeta en Columna 1 actualizada con nuevo conteo de ofertas.
- Error → mensaje dentro del modal, botones rehabilitados para reintentar.
- `Escape` cierra el modal si no está procesando.

**Historias de usuario**

- `US-O08` — Como ejecutivo, quiero simular distintos escenarios de anticipo y tasa con recálculo instantáneo, para encontrar la oferta más rentable sin salir del sistema.
- `US-O09` — Como ejecutivo, quiero que el botón Match & Beat ajuste automáticamente mi tasa para ser la más competitiva del mercado, para no perder tiempo calculando manualmente el diferencial.
- `US-O10` — Como ejecutivo, quiero ver la estructura de liquidación completa con giro líquido y margen, para tener certeza del resultado financiero antes de comprometer la oferta.
- `US-O11` — Como ejecutivo, quiero recibir una alerta y ver el recálculo cuando el cliente modifica su factura, para no enviar una oferta basada en datos desactualizados.
- `US-O12` — Como ejecutivo, quiero confirmar mi oferta en un modal con resumen en lenguaje simple, para evitar errores por clic accidental en operaciones de alto valor.

**Criterios de aceptación**

- [ ] Todos los inputs recalculan la pre-liquidación en < 16ms (Angular Signals, sin HTTP).
- [ ] Slider de anticipo actualiza `Monto Anticipado` y `Excedente Retenido` en tiempo real.
- [ ] Tasa máxima y mínima obtenidas desde el backend al iniciar sesión (valores derivados de la API del Banco Central, manejados a nivel global en el frontend como configuración de aplicación). No hardcodeadas. Campos vacíos vuelven a $0/0%.
- [ ] Botón Match & Beat: ajusta tasa a `(mejor tasa − diferencial configurable)`, muestra siempre la tasa a batir como referencia.
- [ ] IVA calculado únicamente sobre gastos/comisiones, nunca sobre el interés.
- [ ] Todos los montos formateados en CLP sin decimales (ej: `$10.150.413`).
- [ ] Overlay de interferencia bloquea el formulario y el botón de envío al detectar cambio en la factura vía WebSocket. Preserva parámetros del ejecutivo al recalcular.
- [ ] Botón "Enviar Oferta Firme" deshabilitado si: no hay factura seleccionada, formulario inválido, alerta de interferencia activa, cupo agotado.
- [ ] Modal de confirmación muestra resumen en lenguaje humano con valores dinámicos. Spinner al procesar. Toast de éxito o error dentro del modal.
- [ ] `Escape` cierra el modal si no está procesando.

**Componentes**

- `LiquidationCalculator` — Contenedor principal de la calculadora (Sección 4)
- `AnticipoPctField` — Input numérico + slider para % de anticipo
- `TasaField` — Input de tasa con botón Match & Beat y referencia de tasa a batir integrada
- `GastosFieldGroup` — Grupo de 4 inputs de gastos/comisiones
- `PreLiquidacionCard` — Tarjeta de estructura de liquidación con actualización reactiva (Angular Signals)
- `CalculatorInterferenceOverlay` — Overlay bloqueante con mensaje de recálculo (HU-09)
- `SendOfferButton` — Botón "Enviar Oferta Firme" con lógica de habilitación
- `OfferConfirmModal` — Modal de doble confirmación con resumen en lenguaje humano (HU-10)

---

## 8. Pantallas — MFE Dashboard

> ⬜ No iniciado. Las siguientes historias son un punto de partida para la discusión.

### 8.1 Dashboard Cedente

**Historias de usuario**

- `US-D01` — Como cliente, quiero ver un resumen de mis facturas por estado, para entender el estado de mi pipeline de financiamiento de un vistazo.
- `US-D02` — Como cliente, quiero ver el capital total recibido vía factoring en un período, para controlar mi flujo de caja.
- `US-D03` — Como cliente, quiero ver alertas de facturas próximas a vencer sin ofertas, para actuar antes de que pierdan interés.

**KPIs**

| KPI | Descripción | Estado fuente |
|-----|-------------|---------------|
| **Facturas activas** | Conteo dividido por estado: Publicada / Con oferta / Financiada / Verificando pago | `PUBLICADA`, `OFERTADA`, `FINANCIADA`, `PENDIENTE_VERIFICACION_PAGO` |
| **Capital por recibir** | Suma de `montoAnticipado` de facturas en `FINANCIADA` + `PENDIENTE_VERIFICACION_PAGO` | — |
| **Capital recibido (período)** | Suma de `montoAnticipado` de facturas `PAGADA` en el período seleccionado | `PAGADA` |
| **Costo promedio de financiamiento** | Tasa ponderada promedio de las ofertas aceptadas en el período | — |
| **Tiempo promedio para financiarse** | Días promedio entre `PUBLICADA` y `FINANCIADA` | — |
| **⚠️ Facturas en riesgo** | Facturas en `PUBLICADA` con menos de N días al vencimiento sin ninguna oferta | `PUBLICADA` |

**Selector de período**: Último mes / Últimos 3 meses / Últimos 6 meses / Este año / Todo. Los KPIs numéricos muestran variación porcentual respecto al período anterior (ej. `+12% vs mes anterior`). Valores monetarios en CLP sin decimales.

---

### 8.2 Mis Ofertas (Ejecutivo)

**Descripción**: Historial de todas las ofertas enviadas por el ejecutivo, con su estado actual.

**Historias de usuario**

- `US-D04` — Como ejecutivo, quiero ver todas las ofertas que he enviado y su estado actual, para hacer seguimiento de mis operaciones.
- `US-D05` — Como ejecutivo, quiero saber cuándo una oferta mía fue aceptada, para proceder con la liquidación.
- `US-D06` — Como ejecutivo, quiero filtrar mis ofertas por estado (activa, aceptada, rechazada, vencida), para gestionar mi pipeline.

**Criterios de aceptación**

- [ ] Lista con: factura (folio / deudor), monto ofertado, tasa, fecha oferta, estado oferta, estado factura.
- [ ] Notificación destacada cuando una oferta pasa a `ACEPTADA`.
- [ ] Filtros por estado de oferta.
- [ ] Acceso rápido al chat de negociación desde la lista.

**Componentes**

- `MyOffersTable` — Tabla de ofertas propias con filtros
- `OfferStatusBadge` — Badge de estado de oferta (activa / aceptada / rechazada / vencida)

---

### 8.3 Dashboard Ejecutivo

**Historias de usuario**

- `US-D07` — Como ejecutivo, quiero ver el capital que tengo desplegado actualmente, para controlar mi exposición total.
- `US-D08` — Como ejecutivo, quiero ver mi cupo disponible frente al desplegado, para saber si tengo capacidad para nuevas operaciones.
- `US-D09` — Como ejecutivo, quiero ver mis retornos acumulados en el período, para medir la rentabilidad de mi cartera.
- `US-D10` — Como ejecutivo, quiero ver mi pipeline de ofertas activas, para priorizar el seguimiento de las que aún no tienen respuesta.

**KPIs**

| KPI | Descripción | Estado fuente |
|-----|-------------|---------------|
| **Capital desplegado** | Suma de `montoAnticipado` de operaciones activas (`FINANCIADA` + `PENDIENTE_VERIFICACION_PAGO`) | — |
| **Capital disponible** | Cupo total configurado − capital desplegado | — |
| **Retorno proyectado** | Suma de intereses esperados de la cartera activa (interés × plazo restante por factura) | — |
| **Retorno realizado (período)** | Intereses efectivamente cobrados de facturas `PAGADA` en el período | `PAGADA` |
| **Tasa promedio de cartera** | Tasa ponderada de las operaciones activas | — |
| **Ofertas activas** | Ofertas enviadas sin respuesta aún | — |
| **Operaciones cerradas (período)** | Facturas que llegaron a `PAGADA` en el período | `PAGADA` |
| **Ticket promedio** | Monto anticipado promedio por operación en el período | — |

**Selector de período**: Último mes / Últimos 3 meses / Últimos 6 meses / Este año / Todo. Los KPIs numéricos muestran variación porcentual respecto al período anterior. Valores monetarios en CLP sin decimales.

---

## 9. Pantallas — Autenticación y Perfil

### 9.0 Registro de Usuario

**Descripción**: Flujo de creación de cuenta personal. El registro siempre comienza por la cuenta personal (Fase 1). La vinculación a una organización es una Fase 2 separada que ocurre en el primer login post-registro.

#### Arquitectura del flujo: dos fases independientes

```
Fase 1 — Cuenta personal (durante el registro)
  └─► Wizard de 3 pasos → verificación de email → portal vacío

Fase 2 — Organización (primer login post-registro)
  ├─► Crear nueva organización (wizard separado)
  └─► Unirse a organización existente (ingresando código de org)
```

Esta separación permite que un usuario se una a múltiples organizaciones cedentes más adelante sin rehacer su cuenta personal, y que el onboarding de organización pueda interrumpirse y retomarse.

#### Paso 0 — Bifurcación de rol

Pantalla previa al wizard personal. El rol es **exclusivo y fijo** para siempre:

```
┌──────────────────────────────────────────────────────────┐
│  ¿Qué describe mejor tu situación?                       │
│                                                          │
│  ┌─────────────────────┐  ┌──────────────────────────┐   │
│  │  🏢                 │  │  🏦                      │   │
│  │  Soy empresa        │  │  Soy ejecutivo de        │   │
│  │  cedente            │  │  financiera              │   │
│  │  Vendo facturas     │  │  Ofrezco financiamiento  │   │
│  └─────────────────────┘  └──────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
```

#### Paso 1 — Datos personales

| Campo | Validación |
|-------|-----------|
| Nombre | Requerido |
| Apellido | Requerido |
| RUT personal | Máscara `XX.XXX.XXX-K`. Validación de dígito verificador **inline** mientras el usuario escribe. Muestra ✅ al pasar. |
| Email | Formato válido. Requerido. |
| Teléfono | Prefijo `+56` fijo (no seleccionable). Campo numérico. |

#### Paso 2 — Credenciales

| Campo | Validación |
|-------|-----------|
| Contraseña | Medidor de fortaleza visual (4 niveles con color). Toggle de visibilidad. |
| Confirmar contraseña | Debe coincidir. Validación en tiempo real. |
| T&C personales | Checkbox obligatorio antes de avanzar. |

#### Paso 3 — Verificación de email

- OTP de 6 dígitos enviado al email registrado.
- Auto-foco en el siguiente dígito al ingresar cada uno.
- Botón "Reenviar código" con countdown de 60 segundos.
- Al validar el OTP: redirige al portal → disparar Fase 2 de org.

#### Fase 2 — Onboarding de organización (post-registro)

Si el usuario no pertenece a ninguna organización al ingresar al portal, se muestra un **estado intermedio** (no el dashboard vacío):

```
┌─────────────────────────────────────────────────────┐
│  Para comenzar, configura tu organización.          │
│                                                     │
│  [ + Crear nueva organización ]                     │
│  [ Unirme a una organización existente ]            │
└─────────────────────────────────────────────────────┘
```

Este estado persiste hasta que el usuario complete al menos una de las dos acciones.

**Historias de usuario**

- `US-R01` — Como nuevo usuario, quiero elegir mi rol antes de registrarme, para entender desde el inicio si soy cedente o ejecutivo.
- `US-R02` — Como nuevo usuario, quiero ver la validación de mi RUT en tiempo real mientras lo escribo, para saber si es correcto sin esperar al envío del formulario.
- `US-R03` — Como nuevo usuario, quiero verificar mi email con un código OTP, para no depender de que el link llegue al dispositivo correcto.
- `US-R04` — Como nuevo usuario, quiero ver un estado intermedio claro si no pertenezco a ninguna organización, para saber exactamente qué debo hacer antes de poder operar.

**Criterios de aceptación**

- [ ] Pantalla de bifurcación de rol antes del wizard. La selección es vinculante (no editable después).
- [ ] Wizard de 3 pasos con barra de progreso.
- [ ] RUT personal con máscara `XX.XXX.XXX-K` y validación de dígito verificador inline.
- [ ] Medidor de fortaleza de contraseña con 4 niveles visuales. Toggle para mostrar/ocultar contraseña.
- [ ] OTP de 6 dígitos con auto-foco y countdown de 60s para reenvío.
- [ ] Al completar el registro sin organización: portal muestra estado intermedio con dos CTAs (crear org / unirse a org).
- [ ] El onboarding de org puede interrumpirse y retomarse en el próximo login.
- [ ] Layout desktop: panel izquierdo fijo con ilustración/value prop, panel derecho con el formulario. En móvil: solo formulario.

**Componentes**

- `RegistrationPage` — Contenedor del flujo de registro
- `RoleSelectionStep` — Pantalla de bifurcación cedente / ejecutivo
- `PersonalDataStep` — Paso 1: datos personales con validación RUT inline
- `CredentialsStep` — Paso 2: contraseña con medidor + T&C
- `EmailVerificationStep` — Paso 3: OTP de 6 dígitos
- `RutInput` — Input con máscara `XX.XXX.XXX-K` y validación de DV en tiempo real (reutilizable en org también)
- `PasswordStrengthMeter` — Indicador visual de fortaleza (reutilizable)
- `OtpInput` — Grid de 6 dígitos con auto-foco secuencial
- `NoOrganizationGate` — Estado intermedio post-registro (crear / unirse a org)

---

### 9.1 Login

**App:** `app-login` (`login.{APP_DOMAIN}`)

**Descripción**: Aplicación Angular standalone independiente del portal. Maneja el login, la recuperación de contraseña y el inicio del flujo PKCE. Al autenticar con éxito, redirige al Portal (`app.{APP_DOMAIN}/auth/callback`) para que este complete el intercambio PKCE y establezca la sesión.

> ⚠️ Login con correo electrónico **no está implementado** actualmente. El identificador de acceso es el nombre de usuario.

#### Layout general

Mismo patrón que el registro: panel izquierdo fijo con branding, panel derecho con el formulario. En `xs–md` el panel izquierdo desaparece y solo se muestra el formulario centrado.

```
┌──────────────────────────┬──────────────────────────────┐
│                          │                              │
│   Logo Factor            │   Iniciar sesión             │
│                          │                              │
│   "Financiamiento        │   Nombre de usuario          │
│   para empresas          │   ┌──────────────────────┐   │
│   que no esperan."       │   │                      │   │
│                          │   └──────────────────────┘   │
│   [ilustración / patrón  │                              │
│    abstracto en          │   Contraseña            [👁]  │
│    tonos navy/teal]      │   ┌──────────────────────┐   │
│                          │   │                      │   │
│                          │   └──────────────────────┘   │
│                          │                              │
│                          │   [ ● Error inline — mensaje ]│
│                          │                              │
│                          │   ┌──────────────────────┐   │
│                          │   │   Iniciar sesión      │   │
│                          │   └──────────────────────┘   │
│                          │                              │
│                          │   ¿Olvidaste tu contraseña?  │
│                          │                              │
│                          │   ─────────────────────────  │
│                          │   ¿No tienes cuenta?         │
│                          │   Regístrate →               │
└──────────────────────────┴──────────────────────────────┘
  ←── 2/5 ancho ──→           ←── 3/5 ancho ──→
```

#### Flujo principal

1. Usuario ingresa nombre de usuario + contraseña → clic en "Iniciar sesión".
2. Spinner en el botón mientras procesa.
3. **Éxito**: redirige al portal según el rol del usuario (`/publicador` para clientes, `/ofertador` para ejecutivos).
4. **Credenciales incorrectas**: mensaje de error inline genérico — `"Nombre de usuario o contraseña incorrectos."` — sin distinguir si el usuario existe o no. El formulario no se limpia.
5. **Sesión activa en otro dispositivo**: el login cierra la sesión anterior y continúa normalmente. Se puede mostrar un toast informativo: `"Se cerró tu sesión anterior en otro dispositivo."`.

> **Implementación técnica — PKCE**  
> El login es un flujo de 2 pasos contra `ms-auth` (puerto 3000):
> 1. `POST /security/authenticate` → body: `{ username, password, code_challenge, typeDevice: "WEB" }` → recibe URL con `code`.
> 2. `POST /security/callback` → body: `{ code, codeVerifier, typeDevice: "WEB" }` → recibe cookies `auth.session` + `auth.refresh`.
>
> El Angular service debe generar el par `code_verifier` / `code_challenge` (SHA-256 + base64url) **antes** de llamar al paso 1. Ver §14.1 para el flujo completo.

#### Flujo de recuperación de contraseña

El flujo tiene 3 pantallas/estados dentro del mismo espacio derecho (el panel izquierdo permanece fijo):

**Pantalla A — Solicitar recuperación**

```
   Recuperar contraseña
   ← Volver al login

   Ingresa tu correo registrado y te
   enviaremos un enlace de recuperación.

   Correo electrónico
   ┌──────────────────────────┐
   │                          │
   └──────────────────────────┘

   ┌──────────────────────────┐
   │   Enviar enlace           │
   └──────────────────────────┘
```

- Validación de formato de email al enviar.
- **Respuesta siempre positiva** sin importar si el email existe en el sistema (evita enumeración de usuarios): `"Si ese correo está registrado, recibirás un enlace en los próximos minutos."`.
- Link `← Volver al login` cancela el flujo.

> Campo del body: `{ correo: "usuario@empresa.cl" }` → `POST /security/password-reset/request`.

**Pantalla B — Confirmación de envío**

```
   ✅ Revisa tu correo

   Enviamos un enlace de recuperación a
   [correo@ingresado.cl]

   El enlace expira en 30 minutos.

   ¿No llegó? Reenviar (disponible en 60s)

   ← Volver al login
```

- Botón "Reenviar" con countdown de 60 segundos, habilitado solo al terminar.
- Siempre muestra respuesta positiva (no confirma si el email existe).

**Pantalla C — Nueva contraseña** *(accedida desde el enlace del email)*

```
   Nueva contraseña

   Nueva contraseña              [👁]
   ┌──────────────────────────┐
   │                          │  [medidor de fortaleza]
   └──────────────────────────┘

   Confirmar contraseña          [👁]
   ┌──────────────────────────┐
   │                          │
   └──────────────────────────┘

   ┌──────────────────────────┐
   │   Actualizar contraseña   │
   └──────────────────────────┘
```

- Mismas reglas de contraseña que en el registro (medidor de 4 niveles).
- Si el enlace está expirado o ya fue usado: muestra error `"Este enlace ya no es válido. Solicita uno nuevo."` con CTA directo a la Pantalla A.
- Al éxito: redirige al login con toast `"Contraseña actualizada. Puedes iniciar sesión."`.

> El enlace del email contiene `?token=...&uuid=...` (ambos requeridos). Validar primero con `GET /security/password-reset/validate?token=&uuid=` antes de mostrar el formulario. Al enviar: `POST /security/password-reset/reset` con body `{ token, uuid, newPassword, confirmPassword }`.

**Historias de usuario**

- `US-A01` — Como usuario, quiero iniciar sesión con mi nombre de usuario y contraseña, para acceder a la plataforma según mi rol.
- `US-A02` — Como usuario, quiero que si inicio sesión desde un segundo dispositivo simultáneamente, se cierre la sesión anterior, para mantener la seguridad de mi cuenta.
- `US-A03` — Como usuario, quiero recuperar el acceso a mi cuenta si olvidé mi contraseña, para no quedar bloqueado.

**Criterios de aceptación**

- [ ] Layout de 2 paneles en `md+`: panel izquierdo fijo con branding (2/5 ancho), panel derecho con formulario (3/5 ancho). En `xs–md`: solo panel derecho a pantalla completa.
- [ ] Formulario: campo nombre de usuario + campo contraseña con toggle de visibilidad `[👁]`.
- [ ] Botón "Iniciar sesión": muestra spinner mientras procesa. Se deshabilita durante la petición.
- [ ] Error de credenciales: mensaje inline genérico (no distingue si el usuario existe). No limpia el formulario.
- [ ] Al autenticar con sesión previa en otro dispositivo: cierra la sesión anterior, continúa el login, muestra toast informativo.
- [ ] Link `"¿Olvidaste tu contraseña?"` abre la Pantalla A del flujo de recuperación.
- [ ] **Pantalla A**: input de correo con validación de formato. Respuesta siempre positiva al enviar (no revela si el email existe).
- [ ] **Pantalla B**: muestra el correo ingresado (enmascarado si se desea). Botón "Reenviar" con countdown de 60s.
- [ ] **Pantalla C**: accedida desde el enlace del email. Medidor de fortaleza de contraseña. Validación de coincidencia de campos.
- [ ] Enlace de recuperación de un solo uso con expiración de 30 minutos. Si está expirado/usado: error con CTA a solicitar nuevo enlace.
- [ ] Al éxito de Pantalla C: redirect al login con toast de confirmación.
- [ ] Link `"¿No tienes cuenta? Regístrate →"` navega al flujo de registro.

**Componentes**

- `LoginPage` — Página contenedora con layout de 2 paneles
- `LoginBrandPanel` — Panel izquierdo de branding (logo, tagline, ilustración). Oculto en `xs–md`.
- `LoginForm` — Formulario de usuario + contraseña con toggle de visibilidad y error inline
- `ForgotPasswordLink` — Enlace que activa el flujo de recuperación
- `PasswordRecoveryRequestForm` — Pantalla A: input de correo + submit
- `PasswordRecoveryConfirmation` — Pantalla B: confirmación de envío + reenvío con countdown
- `ResetPasswordForm` — Pantalla C: nueva contraseña + confirmación con medidor de fortaleza (accedida desde enlace del email)

---

### 9.2 Perfil de Usuario

**Descripción**: Pantalla de visualización y edición de la información personal del usuario. Accesible desde el botón de perfil de la top-navbar y desde el bloque de usuario del sidebar.

#### Layout general

```
┌─────────────────────────────────────────────────────────────┐
│  [📷]  Banner (gradiente azul/gris — ancho completo)        │
│                                                             │
│  [avatar●]  Juan Pérez García          [+ Conectar] [✉ Mensaje] │
│             @sparra                                         │
└─────────────────────────────────────────────────────────────┘
┌──────────────────────┐  ┌──────────────────────────────────┐
│ Información General  │  │ Actividad Social-Financiera       │
│ ──────────────── [✏] │  │ ──────────────────────────────── │
│ ✉  carlos@email.com  │  │                                  │
│ 📍 Ñuñoa 456, Stgo   │  │   [icono doc]                    │
│ 📞 +56 9 7654 3210   │  │   No hay publicaciones recientes │
├──────────────────────┤  │   en el ecosistema.              │
│ Redes Sociales       │  │                                  │
│ [linkedin]           │  │                                  │
└──────────────────────┘  └──────────────────────────────────┘
```

#### Secciones del perfil

**Banner (cabecera superior)**
- Contenedor horizontal de ancho completo.
- Fondo: gradiente lineal o diseño abstracto en tonos azules y grises (default). Reemplazable por imagen custom.
- Botón de cámara (`📷`) en la esquina superior izquierda para cambiar el banner.
- **Botón de Cerrar sesión** (`↪ Salir`) en la esquina superior derecha del banner. **Solo visible en `xs–md` (mobile/tablet)**; oculto en `md+` (desktop, donde el logout se gestiona desde el sidebar).
  - Estilo: botón delineado con fondo semitransparente, icono de salida y texto `"Cerrar sesión"`.
  - Al pulsar: invalida la sesión en el backend, limpia el state global y redirige al login.
  - Área de toque ≥ 44×44px.

**Avatar / Foto de perfil**
- Imagen circular superpuesta en el borde inferior izquierdo del banner.
- Placeholder: silueta gris genérica cuando no hay foto cargada.
- Indicador de estado activo: punto verde en la esquina inferior derecha del avatar.
- Al hacer clic sobre el avatar → opción de reemplazar foto (upload).

**Bloque de identidad**
- Nombre completo en `H1` (negrita destacada).
- Badge/etiqueta azul con icono de usuario mostrando el username (ej. `@sparra`).
- Acciones alineadas a la derecha:
  - Botón `+ Conectar` (con icono de agregar persona).
  - Botón `Mensaje` (con icono de sobre, estilo outline/delineado).

> ⚠️ Las acciones "Conectar" y "Mensaje" aplican cuando el perfil es visto por **otro usuario**. Cuando el usuario ve su propio perfil, estos botones se reemplazan por un botón `Editar perfil`.

**Columna izquierda**

*Tarjeta: Información General*
- Encabezado con título e icono de lápiz (`✏`) alineado a la derecha para editar.
- Lista con separadores sutiles entre filas:
  - `✉` Email
  - `📍` Dirección (única, campo de texto libre)
  - `📞` Teléfono

*Tarjeta: Redes Sociales*
- Encabezado con título.
- Chips/botones redondeados por red social registrada (ej. `linkedin`).
- Acción para agregar/editar redes sociales.

> ⚠️ Las redes sociales disponibles para registrar están por definir.

**Columna derecha — Actividad Social-Financiera**
- Tarjeta grande que ocupa la mayor parte del espacio inferior derecho.
- Título en negrita: "Actividad Social-Financiera".
- Estado vacío (empty state): icono gris de documento con lápiz + texto `"No hay publicaciones recientes en el ecosistema."`.
- Contenido futuro: publicaciones, operaciones destacadas, actividad pública del usuario en la plataforma (pendiente de definir).

---

#### Visibilidad del perfil

El perfil de usuario es **público** — accesible sin necesidad de iniciar sesión, similar a un perfil de LinkedIn. Cada usuario tiene una URL única: `/u/{username}` (ej. `factor.cl/u/jperez`).

| Sección / campo | Sin sesión | Autenticado externo | El propio usuario |
|-----------------|:----------:|:-------------------:|:-----------------:|
| Nombre completo | ✅ | ✅ | ✅ |
| Username (`@handle`) | ✅ | ✅ | ✅ |
| Avatar / foto de perfil | ✅ | ✅ | ✅ |
| Organización(es) activa(s) y tipo | ✅ | ✅ | ✅ |
| Redes sociales (links externos) | ✅ | ✅ | ✅ |
| Actividad Social-Financiera | ❌ | ✅ | ✅ |
| Email, teléfono, dirección | ❌ | ❌ | ✅ |
| RUT personal | ❌ | ❌ | ✅ |

- Los datos de contacto personal (email, teléfono, dirección, RUT) son **siempre privados** — ningún usuario externo puede verlos, independientemente de su rol.
- La sección de Actividad Social-Financiera requiere sesión iniciada para respetar la privacidad de los datos operacionales.
- El propósito del perfil público es que clientes y ejecutivos puedan conocer a la contraparte antes o durante una negociación: quién es, a qué org pertenece, qué actividad pública tiene.

---

#### Datos del perfil

| Campo | Cantidad | Editable | Notas |
|-------|:--------:|:--------:|-------|
| Foto de perfil | 1 | ✅ | Circular, placeholder de silueta |
| Banner | 1 | ✅ | Default: gradiente azul/gris |
| Nombre | 1 | ✅ | |
| Apellido paterno | 1 | ✅ | |
| Apellido materno | 1 | ✅ | |
| Correo electrónico | 1 | ✅ | También usado para recuperación de contraseña |
| Teléfono | 1 | ✅ | |
| Dirección | 1 | ✅ | Campo de texto libre, domicilio personal |
| Redes sociales | N | ✅ | Chips por red. Tipos por definir |
| Contraseña | — | ✅ | Flujo separado: requiere contraseña actual |

**Historias de usuario**

- `US-A04` — Como usuario, quiero ver mi información de contacto organizada visualmente, para tener una vista clara de mi perfil en la plataforma.
- `US-A05` — Como usuario, quiero editar mi información general (email, teléfono, dirección) desde la tarjeta de información, para mantener mis datos actualizados.
- `US-A06` — Como usuario, quiero cambiar mi foto de perfil y banner, para personalizar mi presencia en la plataforma.
- `US-A07` — Como usuario, quiero cambiar mi contraseña desde el perfil, para mantener la seguridad de mi cuenta.
- `US-A08` — Como usuario, quiero agregar mis redes sociales al perfil, para que otros usuarios puedan contactarme por otros canales.

**Criterios de aceptación**

- [ ] Banner ocupa el ancho completo de la cabecera. Gradiente azul/gris por defecto. Botón de cámara en esquina superior izquierda activa el upload.
- [ ] Botón "Cerrar sesión" visible en la esquina superior derecha del banner **solo en `xs–md`**. No se renderiza en `md+`.
- [ ] Al pulsar "Cerrar sesión" en el banner (mobile): invalida token en backend, limpia state global y redirige al login.
- [ ] Avatar circular superpuesto al borde inferior izquierdo del banner. Indicador verde de estado activo. Clic sobre el avatar activa el upload de foto.
- [ ] Upload de foto y banner: validación de tipo imagen y peso máximo.
- [ ] Nombre completo visible en H1. Badge de username con icono de usuario.
- [ ] En el perfil propio: botón `Editar perfil` en lugar de `+ Conectar` / `Mensaje`.
- [ ] Tarjeta "Información General": filas con icono + valor para email, dirección y teléfono. Icono de lápiz abre modo edición.
- [ ] Tarjeta "Redes Sociales": chips por cada red registrada. Acción para agregar/editar.
- [ ] Panel "Actividad Social-Financiera": empty state con icono y texto descriptivo cuando no hay actividad.
- [ ] Cambio de contraseña requiere ingresar la contraseña actual como verificación.
- [ ] Cambios en nombre y foto actualizan el state global `currentUser` → sidebar y top-navbar reflejan el cambio en tiempo real.

**Componentes**

- `UserProfilePage` — Página principal de perfil
- `ProfileBannerUpload` — Área de banner con botón de cámara (izquierda) y botón de Cerrar sesión (derecha, solo `xs–md`)
- `ProfileAvatarUpload` — Avatar circular con indicador de estado y opción de reemplazar foto
- `ProfileIdentityBlock` — Bloque de nombre, username badge y botones de acción
- `ProfileInfoCard` — Tarjeta de Información General con filas de icono + valor y modo edición
- `ProfileSocialCard` — Tarjeta de Redes Sociales con chips editables
- `ProfileActivityPanel` — Panel de Actividad Social-Financiera con empty state
- `ChangePasswordForm` — Formulario de cambio de contraseña (contraseña actual + nueva + confirmación)

---

### 9.3 Organizaciones

#### Modelo de relación usuario–organización

| Rol | Relación con organización |
|-----|--------------------------|
| `cliente` (cedente) | Un usuario puede pertenecer a **múltiples organizaciones cedentes**. Una organización cedente puede tener **múltiples usuarios**. |
| `ejecutivo` | El primer ejecutivo crea la organización financiera (`FINANCIERA`) como paso separado post-registro. Actualmente asociado a **1 sola institución financiera**. |

#### Flujos de incorporación de miembros

Existen tres caminos formales para que un usuario se incorpore a una organización, más un mecanismo de código de acceso rápido complementario:

##### Flujo A — Solicitud de membresía (iniciada por el usuario)

1. El usuario encuentra la organización (desde el directorio público o su perfil) y hace clic en **"Solicitar unirse"**.
2. Se crea una solicitud en estado `PENDIENTE`.
3. Los admins de la org reciben una notificación.
4. El admin revisa la solicitud desde el **Gestor de Organización** (§9.5). Al tocar el nombre o avatar del solicitante puede ver su perfil público antes de decidir.
   - **Aprobada** → se crea el `OrganizationMember` en estado `ACTIVO`. El usuario recibe notificación.
   - **Rechazada** → el admin puede adjuntar un motivo (opcional). El usuario recibe notificación. La misma persona no puede volver a solicitar durante **30 días**.

##### Flujo B — Invitación por administrador

1. El admin va al **Gestor de Organización → Miembros → "Invitar"**.
2. Ingresa el correo del usuario a invitar.
3. El sistema envía un email con enlace de invitación (expira en **7 días**).
   - Si el correo **ya tiene cuenta**: al hacer clic en el enlace se muestra una pantalla de aceptación/rechazo.
   - Si el correo **no tiene cuenta**: el enlace redirige al registro; al completarlo el usuario queda como miembro activo de la org.
4. El admin puede reenviar o revocar la invitación desde el Gestor mientras esté pendiente.

##### Flujo C — Admin crea usuario directamente

1. El admin va al **Gestor de Organización → Miembros → "Crear usuario"**.
2. Ingresa: nombre, apellido y correo.
3. El sistema crea la cuenta y envía al correo un enlace para establecer contraseña (expira en **48 horas**).
4. Al activar la cuenta, el usuario queda automáticamente como miembro activo de la org.
5. El admin puede revocar el acceso antes de que el usuario active su cuenta.

##### Código de acceso rápido (mecanismo complementario)

La organización dispone de un **código único de 8 caracteres** (ej. `FACT-X7K2`) como mecanismo de incorporación autodeclarada. Cualquier usuario con el código puede unirse sin aprobación manual. Los admins pueden rotarlo en cualquier momento desde el Gestor; el código anterior queda inválido de inmediato.

> El código es útil para incorporaciones masivas en eventos controlados. Para incorporaciones individuales se recomienda usar los flujos A, B o C.

---

#### Roles de administrador dentro de la organización

| Rol en org | Descripción |
|------------|-------------|
| `miembro` | Acceso operativo según el tipo de org. Sin permisos de gestión. |
| `admin` | Puede gestionar miembros (aprobar solicitudes, invitar, crear, remover), grupos de trabajo y la configuración de la org. |

- El creador de la org recibe automáticamente el rol `admin` y tiene badge permanente `👑`.
- Los admins pueden **promover** a `admin` a cualquier miembro activo.
- Los admins pueden **degradar** a `miembro` a otro admin, siempre que la org conserve al menos **1 admin activo**.
- El creador `👑` **no puede ser removido** por otros admins.

#### Flujo de creación de organización — Cedente

Wizard de 4 pasos, guardado incremental (puede interrumpirse y retomarse):

**Paso 1 — Identidad legal**

| Campo | Origen | Validación |
|-------|--------|-----------|
| RUT empresa | Manual | Máscara + DV. Al completar → **lookup automático SII** (ver 9.3.1). |
| Razón social | Pre-rellenado desde SII (editable) | Requerido |

**Paso 2 — Dirección tributaria** *(requerida)*

Campos del registro de dirección:

| Campo | Tipo | Requerido |
|-------|------|-----------|
| `calle` | Texto | ✅ |
| `numero` | Texto | ✅ |
| `depto_oficina` | Texto | ❌ |
| `pais` | Select | ✅ |
| `region` | Select (depende de país) | ✅ |
| `provincia` | Select (depende de región) | ✅ |
| `ciudad` | Texto | ✅ |
| `comuna` | Select (depende de provincia) | ✅ |
| `codigo_postal` | Texto | ❌ |
| `referencia` | Texto libre | ❌ |
| `tipo_direccion` | Enum: `TRIBUTARIA`, `CASA_MATRIZ`, `SUCURSAL`, `BODEGA`, `ATENCION`, otros | ✅ |

> En el wizard de creación, el tipo se pre-selecciona como `TRIBUTARIA`. El CTA "Agregar otra dirección" permite registrar tipos adicionales después del wizard.

**Paso 3 — Cuenta bancaria** *(requerida para operar)*

| Campo | Notas |
|-------|-------|
| Banco | Select con logos de bancos |
| Tipo de cuenta | Corriente / Vista / Ahorro |
| Número de cuenta | Numérico |
| Titular + RUT titular | Puede ser distinto al RUT de la empresa |

> *"Para recibir los fondos al ceder tus facturas"* — el motivo se muestra como texto explicativo junto al paso.

**Paso 4 — Presentación** *(opcional, completar después)*

Logo (dropzone), descripción breve, banner. El paso tiene CTA de "Completar después" que no bloquea el acceso al dashboard.

#### Flujo de creación de organización — Ejecutivo (Financiera)

Wizard análogo al cedente, con diferencias en el paso 3:

- El paso 3 **no solicita cuenta bancaria para recibir pagos**; en su lugar solicita datos de contacto operativo de la financiera (teléfono, email operaciones).
- Los pasos 1, 2 y 4 son idénticos.

> ⚠️ El detalle completo del wizard para financieras queda pendiente de definición.

#### Zona gris — Ejecutivo multi-organización

> ⚠️ **Pendiente**: un ejecutivo podría en el futuro actuar como captor independiente para múltiples financieras. La relación 1-a-1 actual podría no escalar. Debe resolverse antes de diseñar ese escenario.

#### Rol fijo a nivel de cuenta (regla de negocio)

El modelo técnico permitiría que un usuario sea `cliente` en una org y `ejecutivo` en otra, pero **está prohibido por regla de negocio**: tendría acceso a información privada que no le corresponde. El rol es exclusivo y fijo desde el registro.

#### Modelo de datos de una organización

**`Organization`:**

| Grupo de datos | Campos / descripción |
|----------------|---------------------|
| **Identidad** | RUT empresa, razón social, `tipoParticipacion` (`CEDENTE` / `FINANCIERA` / `BROKER`) |
| **Estado de onboarding** | `ONBOARDING_INCOMPLETO` / `ACTIVA` / `PENDIENTE_VERIFICACION` |
| **Código de acceso rápido** | Código único de 8 caracteres. Rotable por cualquier admin. |
| **Creador** | `userId` del fundador. Badge `👑`. No puede ser removido por otros admins. |
| **Direcciones** | Múltiples registros con tipo: `TRIBUTARIA`, `CASA_MATRIZ`, `SUCURSAL`, `BODEGA`, `ATENCION`, otros |
| **Cuentas bancarias** | Múltiples registros: banco, tipo de cuenta, número de cuenta, titular, RUT titular |
| **Adjuntos** | Logo, banner, videos de presentación y otros documentos |
| **Grupos de trabajo** | Grupos internos con líder y miembros. CRUD en §9.5 Gestor. |

**`OrganizationMember`** — vínculo usuario–organización:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `userId` | `string` | Usuario vinculado |
| `organizationId` | `string` | Organización |
| `role` | `miembro` \| `admin` | Rol dentro de la org |
| `status` | `activo` \| `suspendido` | Estado de la membresía |
| `joinMethod` | `solicitud` \| `invitacion` \| `creacion_directa` \| `codigo` \| `fundador` | Cómo ingresó |
| `joinedAt` | `datetime` | Fecha de activación |
| `invitedBy` | `string?` | `userId` del admin que lo incorporó (Flujos B y C) |

**`OrganizationMemberRequest`** — Flujo A (solicitud del usuario):

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | `string` | UUID |
| `userId` | `string` | Quien solicita |
| `organizationId` | `string` | Org a la que se solicita unirse |
| `status` | `pendiente` \| `aprobada` \| `rechazada` | |
| `createdAt` | `datetime` | |
| `resolvedAt` | `datetime?` | |
| `resolvedBy` | `string?` | `userId` del admin que resolvió |
| `declineReason` | `string?` | Motivo opcional si fue rechazada |

**`OrganizationInvitation`** — Flujo B (invitación por admin):

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | `string` | UUID |
| `organizationId` | `string` | |
| `invitedBy` | `string` | `userId` del admin que invita |
| `email` | `string` | Correo del invitado |
| `status` | `pendiente` \| `aceptada` \| `rechazada` \| `expirada` | |
| `createdAt` | `datetime` | |
| `expiresAt` | `datetime` | 7 días desde `createdAt` |
| `acceptedAt` | `datetime?` | |

> `tipoParticipacion` disponibles: `CEDENTE`, `FINANCIERA`, `BROKER`. El tipo `BROKER` corresponde a intermediarios independientes que comparan tasas entre múltiples financieras y redirigen facturas de cedentes. Misma estructura técnica que las demás orgs; su comportamiento diferencial se especificará post-MVP.

---

#### 9.3.1 Integración SII — Lookup KYC al registrar organización

**Endpoint**:
```
POST https://www2.sii.cl/app/stc/recurso/v1/consulta/getConsultaData/
Content-Type: application/json

{
  "rut": "77908337",
  "dv": "3",
  "reAction": "consultaSTC",
  "reToken": " "
}
```

> El token `reToken` se envía como espacio en blanco. El endpoint no valida reCAPTCHA de forma estricta en la versión actual. Esto debe monitorearse ante cambios del SII.

**Campos de la respuesta útiles para Factor**:

| Campo | Tipo | Uso |
|-------|------|-----|
| `registrado` | `boolean` | Validar que el RUT existe antes de continuar |
| `nombre` | `string` | **Pre-rellenar razón social automáticamente** |
| `inicioActividades` | `boolean` | Requerir que la empresa tenga inicio de actividades |
| `fechaInicioActividades` | `string` | Mostrar como dato informativo |
| `tieneTimbraje` | `boolean` | Verificar que puede emitir documentos electrónicos |
| `timbrajes[].codigo === "0033"` | — | **Factura Electrónica** — requisito para operar como cedente |
| `cumpleObligacionTributaria` | `"SI"` / `"NO"` | Determinar si hay alertas tributarias que mostrar |
| `girosNegocio[].descripcion` | `string[]` | Mostrar rubros en el perfil de organización |

**UX del lookup en el wizard de org:**

```
┌────────────────────────────────────────────────────────┐
│  RUT empresa   [ 77.908.337 - 3 ]  ✅                 │
│                                                        │
│  Razón Social  [ SEIS SPA          ]  ← pre-rellenado  │
│                                        (editable)      │
│                                                        │
│  ✅ Contribuyente activo con Factura Electrónica       │
└────────────────────────────────────────────────────────┘
```

**Estados posibles del lookup:**

| Condición | Mensaje al usuario |
|-----------|-------------------|
| `registrado: false` | ❌ "RUT no encontrado en el SII. Verifica el número ingresado." |
| `inicioActividades: false` | ❌ "Este RUT no tiene inicio de actividades en el SII." |
| Sin timbraje `"0033"` | ⚠️ "Este RUT no tiene habilitada la emisión de Facturas Electrónicas. Debes tramitarlo en el SII antes de operar en Factor." |
| `cumpleObligacionTributaria: "NO"` | ⚠️ "Este RUT tiene observaciones tributarias en el SII. Puedes continuar, pero tu cuenta quedará sujeta a revisión." |
| Todo válido | ✅ "Contribuyente activo con Factura Electrónica." |

> El lookup se ejecuta **al completar el campo RUT** (blur + DV válido), no al enviar el formulario. El resultado es informativo; solo los casos ❌ bloquean el avance.

**Nota de implementación**: la llamada al endpoint del SII debe hacerse desde el **backend de Factor** (nunca desde el frontend directamente) para evitar exponer la URL en el cliente y permitir cacheo/rate-limiting.

---

### 9.4 Pantalla: Perfil de Organización

**Descripción**: Vista de perfil institucional de una organización. Combina datos legales, estructura operativa interna (grupos de trabajo y colaboradores) y presencia digital. Accesible desde el selector de organización de la top-navbar o desde la configuración.

#### Modelo de datos

| Entidad | Campos |
|---------|--------|
| `Organización` | `razonSocial`, `rut`, `tipoOrganizacion` (`CEDENTE` / `FINANCIERA`), `direccion`, `logoUrl`, `bannerUrl`, ecosistema digital (links) |
| `GrupoTrabajo` | `nombreGrupo`, `lider` (objeto `Colaborador`), `miembros` (array de `Colaborador`) |
| `Colaborador` | `nombre`, `cargo`, `avatarUrl` |

#### Layout general

```
┌─────────────────────────────────────────────────────────────┐
│  Banner corporativo (ancho completo)             [⚙ Editar] │
│  [logo]  Tecnologías Avanzadas S.A.                         │
│          [badge] Fintech                                    │
└─────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────┐
│  Descripción / Presentación de la empresa                   │
│  Texto libre. Ej: "Somos una empresa fintech especializada   │
│  en soluciones de financiamiento para pymes chilenas..."    │
└─────────────────────────────────────────────────────────────┘
┌──────────────────────┐  ┌──────────────────────────────────┐
│ Datos de la Empresa  │  │ Grupos de Trabajo y Colaboradores │
│ ──────────────────── │  │ ─────────────────────────────────│
│ 🪪  76.123.456-K     │  │  ▾ Equipo Desarrollo Core        │
│ 💼  Razón Social     │  │    [👑 Líder]  Juan Pérez         │
│ 📍  Av. Bello 2115   │  │    ────────────────────────────  │
├──────────────────────┤  │    [●] Ana  [●] Luis  [●] María  │
│ Ecosistema Digital   │  │                                  │
│ [linkedin] [web]     │  │  ▾ Mesa de Dinero                │
└──────────────────────┘  │    [👑 Líder]  Carlos Rojas      │
  1/3 ancho               │    ────────────────────────────  │
                          │    [●] Pedro  [●] Sofía          │
                          └──────────────────────────────────┘
                            2/3 ancho
┌─────────────────────────────────────────────────────────────┐
│  Publicaciones                                   ⬜ No MVP  │
│  ─────────────────────────────────────────────────────────  │
│   [icono doc]                                               │
│   No hay publicaciones aún.                                 │
└─────────────────────────────────────────────────────────────┘
```

#### Sección 1 — Banner Corporativo (cabecera)

- **Banner**: espacio para imagen institucional o colores corporativos. Reemplazable. Botón de cámara para cambiar (solo para admins de la org).
- **Logo de la organización**: avatar circular o cuadrado con bordes redondeados. Superpuesto al borde inferior izquierdo del banner.
- **Razón social** en H1.
- **Badge de tipo de organización** (ej. `Fintech`, `CEDENTE`, `FINANCIERA`) — estilo chip azul/gris.
- **Acciones (derecha)**: botón `Editar Perfil` / `Configuración de Organización` (visible solo para admins de la org).

#### Sección 1b — Descripción / Presentación de la empresa

- Bloque de texto libre debajo del banner, ancho completo.
- Texto de presentación institucional (misión, descripción del negocio, etc.).
- Editable por admins de la org (ícono de lápiz al hacer hover).
- Si no hay descripción cargada: empty state con texto `"Agrega una descripción para presentar tu organización."` y CTA de edición (solo admins).
- Sin límite de longitud visual, pero con un límite de caracteres por definir.

#### Sección 2 — Columna izquierda (1/3 ancho)

*Tarjeta: Datos de la Empresa*

| Ícono | Campo |
|-------|-------|
| 🪪 | RUT / identificación fiscal |
| 💼 | Razón social completa |
| 📍 | Dirección comercial (primera dirección registrada de tipo `TRIBUTARIA` o `CASA_MATRIZ`) |

*Tarjeta: Ecosistema Digital*
- Chips/enlaces a plataformas oficiales de la empresa: LinkedIn corporativo, sitio web, otros.
- Acción para agregar/editar links (solo admins).

#### Sección 3 — Columna derecha (2/3 ancho)

*Panel: Grupos de Trabajo y Colaboradores*

Lista de grupos de trabajo renderizada como acordeones o tarjetas anidadas expandibles:

**Por cada `GrupoTrabajo`:**

```
▾ [Nombre del Grupo]
  ┌──────────────────────────────────────────┐
  │  [avatar]  Juan Pérez  — Líder de Grupo  │  ← micro-tarjeta destacada con badge 👑
  │            Cargo del líder               │  ← usa SearchableCardSelect para asignar/cambiar líder
  └──────────────────────────────────────────┘
  ─────────────────────────────────────────────
  [●] Ana García   [●] Luis Mora   [●] María Sun   ← grid de avatares con nombre y cargo
```

- La sección del **Líder** tiene diseño diferenciado (fondo destacado, badge de corona o texto `"Líder de Grupo"`).
- El líder puede ser reasignado usando el componente `SearchableCardSelect` (ver sección 3.1), filtrando sobre los colaboradores de la organización.
- La sección de **miembros** muestra avatares en grid con nombre y cargo.
- Botón para agregar nuevo grupo / agregar miembros (solo admins).

**Historias de usuario**

- `US-A09` — Como administrador de organización, quiero ver los datos legales y estructura de mi empresa en una sola pantalla, para tener visibilidad completa del perfil institucional.
- `US-A10` — Como administrador, quiero gestionar los grupos de trabajo con sus líderes y miembros, para reflejar la estructura operativa real en la plataforma.
- `US-A11` — Como administrador, quiero reasignar el líder de un grupo de trabajo desde un selector buscable, para actualizar la jerarquía sin esfuerzo.
- `US-A12` — Como usuario, quiero ver a qué grupos pertenezco y quién es mi líder, para entender mi posición dentro de la organización.

**Criterios de aceptación**

- [ ] Banner de ancho completo con logo de org superpuesto. Botón de cámara para cambiar banner (solo admins).
- [ ] Razón social en H1. Badge de tipo de organización debajo.
- [ ] Acciones de editar/configurar visibles solo para admins de la org.
- [ ] Tarjeta "Datos de la Empresa": RUT, razón social, dirección comercial con íconos.
- [ ] Tarjeta "Ecosistema Digital": chips de links externos. Editables por admins.
- [ ] Panel de grupos de trabajo: lista de acordeones expandibles por grupo.
- [ ] Cada grupo muestra: micro-tarjeta de líder con badge 👑, grid de miembros con avatar, nombre y cargo.
- [ ] El líder puede reasignarse vía `SearchableCardSelect` filtrado sobre colaboradores de la org.
- [ ] Botones de agregar grupo / agregar miembro visibles solo para admins.
- [ ] Bloque de descripción visible debajo del banner a ancho completo. Editable por admins. Empty state con CTA si no hay texto.
- [ ] Panel de Publicaciones renderizado al final de la página con empty state. Marcado visualmente como `⬜ No MVP` — sin funcionalidad real en esta fase.

**Componentes**

- `OrganizationProfilePage` — Página principal del perfil de organización
- `OrganizationHeader` — Banner + logo + razón social + badge de tipo + acciones
- `OrganizationBannerUpload` — Área de banner con botón de cámara (admin)
- `OrganizationDataCard` — Tarjeta de datos legales (RUT, razón social, dirección)
- `OrganizationDigitalCard` — Tarjeta de ecosistema digital (chips de links)
- `WorkgroupsPanel` — Panel contenedor de grupos de trabajo (acordeones)
- `WorkgroupAccordion` — Acordeón individual de un grupo de trabajo
- `WorkgroupLeaderCard` — Micro-tarjeta del líder con badge y `SearchableCardSelect` para reasignar
- `WorkgroupMembersGrid` — Grid de avatares de miembros con nombre y cargo
- `OrganizationDescriptionBlock` — Bloque de texto de presentación institucional con modo edición (admin)
- `OrganizationPublicationsPanel` — Panel reservado para publicaciones futuras. Estado actual: empty state. ⬜ No MVP

---

### 9.5 Gestor de Organización

**Descripción**: Pantalla de administración interna de la organización. Accesible solo para usuarios con rol `admin` dentro de la org. Separada del perfil público (§9.4): el perfil es lo que ve cualquier visitante; el gestor es la vista de gestión y operación interna.

> Acceso: botón **"Gestionar organización"** visible solo para admins en el perfil de org (§9.4).

#### Estructura — Pestañas

```
┌──────────────────────────────────────────────────────────────┐
│  [← Volver al perfil]     Gestionar: Constructora ABC S.A.  │
└──────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────┐
│  [ Miembros ]   [ Grupos de trabajo ]   [ Configuración ]   │
└──────────────────────────────────────────────────────────────┘
│  [contenido de la pestaña activa]                           │
```

---

#### Pestaña 1 — Miembros

**Sub-sección: Miembros activos**

```
┌─────────────────────────────────────────────────────────────┐
│  Miembros activos (12)             [ Invitar ] [ Crear + ]  │
├───────────┬──────────────────┬──────────────────┬───────────┤
│  [avatar] │  Juan Pérez      │  admin  [👑]     │  [···]    │
│  [avatar] │  Ana García      │  miembro          │  [···]    │
│  [avatar] │  Luis Mora       │  miembro          │  [···]    │
└───────────┴──────────────────┴──────────────────┴───────────┘
```

- Lista: avatar, nombre completo, rol (`miembro` / `admin`), badge `👑` para el creador.
- Menú `[···]` por fila:
  - **Promover a admin** (si es `miembro`)
  - **Degradar a miembro** (si es `admin` y queda al menos 1 admin activo)
  - **Remover de la organización** → confirmación con motivo opcional
- El creador `👑` no puede ser removido ni degradado por otros admins.
- Al tocar el nombre o avatar de un miembro se abre su perfil público.

**Sub-sección: Solicitudes pendientes**

```
┌─────────────────────────────────────────────────────────────┐
│  Solicitudes pendientes (3)                                 │
├───────────┬────────────────────────┬────────────────────────┤
│  [avatar] │  Pedro López           │  [ Aprobar ]           │
│           │  Hace 2 horas          │  [ Rechazar ]          │
├───────────┼────────────────────────┼────────────────────────┤
│  [avatar] │  Sofía Chen            │  [ Aprobar ]           │
│           │  Hace 1 día            │  [ Rechazar ]          │
└───────────┴────────────────────────┴────────────────────────┘
```

- Al tocar nombre/avatar: abre perfil público del solicitante para evaluar antes de decidir.
- **Aprobar**: crea `OrganizationMember` activo. El usuario recibe notificación.
- **Rechazar**: campo de motivo opcional inline → confirmar. El usuario recibe notificación. Re-solicitud bloqueada 30 días.

**Sub-sección: Invitaciones enviadas**

```
┌─────────────────────────────────────────────────────────────┐
│  Invitaciones enviadas (2)                    [ Invitar + ] │
├─────────────────┬───────────────┬─────────────┬────────────┤
│  ana@empresa.cl │  Enviada ayer │  Expira en  │ [Reenviar] │
│                 │               │  6 días     │ [Revocar]  │
└─────────────────┴───────────────┴─────────────┴────────────┘
```

- **`[ Invitar + ]`**: campo inline para ingresar email + botón "Enviar invitación".
- **Reenviar**: reactiva la invitación con nueva fecha de expiración (7 días).
- **Revocar**: cancela la invitación. Si el usuario intenta usar el enlace después, ve un error con CTA para solicitar nueva invitación.

**Modal: Crear usuario directamente (Flujo C)**

Al hacer clic en `[ Crear + ]` se abre un modal:

```
┌────────────────────────────────────────────┐
│  Crear nuevo usuario                  [✕]  │
│  ─────────────────────────────────────     │
│  Nombre       [ __________________ ]       │
│  Apellido     [ __________________ ]       │
│  Correo       [ __________________ ]       │
│                                            │
│  El usuario recibirá un correo para        │
│  establecer su contraseña (expira 48h).    │
│                                            │
│  [ Cancelar ]        [ Crear usuario ]     │
└────────────────────────────────────────────┘
```

---

#### Pestaña 2 — Grupos de trabajo

```
┌─────────────────────────────────────────────────────────────┐
│  Grupos de trabajo (3)                  [ + Nuevo grupo ]   │
├─────────────────────────────────────────────────────────────┤
│  ▾ Equipo Desarrollo Core        [ Editar ]  [ Eliminar ]   │
│    Líder: Juan Pérez                                        │
│    Miembros: Ana García · Luis Mora · María Sun (3)         │
├─────────────────────────────────────────────────────────────┤
│  ▸ Mesa de Dinero                [ Editar ]  [ Eliminar ]   │
└─────────────────────────────────────────────────────────────┘
```

- Acordeones expandibles. Colapsado: nombre, líder y conteo de miembros.
- **`+ Nuevo grupo`** / **Editar**: abre modal con campos:
  - Nombre del grupo
  - Líder (SearchableCardSelect sobre miembros activos de la org)
  - Miembros (selección múltiple sobre miembros activos)
- **Eliminar**: confirmación inline. Si tiene miembros, se les notifica que el grupo fue disuelto.
- Un miembro puede pertenecer a múltiples grupos simultáneamente.
- El líder debe ser un miembro activo de la organización.

> La vista del perfil público de la org (§9.4) muestra estos grupos en modo lectura. La gestión (CRUD) vive aquí en §9.5.

---

#### Pestaña 3 — Configuración

**Tarjeta: Información de la organización**
- Editar: razón social, descripción, logo, banner, links del ecosistema digital.
- Cambios en razón social y logo se propagan al `OrganizationSelector` del top-navbar en tiempo real.

**Tarjeta: Acceso por código**
- Muestra el código actual de 8 caracteres (ej. `FACT-X7K2`).
- Botón "Rotar código" con confirmación inline. El código anterior queda inválido de inmediato.

**Tarjeta: Zona de riesgo** *(solo creador `👑`)*
- Botón **"Desactivar organización"**: acción irreversible. Requiere escribir el nombre exacto de la org para confirmar.
- Al desactivar: todos los miembros pierden acceso. Las operaciones en curso no se cancelan automáticamente.

---

#### Historias de usuario

- `US-G01` — Como admin, quiero ver y gestionar todos los miembros activos, para controlar quién opera en nombre de la organización.
- `US-G02` — Como admin, quiero ver el perfil público de un solicitante antes de aprobarlo, para tomar una decisión informada.
- `US-G03` — Como admin, quiero invitar a un usuario por email, para incorporarlo sin que tenga que buscar la organización.
- `US-G04` — Como admin, quiero crear directamente una cuenta para un colaborador, para que empiece a operar sin fricciones.
- `US-G05` — Como admin, quiero promover a otro miembro como admin, para delegar la gestión de la organización.
- `US-G06` — Como admin, quiero gestionar los grupos de trabajo (crear, editar, asignar líder y miembros), para reflejar la estructura operativa real del equipo.
- `US-G07` — Como admin, quiero rotar el código de acceso, para invalidar un código comprometido sin afectar las membresías existentes.

#### Criterios de aceptación

- [ ] Solo usuarios con rol `admin` en la org pueden acceder al Gestor. Usuarios con rol `miembro` no ven el botón de acceso.
- [ ] Pestaña Miembros con 3 sub-secciones: Activos, Solicitudes pendientes, Invitaciones enviadas.
- [ ] Al tocar nombre/avatar de un solicitante o miembro: abre su perfil público (nueva pestaña o drawer lateral).
- [ ] Aprobar solicitud → `OrganizationMember` creado, notificación al usuario.
- [ ] Rechazar solicitud → motivo opcional, notificación al usuario, bloqueo de re-solicitud 30 días.
- [ ] Invitar por email → enlace expira en 7 días. Si el email no tiene cuenta, redirige al registro pre-vinculado. Reenvío y revocación disponibles mientras esté pendiente.
- [ ] Crear usuario → modal con nombre + apellido + correo → enlace de activación (expira 48h) → al activar queda como miembro activo.
- [ ] Promover/degradar admin: no permitido si dejaría la org sin admins. El creador `👑` no puede ser degradado ni removido.
- [ ] Pestaña Grupos: acordeones con nombre, líder y miembros. CRUD completo vía modal. Un miembro puede pertenecer a múltiples grupos.
- [ ] Pestaña Configuración: edición de datos de org, rotación de código (con confirmación inline), desactivación de org (solo creador, requiere escribir el nombre).

#### Componentes

- `OrgManagerPage` — Página contenedora con sistema de pestañas
- `OrgMembersTab` — Pestaña de miembros (sub-secciones: activos, solicitudes, invitaciones)
- `ActiveMembersList` — Tabla de miembros activos con rol, badge creador y menú de acciones
- `MemberRequestsList` — Lista de solicitudes pendientes con aprobar/rechazar inline
- `InvitationsList` — Lista de invitaciones enviadas con reenviar/revocar
- `InviteMemberInline` — Campo inline de email para enviar invitación
- `CreateUserModal` — Modal para crear usuario directamente (Flujo C)
- `OrgWorkgroupsTab` — Pestaña de grupos con acordeones y CRUD
- `WorkgroupFormModal` — Modal de creación/edición de grupo (nombre, líder, miembros)
- `OrgSettingsTab` — Pestaña de configuración (datos org, código, zona de riesgo)

---

## 10. Notificaciones (In-App)

### 10.0 Dos superficies de notificación

La plataforma tiene dos paneles de notificación distintos con alcances diferentes:

| Panel | Componente | Scope | Trigger |
|-------|-----------|-------|---------|
| **Global** | `NotificationsSidebar` | Todas las notificaciones del usuario | Botón `🔔` en top-navbar |
| **Por factura** | `InvoiceNotificationSidebar` | Solo actividad de una factura específica | Botón "Notificaciones" en footer de `factura-view` |

Esta sección especifica el panel **global** (`NotificationsSidebar`). El panel por factura reutiliza el mismo feed filtrado por `relatedInvoiceId`.

---

### 10.1 Modelo de Datos

Cada notificación tiene la siguiente estructura:

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `id` | `string` | UUID de la notificación |
| `userId` | `string` | Destinatario |
| `category` | `enum` | `factura` \| `mensaje` \| `alerta` |
| `type` | `enum` | Ver catálogo §10.2 |
| `title` | `string` | Texto principal (negrita) |
| `body` | `string` | Texto secundario (descripción breve) |
| `read` | `boolean` | `false` al crear; `true` al marcar como leída |
| `createdAt` | `datetime` | Timestamp del evento |
| `relatedInvoiceId` | `string?` | Factura relacionada (si aplica) |
| `relatedOfferId` | `string?` | Oferta relacionada (si aplica) |
| `actionUrl` | `string` | Ruta de navegación al tocar la notificación |

---

### 10.2 Catálogo de Eventos

| Tipo (`type`) | Categoría | Destinatario | Título | Body |
|---------------|-----------|-------------|--------|------|
| `invoice.offer_received` | `factura` | Cliente | `"Nueva oferta recibida"` | `"[Ejecutivo] hizo una oferta sobre factura #[folio]"` |
| `invoice.offer_accepted` | `factura` | Ejecutivo | `"Oferta aceptada"` | `"Tu oferta sobre factura #[folio] fue aceptada"` |
| `invoice.offer_rejected` | `factura` | Ejecutivo | `"Oferta rechazada"` | `"Tu oferta sobre factura #[folio] fue rechazada"` |
| `invoice.published` | `factura` | Cliente | `"Factura publicada"` | `"Tu factura #[folio] ya es visible para ejecutivos"` |
| `invoice.rejected` | `factura` | Cliente | `"Factura rechazada"` | `"Tu factura #[folio] fue rechazada: [motivo]"` |
| `invoice.financed` | `factura` | Cliente | `"Operación financiada"` | `"La factura #[folio] fue financiada por [Ejecutivo]"` |
| `invoice.payment_notified` | `factura` | Cliente | `"Depósito notificado"` | `"[Ejecutivo] notificó el depósito de factura #[folio]. Verifica en tu banco."` |
| `invoice.paid` | `factura` | Ejecutivo | `"Pago confirmado"` | `"El cliente confirmó la recepción del depósito en factura #[folio]"` |
| `invoice.expiring_soon` | `alerta` | Cliente | `"Factura próxima a vencer"` | `"Tu factura #[folio] vence en [N] días y no tiene ofertas"` |
| `invoice.expired` | `alerta` | Cliente | `"Factura vencida"` | `"Tu factura #[folio] venció sin recibir financiamiento"` |
| `invoice.denounced` | `alerta` | Ambos | `"Operación denunciada"` | `"La factura #[folio] fue denunciada y está siendo revisada"` |
| `chat.new_message` | `mensaje` | Ambos | `"Nuevo mensaje"` | `"[Nombre] en negociación #[folio]"` |
| `chat.offer_context` | `mensaje` | Ambos | `"Actividad en negociación"` | Evento de sistema dentro del hilo (oferta aceptada/rechazada) |

> Los mensajes de chat no leídos suman al contador global `unreadNotificationsCount` **y** generan su propio badge en la tarjeta de oferta dentro del hilo.

---

### 10.3 `NotificationsSidebar` — Panel Global

#### Comportamiento responsivo

| Breakpoint | Comportamiento |
|------------|---------------|
| `md+` (desktop) | Panel deslizable desde la derecha (`position: fixed; right: 0; top: 0; height: 100vh`). Ancho fijo ~380px. Overlay oscuro semitransparente detrás. El resto de la app permanece visible. Se cierra con `[✕]`, clic fuera o `Escape`. |
| `xs–md` (mobile) | **Bottom sheet** que sube desde el borde inferior. Altura inicial ~65% del viewport, expandible a full screen arrastrando hacia arriba (drag handle visible). El chip de filtros queda sticky bajo el header. Footer de "Limpiar todas" fijo en la parte inferior. Se cierra deslizando hacia abajo o tocando el overlay. |

---

#### Anatomía del componente

```
┌─────────────────────────────────────────────┐
│  Notificaciones                        [✕]  │  ← Header
├─────────────────────────────────────────────┤
│  [Todas] [🗒 Facturas] [✉ Mensajes] [⚠ Alertas] │  ← Filtros (chips sticky)
├─────────────────────────────────────────────┤
│                                             │
│  ── Hoy ──────────────────────────────────  │  ← Separador temporal
│                                             │
│  🗒 Facturas                            3 ≡ │  ← Encabezado de categoría
│  ┌─────────────────────────────────────┐   │
│  │ [●] Nueva oferta recibida           │   │  ← Card no leída (punto color)
│  │     Carlos S. en factura #4521      │   │
│  │     Hoy, 10:32                      │   │
│  └─────────────────────────────────────┘   │
│  ┌─────────────────────────────────────┐   │
│  │     Factura publicada               │   │  ← Card leída (sin punto)
│  │     Tu factura #4488 es visible     │   │
│  │     Hoy, 09:15                      │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ✉ Mensajes                            1 ≡ │
│  ┌─────────────────────────────────────┐   │
│  │ [●] Nuevo mensaje                   │   │
│  │     Juan P. en negociación #4521    │   │
│  │     Hoy, 10:45                      │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ⚠ Alertas                                 │
│       Sin notificaciones                    │  ← Empty state de categoría
│                                             │
│  ── Ayer ─────────────────────────────────  │
│  ...                                        │
│                                             │
├─────────────────────────────────────────────┤
│       🗑 Limpiar todas                      │  ← Footer fijo
└─────────────────────────────────────────────┘
```

---

#### Secciones del componente

**A. Header**
- Título `"Notificaciones"` en negrita (H2/H3).
- Botón `[✕]` a la derecha para cerrar el panel.

**B. Filtros (chips sticky)**
- Chips: `Todas` · `🗒 Facturas` · `✉ Mensajes` · `⚠ Alertas`.
- Chip activo: fondo sólido (color acento), texto blanco.
- Chips inactivos: borde delineado, ícono + texto.
- Al filtrar, el feed muestra solo las notificaciones de esa categoría. Los separadores temporales y encabezados de categoría se ocultan cuando no hay ítems en ese rango.
- Los chips permanecen sticky bajo el header al hacer scroll.

**C. Feed de notificaciones**

*Separadores temporales* (entre grupos de días):
- `"Hoy"`, `"Ayer"`, `"Esta semana"`, `"Anteriores"`

*Encabezado de categoría* (dentro de cada grupo temporal):
- Ícono + título en negrita (`🗒 Facturas`, `✉ Mensajes`, `⚠ Alertas`).
- Contador de no leídas alineado a la derecha con ícono de tres líneas (≡) en gradiente rojo.
- El encabezado de categoría solo aparece en la vista `Todas`; en vista filtrada se omite.

*Card de notificación*:
- `[●]` punto de color (acento) a la izquierda si no está leída. Ausente si ya fue leída.
- **Título** en negrita (ej. `"Nueva oferta recibida"`).
- **Body** en texto secondary (ej. `"Carlos S. en factura #4521"`).
- **Timestamp** en texto small/muted (ej. `"Hoy, 10:32"`).
- Al tocar la card: marca como leída + navega según `actionUrl`.
- Swipe izquierda en mobile: acción rápida para marcar como leída / eliminar individualmente.

*Empty state de categoría*:
- Texto centrado en color muted: `"Sin notificaciones"`.
- Solo visible cuando esa categoría no tiene ítems en el rango temporal activo.

**D. Footer fijo**
- Botón de texto con ícono de papelera en `--color-error`: `"🗑 Limpiar todas"`.
- Al pulsar: confirmación inline (texto + botones Cancelar/Confirmar dentro del footer, sin modal) → elimina/archiva todas las notificaciones leídas. Las no leídas permanecen.

---

#### Comportamiento de lectura

| Acción | Resultado |
|--------|-----------|
| Abrir el panel | Las notificaciones visibles en pantalla se marcan como leídas automáticamente tras **2 segundos** de visibilidad (Intersection Observer). |
| Hacer scroll sobre una card | Se marca como leída al entrar en el viewport durante ≥ 2s. |
| Tocar una card | Marca como leída inmediatamente + navega. |
| Swipe izquierda (mobile) | Opción individual: "Leída" o "Eliminar". |
| Cerrar el panel | Las notificaciones que estuvieron visibles ya fueron marcadas; no hay acción adicional. |

El conteo `unreadNotificationsCount` del state global se decrementa en tiempo real conforme se marcan como leídas.

---

#### Navegación al tocar una notificación (`actionUrl`)

| Categoría / Tipo | Destino |
|-----------------|---------|
| `invoice.*` (cualquier evento de factura) | Navega a la factura correspondiente y expande el `factura-view` |
| `chat.new_message` | Navega directamente al chat de la oferta (`/ofertas/{offerId}/chat`) |
| `invoice.expiring_soon` / `invoice.expired` | Navega a la factura correspondiente |
| `invoice.denounced` | Navega a la factura correspondiente |

---

#### Badge del botón `🔔`

- Muestra `unreadNotificationsCount` del state global.
- Cap visual: `99+` si el conteo supera 99.
- El badge desaparece cuando el conteo llega a 0.
- Los mensajes de chat no leídos **suman** al contador global aunque también tengan su badge propio en la tarjeta de oferta.

---

### 10.4 Historias de usuario

- `US-N01` — Como usuario, quiero ver todas mis notificaciones en un panel centralizado, para no perder ningún evento relevante de mis operaciones.
- `US-N02` — Como usuario, quiero filtrar las notificaciones por categoría (Facturas, Mensajes, Alertas), para enfocarme en lo que me interesa en cada momento.
- `US-N03` — Como usuario, quiero que las notificaciones no leídas se marquen automáticamente al verlas, para que el badge sea siempre un reflejo real de lo que aún no he revisado.
- `US-N04` — Como usuario, quiero tocar una notificación y que me lleve directamente al contexto relevante, para no tener que navegar manualmente hasta la factura o el chat.
- `US-N05` — Como usuario, quiero limpiar todas las notificaciones leídas de una vez, para mantener el panel organizado.
- `US-N06` — Como usuario en mobile, quiero que el panel de notificaciones sea un bottom sheet expandible, para acceder cómodamente desde el teléfono.

### 10.5 Criterios de aceptación

- [ ] `NotificationsSidebar` en `md+`: panel lateral derecho de ancho ~380px con overlay. Se abre/cierra con `🔔`, `[✕]`, clic fuera o `Escape`.
- [ ] `NotificationsSidebar` en `xs–md`: bottom sheet con altura inicial ~65% viewport. Drag handle visible para expandir a full screen. Se cierra deslizando hacia abajo.
- [ ] Chips de filtro sticky bajo el header. Chip activo con fondo sólido; inactivos con borde delineado e ícono.
- [ ] Feed agrupado por separadores temporales: Hoy / Ayer / Esta semana / Anteriores.
- [ ] En vista `Todas`: encabezado de categoría por grupo con ícono, título y contador de no leídas.
- [ ] Card de notificación: punto `[●]` si no leída, título en negrita, body secondary, timestamp muted.
- [ ] Cards no leídas visibles ≥ 2s en viewport → se marcan como leídas automáticamente (Intersection Observer). `unreadNotificationsCount` se decrementa en tiempo real.
- [ ] Tocar una card: marca como leída + navega a `actionUrl`.
- [ ] Swipe izquierda en mobile: acciones rápidas "Leída" / "Eliminar".
- [ ] Empty state por categoría: `"Sin notificaciones"` centrado en color muted.
- [ ] Footer fijo: `"🗑 Limpiar todas"` con confirmación inline (no modal). Elimina solo las leídas; las no leídas permanecen.
- [ ] Badge `🔔` refleja `unreadNotificationsCount`. Cap: `99+`. Desaparece en 0.
- [ ] Mensajes de chat no leídos suman al contador global.
- [ ] Notificaciones llegan en tiempo real vía WebSocket sin recargar el panel.

### 10.6 Componentes

- `NotificationsSidebar` — Panel contenedor. Lateral fijo en `md+`; bottom sheet en `xs–md`.
- `NotificationsHeader` — Título + botón de cierre.
- `NotificationsFilterBar` — Chips de categoría sticky: Todas / Facturas / Mensajes / Alertas.
- `NotificationsFeed` — Lista scrollable con separadores temporales y encabezados de categoría.
- `NotificationCard` — Card individual: punto de no leída, título, body, timestamp. Navegación al tocar.
- `NotificationCategoryHeader` — Encabezado de sección: ícono + título + contador.
- `NotificationsEmptyState` — Estado vacío por categoría.
- `NotificationsFooter` — Footer fijo con botón "Limpiar todas" y confirmación inline.
- `NotificationsButton` — Botón `🔔` de la top-navbar con badge de conteo (ya en §3 shell).

---

## 11. Preguntas Abiertas

| # | Pregunta | Prioridad | Área |
|---|----------|-----------|------|
| 1 | ~~¿Cuáles son los criterios completos de rechazo automático?~~ **✅ Resuelto** — Dos criterios confirmados: (a) **duplicado**: la factura ya existe en el sistema (mismo folio + RUT emisor); (b) **RUT no coincide**: el RUT del cedente o del cliente registrado en la plataforma no coincide con ningún RUT detectado por el OCR en el PDF subido. Criterios adicionales pendientes de definición. | — | — |
| 2 | ~~¿El ejecutivo tiene límites configurables de monto máximo por oferta?~~ **✅ Resuelto** — **No existe un límite configurable fijo**. El porcentaje de anticipo que ofrece el ejecutivo es una **decisión de negociación contextual**: el ejecutivo puede financiar hasta el 100% del valor de la factura o menos, según su evaluación del riesgo del deudor y del contexto de la operación. Ofrecer un anticipo menor es una herramienta de cobertura para la financiadora ante un eventual impago o imprevisto del deudor. El slider de anticipo en la calculadora es el mecanismo que refleja esta decisión. | — | — |
| 3 | ~~¿Cuál es el rango de tasa válido regulatoriamente?~~ **✅ Resuelto** — La tasa válida se obtiene de la API del Banco Central. El dato es proporcionado por el backend y manejado como configuración global en el frontend (cargado al iniciar sesión). El backend es la fuente de verdad; el frontend valida contra esos valores. | — | — |
| 4 | ~~¿Qué campos concretos muestra la pantalla de aceptación de T&C? ¿Es un checkbox o una firma digital?~~ **✅ Resuelto** — Modal `TermsAndConditionsModal` con contenido dinámico desde backend, botones "Revisar publicación" / "Aceptar términos". Ver sección 6.1.1. | — | — |
| 5 | ~~¿El ejecutivo puede pertenecer a más de una organización financiera o es 1-a-1?~~ **✅ Resuelto** — 1-a-1 en MVP. El ejecutivo crea la financiera post-registro como paso separado. El escenario multi-financiera queda como pendiente futuro. | — | — |
| 6 | ~~¿La integración SII entra en el MVP extendido o queda para una fase posterior?~~ **✅ Resuelto** — Integra en el onboarding de organización (lookup KYC por RUT). Endpoint documentado en sección 9.3.1. | — | — |
| 7 | ~~¿Qué KPIs concretos van en el dashboard del cliente y del ejecutivo?~~ **✅ Resuelto** — Ver sección 8.1 (cedente: facturas activas por estado, capital por recibir, capital recibido, costo promedio, tiempo promedio, facturas en riesgo) y sección 8.3 (ejecutivo: capital desplegado/disponible, retorno proyectado/realizado, tasa promedio, ofertas activas, operaciones cerradas, ticket promedio). Ambos con selector de período y variación vs período anterior. | — | — |
| 8 | ~~¿Qué evento concreto dispara `PAGADA`?~~ **✅ Resuelto** — Flujo de doble confirmación: ejecutivo/financiadora registra el depósito → factura pasa a `PENDIENTE_VERIFICACION_PAGO` (notifica al cliente) → cliente verifica en su banco y confirma → `PAGADA`. Ver sección 5. | — | — |
| 9 | ~~¿Cuáles son los criterios para `VENCIDA`, `CANCELADA` y `DENUNCIADA`?~~ **✅ Resuelto** — `VENCIDA`: sistema automático al superar `fechaVencimiento` sin financiar. `CANCELADA`: cliente retira voluntariamente (hasta `OFERTADA`, no desde `FINANCIADA`). `DENUNCIADA`: ejecutivo o admin reporta irregularidad grave, congela desde cualquier estado, solo admin resuelve. `RECHAZADA`: criterio parcial (OCR con discrepancias totales), pendiente revisión. Ver sección 5. | — | — |
| 10 | ~~¿Qué campos completos requiere el registro de una dirección?~~ **✅ Resuelto** — `calle`, `numero`, `depto_oficina`(opt), `pais`, `region`, `provincia`, `ciudad`, `comuna`, `codigo_postal`(opt), `referencia`(opt), `tipo_direccion`. Ver sección 9.3. | — | — |
| 11 | ~~¿El wizard de financieras tiene los mismos pasos que cedentes?~~ **✅ Resuelto** — Wizard idéntico. El campo `tipoParticipacion` se establece automáticamente como `FINANCIERA` según el rol del usuario. No hay pasos ni campos distintos. | — | — |

---

## 12. Diseño Responsivo

La aplicación debe adaptarse a distintos tamaños de pantalla. Se trabaja con los siguientes breakpoints de referencia:

| Breakpoint | Rango | Dispositivo típico |
|------------|-------|--------------------|
| `xs` | < 480px | Teléfono móvil |
| `sm` | 480px – 768px | Teléfono grande / phablet |
| `md` | 768px – 1024px | Tablet |
| `lg` | 1024px – 1280px | Laptop |
| `xl` | > 1280px | Desktop / pantalla grande |

### Comportamientos adaptativos por componente

| Componente | Pantalla grande (`lg+`) | Pantalla pequeña (`xs–md`) |
|------------|------------------------|---------------------------|
| `factura-view` expandido + foto activa | Layout 2 columnas (foto izquierda / formulario derecha) | Layout 1 columna (foto arriba, formulario abajo o en tab separado) |
| `InvoiceNotificationSidebar` | Panel lateral fijo sobre el contenido (overlay parcial) | Drawer de pantalla completa desde abajo (bottom sheet) |
| `InvoiceUploadModal` | Modal centrado de ancho fijo | Pantalla completa (fullscreen modal) |
| `OfferCompareModal` | Grid de hasta 3 columnas comparativas | Scroll horizontal o comparación de a 2 |
| `MarketplaceTable` / `InvoiceList` | Tabla con todas las columnas visibles | Tarjetas apiladas (card view) con columnas priorizadas |
| `InvoiceFormStepper` | Stepper horizontal | Stepper vertical |
| Navbar lateral (shell) | Visible expandida o colapsada (icono) | Oculta; accesible mediante hamburger menu o bottom nav |
| `top-navbar` | Barra superior completa | Simplificada: solo logo, notificaciones y avatar |

### Principios generales

- **Mobile-first**: los componentes se diseñan primero para pantalla pequeña y se expanden progresivamente.
- **Touch targets**: los botones y elementos interactivos deben tener un área mínima de 44×44px en móvil.
- **Tablas → tarjetas**: cualquier tabla con más de 3 columnas debe colapsar a vista de tarjetas en `xs–sm`.
- **Sidebars → bottom sheets**: los paneles laterales se convierten en drawers desde abajo en móvil para mayor ergonomía.
- **Formularios**: en pantalla pequeña, los campos se apilan en una sola columna. Los datepickers usan el nativo del sistema operativo en móvil.
- **Modales**: en `xs–sm` los modales ocupan pantalla completa.

> ⚠️ Los comportamientos adaptativos específicos de cada componente se detallan en su sección correspondiente. Esta tabla es de referencia general; puede haber excepciones justificadas.

---

## 13. Lineamientos Técnicos

### 13.1 Ecosistema y Versiones

| Dependencia | Versión objetivo | Notas |
|-------------|:----------------:|-------|
| Angular CLI / Core / Common | `^19.0.0` | Versión mayor estable al inicio del proyecto |
| `@angular-architects/module-federation` | `^19.0.0` | Debe coincidir con la versión mayor de Angular |
| TypeScript | `~5.5.0` | Compatible con Angular 19 |
| Webpack | `^5.90.0` | Subyacente a `@angular-architects/module-federation` |
| RxJS | `^7.8.0` | Versión ultra-estable; declarada como `singleton` en Module Federation |
| Node.js | `>=20.x LTS` | Requerido por Angular 19 |

> Las versiones se fijan en el momento de scaffolding. Actualizaciones mayores requieren validación de compatibilidad entre todas las apps del monorepo antes de aplicarse.

---

### 13.2 Arquitectura de Aplicaciones Frontend

El frontend está dividido en **dos repositorios/proyectos Angular**:

| Repo | Contenedor | Puerto | Propósito |
|------|-----------|:------:|----------|
| `app-login-erp-seis/` | `app_login` | 8082 | Login, recuperación de contraseña, inicio del flujo PKCE |
| `seis-app-frontend/` (monorepo Nx) | `app_portal` + 4 MFEs | 8083–8087 | Portal principal + microfrontends |

```
 :8082               :8083
 app-login    PKCE   shell (seis-portal)
 ┌──────────┐  ───►  ┌──────────────────────────────────────┐
 │  Login   │        │  federation.manifest.json            │
 │  Recovery│        │  ├── mfe-gestion-usuario   :8084     │
 └──────────┘        │  ├── mfe-dashboard-facturas :8085    │
                     │  ├── mfe-publicador-facturas :8086   │
                     │  ├── mfe-ofertador-facturas :8087    │
                     │  └── /auth/callback (PKCE step 2)   │
                     └──────────────────────────────────────┘
                                    │
                           Kong :8000
                    /api/auth  →  ms-auth  :3000
                    /api/core  →  bff      :3002
```

#### Monorepo del Portal (`seis-app-frontend/`) — Angular Multi-Project Workspace

```
seis-app-frontend/
├── projects/
│   ├── seis-portal/               # Host app (Shell)
│   ├── seis-mfe-gestion-usuario/  # Remote: perfil, org, gestor
│   ├── seis-mfe-dashboard-facturas/
│   ├── seis-mfe-publicador-facturas/
│   ├── seis-mfe-ofertador-facturas/
│   └── shared-utils/              # Librería transversal (ver §13.5)
├── dockerfile.portal
├── dockerfile.mfe-gestion-usuario
├── dockerfile.mfe-dashboard-facturas
├── dockerfile.mfe-publicador-facturas
├── dockerfile.mfe-ofertador-facturas
├── nginx.conf                     # Portal
├── nginx.mfe-*.conf               # Uno por MFE
└── angular.json                   # Workspace multi-project
```

El build de cada app comienza compilando `shared-utils` primero: `npm run build -- shared-utils && npx ng build <project> --configuration development`.

`app-login` es un proyecto Angular standalone **separado**. No usa Module Federation ni `shared-utils`.

---

### 13.3 Configuración de Module Federation — Manifest-based

Se utiliza **`@angular-architects/module-federation` en modo manifest** (no URLs hardcodeadas en webpack). El Shell carga un `federation.manifest.json` en runtime, lo que permite cambiar las URLs de los remotos sin recompilar el Shell.

#### Flujo de resolución

```
Shell bootstrap
  └─► fetch(federation.manifest.json)          ← resuelve URLs en runtime
        └─► loadManifest()  →  initFederation()
              └─► loadRemoteModule({ manifestName: 'mfePublicadorFacturas', ... })
```

#### `federation.manifest.json` (Portal — copiado al bundle en build)

```json
{
  "mfeGestionUsuario":    "http://localhost:8084/remoteEntry.json",
  "mfeDashboardFacturas": "http://localhost:8085/remoteEntry.json",
  "mfePublicadorFacturas":"http://localhost:8086/remoteEntry.json",
  "mfeOfertadorFacturas": "http://localhost:8087/remoteEntry.json"
}
```

> En el Dockerfile del portal se copia `federation.manifest.prod.json` → `federation.manifest.json` antes de pasar al stage Nginx, sobreescribiendo las URLs de desarrollo.

#### Shell (`webpack.config.js`)

```js
// projects/seis-portal/webpack.config.js
const { shareAll, withModuleFederationPlugin } = require('@angular-architects/module-federation/webpack');

module.exports = withModuleFederationPlugin({
  // Sin `remotes` hardcodeados — se resuelven desde federation.manifest.json
  shared: {
    ...shareAll({
      singleton: true,
      strictVersion: true,
      requiredVersion: 'auto',
    }),
  },
});
```

#### MFE remoto — ejemplo `seis-mfe-publicador-facturas` (`webpack.config.js`)

```js
// projects/seis-mfe-publicador-facturas/webpack.config.js
const { shareAll, withModuleFederationPlugin } = require('@angular-architects/module-federation/webpack');

module.exports = withModuleFederationPlugin({
  name: 'mfePublicadorFacturas',
  filename: 'remoteEntry.json',   // ← JSON, no .js
  exposes: {
    './PublicadorRoutes': './src/app/publicador.routes.ts',
  },
  shared: {
    ...shareAll({
      singleton: true,
      strictVersion: true,
      requiredVersion: 'auto',
    }),
  },
});
```

#### Nginx — caché del `remoteEntry.json`

Cada MFE tiene su propio `nginx.mfe-*.conf` que sirve:
- `remoteEntry.json` con `Cache-Control: no-store` — siempre fresco para el Shell.
- Activos estáticos (`.js`, `.css`, etc.) con `Cache-Control: public, immutable, 1y` — agresivamente cacheados por hash de contenido.

> Cada MFE expone sus **rutas** (no un componente directamente), lo que permite lazy loading de módulos completos desde el Shell.

---

### 13.4 Enrutamiento Global — Shell (`app.routes.ts`)

Con el modo manifest, `loadRemoteModule` recibe `{ manifestName, exposedModule }` — sin URL hardcodeada.

```ts
// projects/seis-portal/src/app/app.routes.ts
import { Routes } from '@angular/router';
import { loadRemoteModule } from '@angular-architects/module-federation';

export const APP_ROUTES: Routes = [
  {
    path: '',
    redirectTo: 'dashboard',
    pathMatch: 'full',
  },
  {
    path: 'usuario',
    loadChildren: () =>
      loadRemoteModule({
        type: 'manifest',
        remoteName: 'mfeGestionUsuario',
        exposedModule: './GestionUsuarioRoutes',
      }).then((m) => m.GESTION_USUARIO_ROUTES),
  },
  {
    path: 'publicador',
    loadChildren: () =>
      loadRemoteModule({
        type: 'manifest',
        remoteName: 'mfePublicadorFacturas',
        exposedModule: './PublicadorRoutes',
      }).then((m) => m.PUBLICADOR_ROUTES),
  },
  {
    path: 'ofertador',
    loadChildren: () =>
      loadRemoteModule({
        type: 'manifest',
        remoteName: 'mfeOfertadorFacturas',
        exposedModule: './OfertadorRoutes',
      }).then((m) => m.OFERTADOR_ROUTES),
  },
  {
    path: 'dashboard',
    loadChildren: () =>
      loadRemoteModule({
        type: 'manifest',
        remoteName: 'mfeDashboardFacturas',
        exposedModule: './DashboardRoutes',
      }).then((m) => m.DASHBOARD_ROUTES),
  },
];
```

---

### 13.5 Principios de Arquitectura Angular

| Principio | Regla |
|-----------|-------|
| **Standalone Components** | Prohibido usar `NgModule` tradicionales. Toda la app usa standalone components (`standalone: true`). |
| **Lazy Loading** | Cada MFE se carga bajo demanda vía `loadRemoteModule` (modo manifest). Nunca se importa directamente en el Shell. |
| **Dependencias compartidas** | Angular Core, Common, Router, RxJS y FormsModule declarados como `singleton: true` en todos los `webpack.config.js` para evitar descarga duplicada. |
| **State global (`shared-utils`)** | Ver §13.5.1. Librería transversal del monorepo que centraliza el estado de sesión, servicios HTTP base y modelos compartidos. |
| **Comunicación entre MFEs** | Únicamente a través de los servicios de `shared-utils` (singleton vía MF shared scope). Prohibido el acoplamiento directo entre MFEs remotos. |
| **TypeScript estricto** | `strict: true` en todos los `tsconfig.json`. Sin `any` implícito. |
| **Señales (Signals)** | Preferir Angular Signals sobre BehaviorSubject para estado local de componentes. RxJS se reserva para flujos asíncronos (WebSocket, HTTP). |
| **Build en `development`** | Todos los proyectos del monorepo (`seis-portal`, `seis-mfe-*`) se compilan con `--configuration development` en los Dockerfiles para habilitar source maps y logs. |
| **Base-href dinámico** | Cada app se construye con `--base-href=/<project-name>/`. En runtime, el Shell resuelve la URL base del despliegue automáticamente para localizar los `remoteEntry.json` sin hardcodear hostnames. |

#### 13.5.1 Librería `shared-utils` — State transversal

`shared-utils` es la librería Angular del monorepo que se compila primero en cada build (`npm run build -- shared-utils`). Es declarada como **singleton** en el shared scope de Module Federation, por lo que todos los MFEs consumen la misma instancia en memoria.

| Responsabilidad | Descripción |
|-----------------|-------------|
| **Session state** | `SessionService` — expone usuario autenticado, organización activa, roles. Señales reactivas (`Signal<User>`, `Signal<Org>`). |
| **HTTP base** | Interceptores HTTP: adjunta cookies de sesión, maneja renovación silenciosa de `auth.refresh`, centraliza errores 401/403. |
| **Modelos compartidos** | Interfaces TypeScript (`User`, `Organization`, `Factura`, etc.) usadas por Shell y todos los MFEs. |
| **Componentes UI comunes** | Componentes standalone reutilizables: `SearchableCardSelect`, loaders, modales base. |

> **Nota de seguridad / refinamiento pendiente**: el patrón de state global compartido via MF singleton es válido y ampliamente usado, pero expone el estado de sesión a cualquier MFE cargado. En una siguiente iteración se puede refinar usando **scope isolation** (cada MFE declara qué slice del state necesita) o **tokens de acceso explícitos** para limitar qué MFEs pueden leer datos sensibles de la sesión.

---

### 13.6 Puertos de desarrollo

| App | Contenedor | Puerto host | Ruta base en Kong |
|-----|-----------|:-----------:|-------------------|
| Kong API Gateway | (—) | **8000** | — punto de entrada único |
| `app-login` | `app_login` | 8082 | — |
| `shell` (portal) | `app_portal` | 8083 | — |
| `mfe-gestion-usuario` | `app_mfe_gestion_usuario` | 8084 | — |
| `mfe-dashboard-facturas` | `app_mfe_dashboard_facturas` | 8085 | — |
| `mfe-publicador-facturas` | `app_mfe_publicador_facturas` | 8086 | — |
| `mfe-ofertador-facturas` | `app_mfe_ofertador_facturas` | 8087 | — |
| `ms-auth` | `ms_auth` | 3000 | `/api/auth` |
| `bff_seis_app` | `bff_seis_app` | 3002 | `/api/core` |

> En desarrollo, `app-login` y `app-portal` reciben `API_BASE_URL=http://localhost:8000` vía variable de entorno Docker. Los MFEs obtienen la base URL en runtime desde el despliegue (`window.location`) sin variables de entorno propias. Las URLs finales: `http://localhost:8000/api/auth/...` y `http://localhost:8000/api/core/...`.

---

### 13.7 `package.json` — Dependencias clave (bloque de referencia)

```json
{
  "dependencies": {
    "@angular/core":                       "^19.0.0",
    "@angular/common":                     "^19.0.0",
    "@angular/router":                     "^19.0.0",
    "@angular/forms":                      "^19.0.0",
    "@angular/platform-browser":           "^19.0.0",
    "@angular/platform-browser-dynamic":   "^19.0.0",
    "@angular-architects/module-federation":"^19.0.0",
    "rxjs":                                "^7.8.0",
    "zone.js":                             "~0.15.0"
  },
  "devDependencies": {
    "@angular/cli":          "^19.0.0",
    "@angular-devkit/build-angular": "^19.0.0",
    "typescript":            "~5.5.0",
    "webpack":               "^5.90.0"
  }
}
```

> Este bloque debe replicarse en cada app del monorepo. Las versiones de dependencias compartidas **deben ser idénticas en todos los `package.json`** para que Module Federation resuelva correctamente los singletons.

---

### 13.8 Servicios Backend — Contratos de API

Los servicios backend existentes son los siguientes. El frontend interactúa exclusivamente con el BFF; ms-auth solo recibe llamadas directas para el flujo de autenticación PKCE.

| Servicio | Puerto | Propósito |
|----------|:------:|-----------|
| `ms-auth` | `3000` | Autenticación PKCE, sesiones Redis, recuperación de contraseña |
| `bff_seis_app` | `3002` | Fachada de negocio: facturas, perfil, menú, objetos, T&C |

> Ver documentos completos: [MS-AUTH-API-REFERENCE.md](../MS-AUTH-API-REFERENCE.md) y [BFF-API-REFERENCE.md](../BFF-API-REFERENCE.md).

#### Mapeo feature → endpoint

| Feature del producto | Servicio | Método | Ruta |
|----------------------|----------|:------:|------|
| **Login (paso 1 PKCE)** | ms-auth | `POST` | `/security/authenticate` |
| **Login (paso 2 PKCE)** | ms-auth | `POST` | `/security/callback` |
| **Renovar sesión** | ms-auth | `POST` | `/security/session/refresh` |
| **Logout** | ms-auth | `GET` | `/security/logout` |
| **Solicitar recovery de contraseña** | ms-auth | `POST` | `/security/password-reset/request` |
| **Validar token de recovery** | ms-auth | `GET` | `/security/password-reset/validate?token=&uuid=` |
| **Ejecutar cambio de contraseña** | ms-auth | `POST` | `/security/password-reset/reset` |
| **Menú de navegación del portal** | BFF | `GET` | `/portal/menu` |
| **Perfil del usuario (lectura)** | BFF | `GET` | `/usuario/profile` |
| **Perfil del usuario (edición)** | BFF | `PUT` | `/usuario/profile` |
| **Avatar y banner del usuario** | BFF | `GET` | `/usuario/profile/img` |
| **Organizaciones del usuario** | BFF | `GET` | `/usuario/profile/organizacion` |
| **Listado de facturas de una org** | BFF | `GET` | `/facturas/list/:organizacionUUID` |
| **Publicar factura** | BFF | `POST` | `/facturas` |
| **Editar campo de factura** | BFF | `PATCH` | `/facturas` |
| **Registrar aceptación de T&C** | BFF | `POST` | `/facturas/autorizacion` |
| **Obtener versión activa de T&C** | BFF | `GET` | `/terminos/activo` |
| **Obtener presigned URL (MinIO)** | BFF | `GET` | `/object/presigned-url/:objectType` |
| **Subir archivo (multipart)** | BFF | `POST` | `/object/:objectType` |
| **Subir archivo (raw binary)** | BFF | `PUT` | `/object/:objectType` |

#### Tipos de objeto para subida de archivos (`objectType`)

El enum `CATEGORY_PROCESS` del BFF define los tipos válidos. Los confirmados para facturas:

| `objectType` | Uso | Params requeridos en query |
|---|---|---|
| `DOCUMENT_DTE` | Archivo XML/PDF de la factura electrónica (DTE) | `fileName`, `fileType`, `userName`, `organization` |
| `DOCUMENT_DTE_RESPALDO` | Documento respaldo de una factura | `fileName`, `fileType`, `userName`, `organization`, `idFactura` |

#### Envolvente de respuesta (`ApiResponse<T>`)

Todos los endpoints del BFF retornan esta estructura (salvo `/health` y `/liveness`):

```json
{
  "status": 200,
  "message": "Descripción del resultado",
  "data": { }
}
```

El interceptor HTTP de Angular debe leer `data` para obtener el payload. Los errores (`4xx`, `5xx`) siguen la misma envolvente — el interceptor puede leerlos por `status` para mostrar mensajes de error estándar.

#### Header de trazabilidad

El BFF propaga `X-Correlation-Id` (o `correlationId` en body donde aplique). Incluirlo en todas las requests mutantes permite correlacionar logs entre ms-auth y BFF en caso de incidencias.

---

## 14. Seguridad

> Factor opera en el dominio financiero y está sujeto a la supervisión de la **CMF (Comisión para el Mercado Financiero)**. La seguridad no es una capa adicional — es un requerimiento estructural desde el inicio.

---

### 14.1 Autenticación y Gestión de Sesión

#### Flujo de autenticación — PKCE cross-app

El flujo PKCE se distribuye entre `app-login` (genera el challenge y captura credenciales) y el Shell del Portal (ejecuta el callback que establece la sesión).

**Mecanismo de traspaso del `code_verifier`**: ms-auth lo almacena **server-side** vinculado al `sessionId` generado por `app-login`. El Portal no necesita recibirlo — ms-auth lo recupera internamente al llamar al callback. Esto requiere que ms-auth utilice el campo `sessionId` opcional del endpoint `/security/authenticate` para persistir el verifier en Redis.

> **Cambio de backend requerido**: el endpoint `POST /security/callback` actualmente exige `codeVerifier` en el body. Con el enfoque server-side, este campo debe volverse opcional: si `codeVerifier` está ausente, ms-auth lo recupera desde Redis usando `sessionId`. Si está presente, se usa directamente (compatibilidad con flujos directos).

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

                                            ← Cookies: auth.session + auth.refresh

                                         6. Leer rol desde GET /usuario/profile
                                            Redirigir a /publicador o /ofertador
                                            según rol
```

**URL del callback**: `app.{APP_DOMAIN}/auth/callback` — ruta dedicada en el Shell que no renderiza layout, solo ejecuta el paso 2 PKCE y redirige. No debe ser indexable ni accesible directamente sin parámetros válidos.

**Recovery de contraseña**: los enlaces del email apuntan a `login.{APP_DOMAIN}/reset-password?token=...&uuid=...`. Esta ruta vive en `app-login`, que tiene acceso a `ResetPasswordForm`. El portal no necesita manejar este flujo.

**Logout**: `GET /security/logout` puede llamarse desde cualquiera de las dos apps. Ambas deben redirigir a `login.{APP_DOMAIN}` al detectar que la sesión expiró (`401` del BFF).

#### Cookies de sesión

| Cookie | Flags | TTL | Descripción |
|--------|-------|-----|-------------|
| `auth.session` | `HttpOnly; SameSite=Lax` | **1 hora** (TTL Redis) | ID de sesión vinculado a los tokens internos de ms-auth |
| `auth.refresh` | `HttpOnly; SameSite=Lax; Secure en HTTPS` | **7 días** (rotante) | Refresh token; cada uso emite uno nuevo, el anterior queda inválido |

> El JWT es **interno a ms-auth**. El frontend nunca lo ve ni lo almacena.

#### Consideración CSRF

`SameSite=Lax` bloquea cookies en cross-site POST desde navegadores modernos, cubriendo los vectores CSRF más comunes. Para operaciones críticas (aceptar oferta, confirmar depósito) se recomienda añadir un token anti-CSRF (`X-CSRF-TOKEN`) como segunda línea de defensa. ⬜ Post-MVP v1.

#### Reglas de sesión
- Logout activo: `GET /security/logout` destruye la sesión en Redis e invalida ambas cookies.
- **No sesiones simultáneas** (ver §2): el nuevo login invalida la sesión anterior en Redis.
- Inactividad: cuando `auth.session` expira, el interceptor HTTP Angular intenta refresh silencioso. Si `auth.refresh` también expiró, redirige al login con mensaje `"Tu sesión expiró"`.
- 2FA: ⬜ Post-MVP v1 — TOTP / SMS. Los roles `ADMIN_*` y `SUPER_ADMIN` serán los primeros en requerirlo.

---

### 14.2 Control de Acceso (RBAC)

- **Validación dual**: el frontend oculta elementos según el rol (UX), pero el **backend valida en cada request** (seguridad real). Una respuesta `403` del backend nunca debe provocar pantalla en blanco — el frontend muestra un estado de acceso denegado controlado.
- **Principio de mínimo privilegio**: cada rol solo recibe los permisos que necesita para operar. Sin herencia implícita entre roles.
- **Pertenencia a organización**: el backend verifica que el usuario sea miembro activo de la organización afectada en operaciones sobre recursos de org (facturas, miembros, configuración).
- **Separación de contextos**: un `EJECUTIVO_FINANCIADORA` no puede ver facturas ni datos de otras organizaciones financieras, aunque comparta la plataforma.

---

### 14.3 Protección contra Ataques Comunes (OWASP Top 10)

| Amenaza | Mitigación |
|---------|-----------|
| **A01 — Broken Access Control** | RBAC estricto en backend. Validación de org membership en cada operación de recurso. |
| **A02 — Cryptographic Failures** | HTTPS / TLS 1.2+ obligatorio. Datos sensibles en reposo cifrados (contraseñas con bcrypt/argon2, datos PII). No transmitir datos sensibles en query params. |
| **A03 — Injection** | ORM con queries parametrizados. Validación y sanitización de todos los inputs en backend. Nunca concatenar SQL/queries. |
| **A04 — Insecure Design** | Flujos de negocio con controles anti-fraude (§14.5). Validación de estado de factura antes de cada transición. |
| **A05 — Security Misconfiguration** | CORS estricto (solo dominios autorizados). Headers de seguridad: `Strict-Transport-Security`, `X-Content-Type-Options`, `X-Frame-Options: DENY`, `Content-Security-Policy`. |
| **A06 — Vulnerable Components** | Dependencias auditadas con `npm audit` / `snyk` en CI/CD. Sin librerías abandonadas o con CVEs activos. |
| **A07 — Auth Failures** | Rate limiting en login (ver §14.4). Mensajes de error genéricos (anti-enumeración). |
| **A08 — Software Integrity Failures** | Verificación de integridad en el pipeline CI/CD. Subresource Integrity (SRI) para assets externos. |
| **A09 — Logging Failures** | Audit log de operaciones críticas (ver §14.6). Logs de autenticación con IP y User-Agent. |
| **A10 — SSRF** | La llamada al SII se realiza desde el backend con URL hardcodeada. Sin endpoints que acepten URLs arbitrarias del cliente. |

---

### 14.4 Rate Limiting y Protección Anti-Fuerza Bruta

| Endpoint | Límite | Acción al superar |
|----------|--------|------------------|
| `POST /security/authenticate` | 5 intentos fallidos en 10 minutos por IP+username | Bloqueo temporal 15 min + notificación al usuario |
| `POST /security/session/refresh` | 30 req/min por IP | Responde `429 Too Many Requests` |
| `POST /security/password-reset/request` | 3 solicitudes en 15 min por correo | Anti-enumeración: siempre responde `200` (ver §9.1) |
| Endpoints de API general | 100 req/min por usuario autenticado | `429` con header `Retry-After` |
| Subida de documentos | 10 documentos/hora por org | `429` con mensaje descriptivo |

---

### 14.5 Controles de Negocio Anti-Fraude

Específicos del dominio de factoring:

- **Validación de RUT con SII** antes de activar una organización — verifica que el RUT exista, esté activo y tenga habilitada la emisión de facturas electrónicas (§11 del doc).
- **Unicidad de factura**: una factura no puede publicarse dos veces en la plataforma (control por folio + RUT emisor).
- **Trazabilidad de estados**: cada transición de estado de una factura queda registrada con timestamp, userId y origen (UI, webhook, sistema). No existen transiciones retroactivas.
- **Confirmación doble en aceptación de oferta**: el cliente debe confirmar explícitamente la oferta antes de que sea vinculante (modal de doble confirmación — §7).
- **Firma de operaciones críticas**: las acciones de aceptar oferta y confirmar depósito requieren que el usuario esté autenticado con sesión vigente (no pueden ejecutarse con tokens cercanos a expirar sin refresh previo).

---

### 14.6 Trazabilidad y Auditoría

Requerido por buenas prácticas CMF para plataformas financieras.

#### Operaciones que generan registro de auditoría

| Categoría | Operaciones |
|-----------|------------|
| **Autenticación** | Login exitoso, login fallido, logout, refresh de token, cambio de contraseña |
| **Facturas** | Creación, publicación, rechazo, aceptación de oferta, confirmación de depósito, denuncia |
| **Ofertas** | Creación, modificación, aceptación, rechazo, Match & Beat |
| **Organización** | Creación, activación, desactivación, cambio de datos |
| **Membresía** | Ingreso (con método), remoción, cambio de rol (promote/demote) |
| **Acceso** | Aprobación/rechazo de solicitudes de membresía, invitaciones enviadas/revocadas |
| **Admin de plataforma** | Cambios realizados por `SUPER_ADMIN` / `ADMIN` sobre cualquier recurso |

#### Estructura del registro de auditoría

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
| `metadata` | JSON adicional según el tipo de acción (ej. motivo de rechazo, rol anterior/nuevo) |

- Los registros de auditoría son **inmutables** — no pueden modificarse ni eliminarse por ningún rol, incluido `SUPER_ADMIN`.
- Retención mínima recomendada: **5 años** (alineado con normativas contables/financieras chilenas).

---

### 14.7 Privacidad y Datos Personales

Contexto: Chile está en transición hacia una nueva Ley de Protección de Datos Personales (reemplazo de Ley 19.628). Se recomienda diseñar bajo los principios de la nueva ley desde el inicio.

| Principio | Aplicación en Factor |
|-----------|---------------------|
| **Finalidad** | Los datos se recopilan solo para los fines de la plataforma (factoring). No se comparten con terceros sin consentimiento. |
| **Minimización** | Se solicitan solo los datos necesarios para cada flujo. Ej: el perfil público no expone email, teléfono ni RUT (§9.2). |
| **Transparencia** | Términos y Condiciones visibles antes de publicar una factura (§6). Política de privacidad accesible desde el footer. |
| **Seguridad** | Datos PII cifrados en reposo. Contraseñas hasheadas con bcrypt/argon2 (nunca almacenadas en texto plano). |
| **Derecho de acceso/cancelación** | El usuario puede exportar o solicitar la eliminación de sus datos personales (funcionalidad de backoffice, fuera de scope MVP de UI). |

---

### 14.8 Seguridad en el Frontend (Angular)

- Angular sanitiza automáticamente el DOM — **no usar `bypassSecurityTrust*`** salvo casos excepcionales documentados y revisados.
- **No almacenar datos sensibles en `localStorage` ni `sessionStorage`** — estado de sesión solo en memoria o httpOnly cookie.
- El state global (Module Federation singleton) **no debe incluir** el JWT ni datos PII completos. Solo lo mínimo necesario para la UI (nombre, rol, `unreadCount`).
- Variables de entorno con URLs de API y claves públicas gestionadas por el pipeline de CI/CD — **no harcodear** en código fuente.
- Content Security Policy restrictiva: bloquear inline scripts, evaluar solo fuentes propias y CDNs explícitamente listados.

---

## 15. Convenciones del Documento

- Los IDs de historias siguen el formato `US-[Módulo][Número]`: `P` = Publicador, `O` = Ofertador, `D` = Dashboard, `A` = Auth.
- Los componentes listados son propuestas iniciales, no definitivos.
- Criterios de aceptación marcados con `[ ]` indican pendiente de verificación/implementación.
- Las secciones con `⬜` indican trabajo no iniciado; `🔧` indican en desarrollo; `✅` indican completo.
