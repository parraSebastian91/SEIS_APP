# HU-39 — Referencia Técnica de Arquitectura

*Tipo: documento de referencia permanente | No es una tarea de implementación incremental*
*Aplica a: todos los proyectos del monorepo | Consultar antes de modificar configs de build, routing, Module Federation o shared-utils*

---

## Propósito

Este documento centraliza los lineamientos técnicos de arquitectura del frontend: versiones de dependencias, topología de aplicaciones, configuración de Module Federation, enrutamiento global, diseño responsivo y contratos de API. Es la fuente de verdad para decisiones de scaffolding y configuración que afectan al monorepo completo.

---

## 1. Ecosistema y Versiones

| Dependencia | Versión objetivo | Notas |
|-------------|:----------------:|-------|
| Angular CLI / Core / Common | `^19.0.0` | Versión mayor estable al inicio del proyecto |
| `@angular-architects/module-federation` | `^19.0.0` | Debe coincidir con la versión mayor de Angular |
| TypeScript | `~5.5.0` | Compatible con Angular 19 |
| Webpack | `^5.90.0` | Subyacente a `@angular-architects/module-federation` |
| RxJS | `^7.8.0` | Versión ultra-estable; declarada como `singleton` en Module Federation |
| Node.js | `>=20.x LTS` | Requerido por Angular 19 |

> Las versiones se fijan en el momento de scaffolding. Actualizaciones mayores requieren validación de compatibilidad entre **todas** las apps del monorepo antes de aplicarse.

---

## 2. Topología de Aplicaciones

El frontend está dividido en **dos proyectos Angular independientes**:

| Proyecto | Contenedor | Puerto | Propósito |
|----------|-----------|:------:|----------|
| `app-login-erp-seis/` | `app_login` | 8082 | Login, recuperación de contraseña, inicio del flujo PKCE, registro de usuarios |
| `seis-app-frontend/` | `app_portal` + 4 MFEs | 8083–8087 | Portal principal + microfrontends |

```
 :8082               :8083
 app-login    PKCE   shell (seis-portal)
 ┌──────────┐  ───►  ┌──────────────────────────────────────┐
 │  Login   │        │  federation.manifest.json            │
 │  Recovery│        │  ├── mfe-gestion-usuario   :8084     │
 │  Registro│        │  ├── mfe-dashboard-facturas :8085    │
 └──────────┘        │  ├── mfe-publicador-facturas :8086   │
                     │  ├── mfe-ofertador-facturas :8087    │
                     │  └── /auth/callback (PKCE paso 2)   │
                     └──────────────────────────────────────┘
                                    │
                           Kong :8000
                    /api/auth  →  ms-auth  :3000
                    /api/core  →  bff      :3002
```

### Estructura del monorepo (`seis-app-frontend/`)

```
seis-app-frontend/
├── projects/
│   ├── seis-portal/                    # Host app (Shell)
│   ├── seis-mfe-gestion-usuario/       # Remote: perfil, org, gestor
│   ├── seis-mfe-dashboard-facturas/    # Remote: dashboards cedente/ejecutivo
│   ├── seis-mfe-publicador-facturas/   # Remote: publicador
│   ├── seis-mfe-ofertador-facturas/    # Remote: marketplace, calculadora
│   └── shared-utils/                   # Librería transversal (singleton)
├── dockerfile.portal
├── dockerfile.mfe-gestion-usuario
├── dockerfile.mfe-dashboard-facturas
├── dockerfile.mfe-publicador-facturas
├── dockerfile.mfe-ofertador-facturas
├── nginx.conf                          # Portal
├── nginx.mfe-*.conf                    # Uno por MFE
└── angular.json                        # Workspace multi-project
```

El build de cada app comienza compilando `shared-utils` primero:
```bash
npm run build -- shared-utils && npx ng build <project> --configuration development
```

`app-login` es un proyecto Angular standalone **separado**. No usa Module Federation ni `shared-utils`.

