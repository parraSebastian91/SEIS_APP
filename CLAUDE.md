# CLAUDE.md — SEIS App (Proyecto Factor)
> Co-arquitecto: Claude Sonnet 4.6
> Última actualización: 2026-05-25 (graphify sync)
> Tagline: "Conexión Financiera"
> Knowledge graph: `graphify-out/graph.json` — 3,929 nodos · 5,126 edges · 469 comunidades

---

## 1. ADN del Negocio

**Propósito:** Conectar empresas (emisores de facturas) con ejecutivas de factoring (inversores) mediante una plataforma basada en confianza y reputación.

**Valor diferencial:**
- Transparencia social e historial de relaciones previas
- Procesamiento automatizado via OCR para agilizar liquidez
- Insignias de reputación ("Cliente Recurrente") basadas en historial

---

## 2. Stack Tecnológico (verificado por graphify 2026-05-25)

### Frontend — Angular Micro Frontend (Module Federation nativo)
- **Framework:** Angular — `@angular-architects/native-federation`
- **Estado global:** Signals — `UserStateService` Singleton en `shared-utils`
- **Proyecto raíz:** `FRONTEND/seis-app-frontend/` (workspace Angular multi-proyecto)
- **MFEs implementados:**
  | Proyecto | Puerto | Rol |
  |---|---|---|
  | `seis-portal` | shell | Contenedor principal, sidebar, navbar, routing |
  | `seis-mfe-ofertador-facturas` | remoto | Marketplace facturas, calculadora, perfil riesgo deudor |
  | `seis-mfe-publicador-facturas` | remoto | Publicación de facturas, visor documental panzoom |
  | `seis-mfe-dashboard-facturas` | remoto | Dashboard KPI de facturas |
  | `seis-mfe-gestion-usuario` | remoto | Perfil usuario (ver/editar) |
  | `app-login-erp-seis` | 8082 | SPA login independiente |
- **Librería compartida:** `shared-utils` — componentes/servicios reutilizables entre MFEs
- **Federation manifest:** `seis-portal/public/federation.manifest.json` (dev) + `.prod.json`

### Backend — NestJS / TypeScript
- **ms-auth** (puerto 3000) — Autenticación JWT, guards, OAuth
- **ms-core** (puerto 3001) — Dominio: facturas, usuarios, permisos (`FacturasService`, `FacturaManagerUseCase`)
- **bff_seis_app** (puerto 3002) — API Gateway / BFF, adapters HTTP input/output

### Backend — Java / Spring Boot
- **ms-bodegaje** — Gestión de inventario/bodegaje (entidades JPA: `ItemJpaEntity`, `ItemModel`, `ContactoRepository`, `OrganizacionRepository`)

### Storage Layer — Node.js
- **ms-storage-orchestrator** — Orquestación de almacenamiento (MinIO)
- **worker-storage-processor** — Procesamiento async: OCR + indexación de documentos

### Infraestructura
| Servicio | Rol |
|---|---|
| **PostgreSQL** | Persistencia de dominio (schemas: `factura`, `core`, `media`) |
| **Redis** | Caché, sesiones, cola de trabajos, notificaciones real-time |
| **MinIO** | Almacenamiento de objetos (`/private` + `/public`) |
| **Vault** | Gestión de secretos (JWT, DB credentials) |
| **Kong** | API Gateway externo (routing a BFF) |
| **Grafana/Prometheus/Loki** | Stack de observabilidad |

---

## 3. Arquitectura de Datos

### Pipeline de Facturas (OCR)
```
Angular (MFE Publicador)
  → Presigned URL (MinIO /private)
  → Webhook → ms-storage-orchestrator
  → worker-storage-processor (OCR + indexación)
  → ms-core (FacturaManagerUseCase)
  → PostgreSQL (schema factura)
```

### Pipeline de Ofertas (tiempo real)
```
Angular (MFE Ofertador) ←→ WebSocket
  → BFF (bff_seis_app) → ms-core
  → PostgreSQL (factura.ofertas)
  → Redis (notificaciones interferencia HU-09)
```

### Estrategia MinIO
- `/private` → Originales, PDFs, documentos legales (acceso restringido)
- `/public` → Assets optimizados, avatares, logos (`logo.svg`, `logo.png`, `wallpaper1.png`)

### Esquemas PostgreSQL
| Schema | Tabla | Contenido |
|---|---|---|
| `factura` | `factura` | Datos del documento (monto, vencimiento, deudor) extraídos por OCR |
| `factura` | `ofertas` | Propuestas de tasa y monto de las ejecutivas |
| `factura` | `historial_negocios` | Calificación cruzada y registro de operaciones cerradas |
| `core` | _(pendiente definir)_ | Datos de usuarios y empresas |
| `media` | _(pendiente definir)_ | Metadatos de archivos procesados |

---

