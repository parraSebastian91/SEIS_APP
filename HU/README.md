# Factor App — Documentación de Historias de Usuario

Registro completo de HUs para el frontend Angular 19 de la plataforma B2B de factoring digital.

---

## Estructura de carpetas

```
Claude/
├── factor-app-product.md        # Spec maestro del producto (§1–§15)
│
├── HU-Calculadora/              # HUs de referencia: calculadora (del dominio)
├── HU-Fase1/                    # HUs de implementación — infraestructura base
├── HU-Fase2/                    # HUs de implementación — autenticación PKCE
├── HU-Fase3/                    # HUs de implementación — gestión de usuario y org
├── HU-Fase4/                    # HUs de implementación — publicador de facturas
├── HU-Fase5/                    # HUs de implementación — ofertador / marketplace
├── HU-Fase6/                    # HUs de implementación — dashboards
├── HU-Fase7/                    # HUs de implementación — shell, diseño y registro
└── HU-Ref/                      # Documentos de referencia permanente (arquitectura, seguridad)

HU/                              # HUs originales de producto (dominio de negocio)
```

---

## Inventario completo

### Referencia de dominio (`/HU/` — Downloads)

| HU | Título |
|----|--------|
| HU-01 | Tablero de Competición en Tiempo Real (Marketplace) |
| HU-02 | Filtros Rápidos del Marketplace |
| HU-03 | Visor Documental de Facturas con Panzoom |
| HU-04 | Validador Delta OCR |
| HU-05 | Perfil de Riesgo del Deudor |
| HU-06 | Calculadora de Parámetros de Liquidación |
| HU-07 | Pre-liquidación Explícita |
| HU-08 | Botón Match & Beat |
| HU-09 | Alerta de Interferencia WebSocket |
| HU-10 | Modal de Doble Confirmación de Oferta |

### Referencia calculadora (`HU-Calculadora/`)

| HU | Título |
|----|--------|
| HU-06 | Calculadora de Parámetros de Liquidación |
| HU-07 | Pre-liquidación Explícita |
| HU-08 | Botón Match & Beat |
| HU-09 | Alerta de Interferencia WebSocket |
| HU-10 | Modal de Doble Confirmación de Oferta |

### Implementación técnica

#### Fase 1 — Infraestructura base (`HU-Fase1/`)

| HU | Título |
|----|--------|
| HU-00 | Convenciones de Código: Legibilidad y Baja Carga Cognitiva *(fundacional)* |
| HU-11 | Alineación de Builds en Development |
| HU-12 | Bootstrap del Shell con Manifest |
| HU-13 | `shared-utils` SessionService y Modelos |
| HU-14 | `shared-utils` HTTP Interceptors |

#### Fase 2 — Autenticación PKCE (`HU-Fase2/`)

| HU | Título |
|----|--------|
| HU-15 | Login PKCE (`app-login`) |
| HU-16 | Callback PKCE + `authGuard` + `SessionRestoreService` |
| HU-17 | Recuperación de Contraseña |

#### Fase 3 — Gestión de usuario y organización (`HU-Fase3/`)

| HU | Título |
|----|--------|
| HU-18 | Perfil de Usuario |
| HU-19 | Wizard Creación de Organización |
| HU-20 | Perfil de Organización |
| HU-21 | Gestor de Organización (3 pestañas) |
| HU-22 | Lookup KYC SII |

#### Fase 4 — Publicador de facturas (`HU-Fase4/`)

| HU | Título |
|----|--------|
| HU-23 | Subida de Factura (3 flujos) |
| HU-24 | Lista de Facturas + `factura-view` |
| HU-25 | Modal T&C + Detalle de Ofertas + Comparación |
| HU-26 | `NegotiationChat` (`shared-utils`) |

#### Fase 5 — Ofertador / Marketplace (`HU-Fase5/`)

| HU | Título |
|----|--------|
| HU-27 | Marketplace Lista de Facturas (Columna 1) |
| HU-28 | KPIs Header + Visor OCR (Secciones 2 y 3) |
| HU-29 | Calculadora de Parámetros de Liquidación (Sección 4) |
| HU-30 | Enviar Oferta Firme + Modal Doble Confirmación |

#### Fase 6 — Dashboards (`HU-Fase6/`)

| HU | Título |
|----|--------|
| HU-31 | Dashboard Cedente |
| HU-32 | Mis Ofertas Ejecutivo |
| HU-33 | Dashboard Ejecutivo |

#### Fase 7 — Shell, diseño y registro (`HU-Fase7/`)

| HU | Título |
|----|--------|
| HU-34 | Shell Sidebar + Top-Navbar |
| HU-35 | `SearchableCardSelect` (`shared-utils`) |
| HU-36 | `NotificationsSidebar` |
| HU-37 | Design System Tokens (3 capas CSS) |
| HU-38 | Registro de Usuario + `NoOrganizationGate` |

### Documentos de referencia permanente (`HU-Ref/`)

| HU | Título | Cubre spec |
|----|--------|-----------|
| HU-39 | Referencia Técnica de Arquitectura | §12, §13 |
| HU-40 | Seguridad y Cumplimiento | §14 |

---

## Stack técnico (resumen)

| Capa | Tecnología |
|------|-----------|
| Framework | Angular 19, standalone components, Angular Signals |
| Micro-frontends | `@angular-architects/module-federation` v19, manifest-based |
| Monorepo | Angular Multi-Project Workspace (`seis-app-frontend/`) |
| State global | `shared-utils` singleton (SessionService, interceptors, modelos, UI comunes) |
| API | Kong :8000 → ms-auth :3000, BFF :3002 |
| Real-time | WebSocket / SSE (canales: `marketplace`, `usuario:{id}`, `offer:{id}`) |
| CSS | Custom properties 3 capas (ref / semántica / org) — tema dark fijo MVP |
| Tipografía | Plus Jakarta Sans + JetBrains Mono (solo módulos financieros) |
| Auth | PKCE cross-app, cookies HttpOnly, sin JWT en frontend |