### Puertos de desarrollo

| App | Contenedor | Puerto | Ruta Kong |
|-----|-----------|:------:|-----------|
| Kong API Gateway | (—) | **8000** | — punto de entrada único |
| `app-login` | `app_login` | 8082 | — |
| Shell (portal) | `app_portal` | 8083 | — |
| `mfe-gestion-usuario` | `app_mfe_gestion_usuario` | 8084 | — |
| `mfe-dashboard-facturas` | `app_mfe_dashboard_facturas` | 8085 | — |
| `mfe-publicador-facturas` | `app_mfe_publicador_facturas` | 8086 | — |
| `mfe-ofertador-facturas` | `app_mfe_ofertador_facturas` | 8087 | — |
| `ms-auth` | `ms_auth` | 3000 | `/api/auth` |
| `bff_seis_app` | `bff_seis_app` | 3002 | `/api/core` |

> `app-login` y `app-portal` reciben `API_BASE_URL=http://localhost:8000` vía variable de entorno Docker. Los MFEs obtienen la base URL en runtime desde `window.location`.

---

## 3. Configuración de Module Federation (Manifest-based)

Se usa `@angular-architects/module-federation` en **modo manifest** — las URLs de los remotos no están hardcodeadas en webpack; se resuelven en runtime cargando `federation.manifest.json`.

### Flujo de resolución

```
Shell bootstrap
  └─► fetch(federation.manifest.json)
        └─► loadManifest() → initFederation()
              └─► loadRemoteModule({ manifestName, exposedModule })
```

### `federation.manifest.json` (copiado al bundle en build)

```json
{
  "mfeGestionUsuario":    "http://localhost:8084/remoteEntry.json",
  "mfeDashboardFacturas": "http://localhost:8085/remoteEntry.json",
  "mfePublicadorFacturas":"http://localhost:8086/remoteEntry.json",
  "mfeOfertadorFacturas": "http://localhost:8087/remoteEntry.json"
}
```

> En el Dockerfile del portal, `federation.manifest.prod.json` sobrescribe `federation.manifest.json` antes del stage Nginx.

### Shell — `webpack.config.js`

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

### MFE remoto — ejemplo `seis-mfe-publicador-facturas`

```js
// projects/seis-mfe-publicador-facturas/webpack.config.js
const { shareAll, withModuleFederationPlugin } = require('@angular-architects/module-federation/webpack');

module.exports = withModuleFederationPlugin({
  name: 'mfePublicadorFacturas',
  filename: 'remoteEntry.json',   // JSON, no .js
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

### Nginx — caché de `remoteEntry.json`

Cada MFE tiene su propio `nginx.mfe-*.conf`:
- `remoteEntry.json`: `Cache-Control: no-store` — siempre fresco para el Shell.
- Activos estáticos (`.js`, `.css`): `Cache-Control: public, immutable, 1y` — cacheados por hash de contenido.

> Cada MFE expone sus **rutas** (no un componente directamente), lo que habilita lazy loading de módulos completos desde el Shell.

---

## 4. Enrutamiento Global — Shell (`app.routes.ts`)

Con el modo manifest, `loadRemoteModule` recibe `{ manifestName, exposedModule }` — sin URL hardcodeada.

```ts
// projects/seis-portal/src/app/app.routes.ts
import { Routes } from '@angular/router';
import { loadRemoteModule } from '@angular-architects/module-federation';