## 4. Reglas de Arquitectura

### NestJS — Clean Architecture (ms-auth, ms-core, bff)
```
src/
├── core/domain/         → Entidades, interfaces, errores de dominio
├── core/use-cases/      → Lógica de negocio pura (FacturaManagerUseCase)
├── infrastructure/      → Adapters HTTP, DB, Vault, Redis
└── guards/              → JwtAuthGuard, PermisosGuard (duplicado en ms-auth y ms-core)
```

### BFF — Input/Output Adapters
- Toda comunicación frontend→backend pasa por `bff_seis_app` (puerto 3002)
- Adapters separados por dirección: `input/` (HTTP requests) y `output/` (hacia ms-auth/ms-core)
- Kong enruta externamente hacia el BFF

### Queries en repositorio, no en vistas BD
- Las queries viven en la capa de repositorio de cada microservicio
- Excepción justificada: vistas materializadas para reportería de historial/reputación
- Nunca compartir queries entre microservicios — exponer endpoints

### Seguridad de archivos
- Avatares y logos → `/public` ✅
- Facturas y documentos legales → `/private` 🔒 (nunca públicos)

---

## 5. Decisiones Técnicas Registradas

| Fecha | Decisión | Razón |
|---|---|---|
| 2026-05-25 | Queries en repositorio NestJS, no en vistas BD | Mantener Clean Architecture, facilitar tests y mocks |
| 2026-05-25 | Vault Obsidian fuera del repo | Evitar ruido en commits con metadatos de workspace |
| 2026-05-25 | CLAUDE.md como puente repo ↔ Obsidian | Contexto versionado con el código |
| 2026-05-25 | Guards JWT duplicados en ms-auth y ms-core | Cada servicio valida independientemente — no hay SPOF de autenticación |
| 2026-05-25 | Module Federation nativo (no Webpack) | `@angular-architects/native-federation` — menor overhead, ESM nativo |

---

## 6. Convenciones de Naming

```
# MinIO paths
/private/invoices/{uuid}/original.pdf
/private/invoices/{uuid}/legal/
/public/avatars/{user_id}/avatar.webp
/public/banners/{company_id}/banner.webp
```

---

## 7. Historias de Usuario Implementadas (HU)

| HU | Título | MFE |
|---|---|---|
| HU-01 | Tablero marketplace tiempo real | seis-mfe-ofertador-facturas |
| HU-02 | Filtros rápidos marketplace | seis-mfe-ofertador-facturas |
| HU-03 | Visor documental facturas (panzoom) | seis-mfe-ofertador-facturas / publicador |
| HU-04 | Validador delta OCR | seis-mfe-ofertador-facturas |
| HU-05 | Perfil riesgo deudor | seis-mfe-ofertador-facturas |
| HU-06 | Calculadora parámetros liquidación | seis-mfe-ofertador-facturas |
| HU-07 | Pre-liquidación explícita | seis-mfe-ofertador-facturas |
| HU-08 | Botón Match & Beat | seis-mfe-ofertador-facturas |
| HU-09 | Alerta interferencia WebSocket | seis-mfe-ofertador-facturas |
| HU-10 | Modal doble confirmación oferta | seis-mfe-ofertador-facturas |

---

## 8. Nodos God (abstracciones más conectadas — graphify)

> Actualizado desde `graphify-out/graph.json`. Tocar estos nodos tiene impacto alto.

| Nodo | Edges | Módulo |
|---|---|---|
| `FacturaViewComponent` | 67 | seis-mfe-publicador-facturas |
| `ModalPublicacionFacturaComponent` | 33 | seis-mfe-publicador-facturas |
| `PublicadorFacturasComponent` | 33 | seis-mfe-publicador-facturas |
| `ItemJpaEntity` | 28 | ms-bodegaje (Java) |
| `ItemModel` | 27 | ms-bodegaje (Java) |
| `FacturaManagerUseCase` | — | ms-core (bridge BFF ↔ Invoice Domain) |

---

## 9. Pendientes / Backlog Técnico

- [ ] Definir esquemas `core.*` y `media.*` en PostgreSQL
- [ ] Centralizar configs `.codegraph/config.json` (actualmente duplicados en cada servicio)
- [ ] Revisar cohesión baja en `Auth Security & Guards` (score 0.05) — posible refactor
- [ ] Revisar 895 nodos débilmente conectados — posibles gaps de documentación
- [x] ~~Configurar Module Federation en Angular~~ — implementado con native-federation
- [x] ~~Definir estrategia JWT~~ — implementado en ms-auth con guards duplicados en ms-core

---

## 10. Personalidad del Co-arquitecto

- Priorizar siempre Clean Architecture en NestJS
- Escalabilidad de microservicios sobre comodidad
- Ser directo, técnico e ingenioso
- Nunca sugerir soluciones que acoplen microservicios innecesariamente