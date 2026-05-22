# SEIS App - Arquitectura Monorepo

**Última actualización:** 2026-05-20  
**Scope:** Mapa de dependencias entre servicios, frontends e infraestructura

---

## 1. Topología de Servicios

### Backend Microservicios

| Servicio | Puerto | Responsabilidad | Dependencias | Estado Análisis |
|----------|--------|-----------------|--------------|-----------------|
| **ms-auth** | 3000 | Autenticación JWT, OAuth | postgres, redis, vault | ✅ CodeGraph init |
| **ms-core** | 3001 | Dominio principal (facturas, usuarios) | postgres, redis, vault | ✅ CodeGraph init |
| **bff_seis_app** | 3002 | API Gateway / BFF | ms-auth (3000), ms-core (3001) | ⏳ Pendiente |
| **ms-storage-orchestrator** | ? | Orquestación de almacenamiento | minio, postgres | ✅ CodeGraph init |
| **worker-storage-processor** | ? | Procesamiento async de archivos | minio, redis, postgres | ✅ CodeGraph init |

### Frontend Aplicaciones

| App | Puerto | Tipo | Dependencias | Estado Análisis |
|-----|--------|------|--------------|-----------------|
| **app-login-erp-seis** | 8082 | SPA (Auth) | bff (3002), ms-auth (3000) | ⏳ Pendiente |
| **seis-app-frontend** (Portal) | 8083 | SPA (Portal principal) | bff (3002), ms-core (3001) | ⏳ Pendiente |
| **mfe-gestion-usuario** | 8084 | Micro Frontend | bff (3002), ms-auth (3000) | ⏳ Pendiente |
| **mfe-dashboard-facturas** | 8085 | Micro Frontend | bff (3002), ms-core (3001) | ⏳ Pendiente |
| **mfe-publicador-facturas** | 8086 | Micro Frontend | bff (3002), ms-core (3001) | ⏳ Pendiente |
| **mfe-ofertador-facturas** | 8087 | Micro Frontend | bff (3002), ms-core (3001) | ⏳ Pendiente |

### Infraestructura Compartida

| Servicio | Rol | Consumidores | Dockercompose |
|----------|-----|--------------|---------------|
| **postgres** | Base de datos principal | ms-auth, ms-core, orchestrator | docker-compose-app-imfra.yml |
| **redis** | Cache + sesiones + job queue | ms-auth, ms-core, BFF | docker-compose-app-imfra.yml |
| **vault** | Secrets management | ms-auth, ms-core, BFF | docker-compose-app-imfra.yml |
| **minio** | Object storage (archivos) | ms-storage, worker | docker-compose-app-imfra.yml |
| **prometheus** | Métricas | All services (scrape labels) | monitoring/ |
| **grafana** | Dashboards | N/A (UI) | monitoring/ |
| **kong** | API Gateway (producción) | bff → kong → backend | docker-compose-app-imfra.yml |

---

## 2. Flujos de Datos Críticos

### Flujo: Usuario se Autentica
```
Frontend (Login) 
  → POST /auth/login (BFF 3002)
  → ms-auth (3000) /login
  → postgres (select usuario, contacto)
  → redis (cache JWT)
  ← JWT token
```

### Flujo: Consultar Facturas
```
Frontend (MFE Dashboard)
  → GET /facturas?orgId=X (BFF 3002)
  → ms-core (3001) /facturas
  → postgres (select + permisos.check_access)
  → redis (cache resultados)
  ← JSON facturas
```

### Flujo: Subir Factura (Async)
```
Frontend (MFE Publicador)
  → POST /upload (BFF 3002)
  → ms-storage-orchestrator
  → minio (store PDF)
  → postgres (insert factura row)
  → redis (queue job)
  → worker-storage-processor
  → OCR/PDF parsing
  → postgres (update factura con OCR data)
  ← webhook a BFF con status
```

---

## 3. Acoplamiento e Impacto de Cambios

### 🔴 Dependencias Críticas (Alto Impacto si Fallan)

1. **postgres** (CRÍTICO)
   - Si cae: Todos los servicios se detienen
   - Afecta: ms-auth, ms-core, storage, workers
   - Mitigación: Replica, backups automáticos

2. **redis** (ALTO)
   - Si cae: Pérdida de caché, sesiones, job queue
   - Afecta: BFF, ms-auth (sesiones), workers (job queue)
   - Mitigación: Cluster redis, sentinel

3. **ms-auth** (ALTO)
   - Si cae: No nuevos logins, expiraciones de JWT
   - Afecta: BFF (valida JWT), frontend (logout forzado)
   - Mitigación: Health checks, reintentos exponenciales

4. **BFF** (MEDIO)
   - Si cae: Frontend sin conectividad
   - Afecta: Todos los frontends
   - Mitigación: Múltiples instancias, load balancer

### 🟡 Cambios de Bajo Impacto

- MFE individuales: Solo afecta ese MFE
- Dominio específico en ms-core: Buscar callers en BFF
- Cache en redis: Invalidar sin parar servicios

---

## 4. Análisis CodeGraph por Módulo

### Ya Configurados ✅
- `/BACKEND/ms-auth` → codegraph.json
- `/BACKEND/ms-core` → codegraph.json
- `/BACKEND/storage/ms-storage-orchestrator` → codegraph.json
- `/BACKEND/storage/worker-storage-processor` → codegraph.json

### Por Configurar ⏳
- `/BACKEND/bff_seis_app` → Debe tener imports de ms-auth, ms-core
- `/FRONTEND/app-login-erp-seis` → Llamadas a /api/auth, /api/core
- `/FRONTEND/seis-app-frontend` → Llamadas a BFF (3002)
- `/DB/db_seis_erp/init-db` → Schema dependencies (permisos → factura → core)

### Root Monorepo 📦
- `/codegraph.json` (raíz) → Agrupa todas las relaciones cross-project
- Permite detectar:
  - Imports frontend→backend (package imports)
  - Llamadas HTTP (documentadas en BFF)
  - Dependencias de BD (triggers, FKs en SQL)

---

## 5. Próximos Pasos Recomendados

### Corto Plazo (Esta Semana)
1. [ ] Ejecutar `codegraph init` en raíz del monorepo
2. [ ] Revisar `codegraph.json` en raíz para detectar ciclos
3. [ ] Documentar endpoints BFF que no estén mapeados aún
4. [ ] Crear visual Mermaid de arquitectura (flowchart)

### Mediano Plazo (Este Mes)
1. [ ] Detectar servicios desacoplables (refactor para reducir acoplamiento)
2. [ ] Crear matriz de impacto: "Si cambio X, ¿quién se afecta?"
3. [ ] Validar que docker-compose-app-*.yml refleje dependencias reales
4. [ ] Documentar points of failure y mitigaciones

### Largo Plazo (Roadmap)
1. [ ] Implementar API Contract Testing (para frontend↔backend)
2. [ ] Consumer-Driven Contracts (CDC) para ms-auth, ms-core
3. [ ] Event mesh si se requiere async entre servicios
4. [ ] Observabilidad distribuida (trace correlations entre servicios)

---

## 6. Referencias

- Docker Compose Arquitectura: `docker-compose-app-services.yml`
- Infraestructura: `docker-compose-app-imfra.yml`
- Frontends: `docker-compose-app-frontend.yml`
- CodeGraph Output: `graphify-out/`
- Grafana Dashboards: `monitoring/grafana/dashboards`