export const APP_ROUTES: Routes = [
  { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
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

## 5. Principios de Arquitectura Angular

| Principio | Regla |
|-----------|-------|
| **Standalone Components** | Prohibido usar `NgModule` tradicionales. Toda la app usa `standalone: true`. |
| **Lazy Loading** | Cada MFE se carga bajo demanda vía `loadRemoteModule`. Nunca importar directamente en el Shell. |
| **Dependencias compartidas** | Angular Core, Common, Router, RxJS y FormsModule declarados como `singleton: true` en todos los `webpack.config.js`. |
| **State global** | Solo a través de servicios de `shared-utils` (singleton via MF shared scope). Prohibido el acoplamiento directo entre MFEs. |
| **TypeScript estricto** | `strict: true` en todos los `tsconfig.json`. Sin `any` implícito. |
| **Signals** | Preferir Angular Signals sobre `BehaviorSubject` para estado local. RxJS se reserva para flujos asíncronos (WebSocket, HTTP). |
| **Build** | Todos los proyectos del monorepo se compilan con `--configuration development` en los Dockerfiles (source maps + logs). |
| **Base-href** | Cada app se construye con `--base-href=/<project-name>/`. El Shell resuelve la URL base en runtime. |

### Librería `shared-utils` — State transversal

`shared-utils` se compila primero (`npm run build -- shared-utils`) y se declara como **singleton** en el shared scope de Module Federation: todos los MFEs consumen la misma instancia en memoria.

| Responsabilidad | Descripción |
|-----------------|-------------|
| **Session state** | `SessionService` — usuario autenticado, organización activa, roles. Angular Signals reactivas. |
| **HTTP base** | Interceptores: adjunta cookies de sesión, renovación silenciosa de `auth.refresh`, manejo centralizado de 401/403. |
| **Modelos compartidos** | Interfaces TypeScript (`User`, `Organization`, `Factura`, `SessionState`, etc.) usadas por Shell y todos los MFEs. |
| **Componentes UI comunes** | `SearchableCardSelect`, `NegotiationChat`, `OcrNotesList`, `RutInput`, `PasswordStrengthMeter`, `AddressForm`. |

> **Nota**: el singleton de MF expone el estado de sesión a cualquier MFE cargado. Refinamiento futuro: scope isolation por MFE con tokens de acceso explícitos.

---

## 6. `package.json` — Dependencias clave

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
    "@angular/cli":                        "^19.0.0",
    "@angular-devkit/build-angular":       "^19.0.0",
    "typescript":                          "~5.5.0",
    "webpack":                             "^5.90.0"
  }
}
```

> Las versiones de dependencias compartidas **deben ser idénticas en todos los `package.json`** del monorepo para que Module Federation resuelva correctamente los singletons.

---

## 7. Contratos de API

El frontend interactúa exclusivamente con el BFF a través de Kong. `ms-auth` solo recibe llamadas directas para el flujo PKCE.

| Servicio | Puerto | Propósito |
|----------|:------:|-----------|
| `ms-auth` | 3000 | Autenticación PKCE, sesiones Redis, recuperación de contraseña |
| `bff_seis_app` | 3002 | Fachada de negocio: facturas, perfil, menú, objetos, T&C |

### Mapeo feature → endpoint

| Feature | Servicio | Método | Ruta |
|---------|----------|:------:|------|
| Login paso 1 PKCE | ms-auth | `POST` | `/security/authenticate` |
| Login paso 2 PKCE | ms-auth | `POST` | `/security/callback` |
| Renovar sesión | ms-auth | `POST` | `/security/session/refresh` |
| Logout | ms-auth | `GET` | `/security/logout` |
| Solicitar recovery | ms-auth | `POST` | `/security/password-reset/request` |
| Validar token recovery | ms-auth | `GET` | `/security/password-reset/validate?token=&uuid=` |
| Ejecutar cambio de contraseña | ms-auth | `POST` | `/security/password-reset/reset` |
| Menú navegación portal | BFF | `GET` | `/portal/menu` |
| Perfil usuario (lectura) | BFF | `GET` | `/usuario/profile` |
| Perfil usuario (edición) | BFF | `PUT` | `/usuario/profile` |
| Avatar y banner | BFF | `GET` | `/usuario/profile/img` |
| Organizaciones del usuario | BFF | `GET` | `/usuario/profile/organizacion` |
| Lista facturas de una org | BFF | `GET` | `/facturas/list/:organizacionUUID` |
| Publicar factura | BFF | `POST` | `/facturas` |
| Editar campo de factura | BFF | `PATCH` | `/facturas` |
| Registrar aceptación T&C | BFF | `POST` | `/facturas/autorizacion` |
| Obtener versión activa T&C | BFF | `GET` | `/terminos/activo` |
| Obtener presigned URL (MinIO) | BFF | `GET` | `/object/presigned-url/:objectType` |
| Subir archivo (multipart) | BFF | `POST` | `/object/:objectType` |
| Subir archivo (raw binary) | BFF | `PUT` | `/object/:objectType` |

### Tipos de `objectType` para subida de archivos

| `objectType` | Uso | Query params requeridos |
|---|---|---|
| `DOCUMENT_DTE` | XML/PDF factura electrónica (DTE) | `fileName`, `fileType`, `userName`, `organization` |
| `DOCUMENT_DTE_RESPALDO` | Documento respaldo de factura | `fileName`, `fileType`, `userName`, `organization`, `idFactura` |

### Envolvente de respuesta (`ApiResponse<T>`)

Todos los endpoints del BFF retornan:

```json
{
  "status": 200,
  "message": "Descripción del resultado",
  "data": {}
}
```

El interceptor HTTP de Angular lee `data` para obtener el payload. Los errores (`4xx`, `5xx`) siguen la misma envolvente — el interceptor lee `status` para mostrar mensajes estándar.

### Header de trazabilidad

El BFF propaga `X-Correlation-Id`. Incluirlo en todas las requests mutantes para correlacionar logs entre ms-auth y BFF en incidencias.

---

## 8. Diseño Responsivo — Breakpoints y Comportamientos

### Breakpoints de referencia

| Breakpoint | Rango | Dispositivo típico |
|------------|-------|--------------------|
| `xs` | < 480px | Teléfono móvil |
| `sm` | 480px – 768px | Teléfono grande / phablet |
| `md` | 768px – 1024px | Tablet |
| `lg` | 1024px – 1280px | Laptop |
| `xl` | > 1280px | Desktop / pantalla grande |

### Comportamientos adaptativos por componente

| Componente | `lg+` | `xs–md` |
|------------|-------|---------|
| `factura-view` | Layout 2 columnas (foto izq. / formulario der.) | Layout 1 columna (foto arriba, formulario abajo) |
| `InvoiceNotificationSidebar` | Panel lateral fijo (overlay parcial) | Bottom sheet pantalla completa |
| `InvoiceUploadModal` | Modal centrado de ancho fijo | Fullscreen modal |
| `OfferCompareModal` | Grid hasta 3 columnas | Scroll horizontal o comparación de a 2 |
| `MarketplaceTable` / `InvoiceList` | Tabla con todas las columnas | Tarjetas apiladas (card view) |
| `InvoiceFormStepper` | Stepper horizontal | Stepper vertical |
| Sidebar Shell | Visible expandida o colapsada (ícono) | Oculta; accesible por BottomNavBar |
| `top-navbar` | Barra superior completa | Simplificada / 2 filas |

### Principios generales

- **Mobile-first**: diseñar primero para pantalla pequeña y expandir progresivamente.
- **Touch targets**: área mínima 44×44px para botones e interactivos en móvil.
- **Tablas → tarjetas**: cualquier tabla con más de 3 columnas colapsa a card view en `xs–sm`.
- **Sidebars → bottom sheets**: los paneles laterales se convierten en drawers desde abajo en móvil.
- **Formularios**: en pantalla pequeña, campos apilados en una sola columna. Datepickers usan el nativo del SO en móvil.
- **Modales**: en `xs–sm`, los modales ocupan pantalla completa.

> Los comportamientos adaptativos específicos de cada componente se detallan en su HU de implementación. Esta sección es de referencia general.
