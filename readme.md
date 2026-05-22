# 🚀 SEIS App - ERP Financiero con Microservicios

**Sistema de Gestión de Facturas y Financiamiento** construido con arquitectura de microservicios NestJS, Angular Micro Frontends, PostgreSQL y análisis de dependencias con CodeGraph.

📚 **Documentación Principal:**
- [MONOREPO_ARCHITECTURE.md](MONOREPO_ARCHITECTURE.md) - Arquitectura completa, flujos de datos, dependencias críticas
- [.github/copilot-instructions.md](.github/copilot-instructions.md) - Directrices para development con CodeGraph
- [DB/db_seis_erp/README.md](DB/db_seis_erp/README.md) - Schema de base de datos

## 📋 Tabla de Contenidos

- [Arquitectura](#-arquitectura)
- [Tecnologías](#-tecnologías)
- [Estructura del Monorepo](#-estructura-del-monorepo)
- [Análisis de Dependencias con CodeGraph](#-análisis-de-dependencias-con-codegraph)
- [Prerequisitos](#-prerequisitos)
- [Instalación Rápida](#-instalación-rápida)
- [Verificación](#-verificación)
- [URLs de Acceso](#-urls-de-acceso)
- [Desarrollo](#-desarrollo)
- [Troubleshooting](#-troubleshooting)

---

## 🏗️ Arquitectura

### Topología General

```
┌────────────────────────────────────────────────────────────────────┐
│                     FRONTEND (8082-8087)                           │
│  app-login (8082) → seis-app (8083) → MFEs (8084-8087)            │
└─────────┬──────────────────────────────────────────────────────────┘
          │ HTTP Calls
          ▼
┌────────────────────────────────────────────────────────────────────┐
│            BFF / API Gateway (3002)                                │
│  (Backend for Frontend - Orquestación de servicios)                │
└─────────┬─────────────────────────┬────────────────────────────────┘
          │                         │
          ▼                         ▼
┌──────────────────────┐  ┌──────────────────────┐
│   ms-auth (3000)     │  │   ms-core (3001)     │
│  JWT / OAuth         │  │  Dominio (Facturas)  │
└──────────┬───────────┘  └──────────┬───────────┘
           │                         │
           │                         │
           └────────────┬────────────┘
                        │
                        ▼
            ┌─────────────────────────┐
            │  Infraestructura Shared │
            ├─────────────────────────┤
            │ • PostgreSQL (5432)     │
            │ • Redis (6379)          │
            │ • Vault (8200)          │
            │ • MinIO (9000)          │
            └─────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│              Storage Services (Async)                               │
│  ms-storage-orchestrator + worker-storage-processor                │
│  (OCR, indexación de documentos, procesamiento de facturas)        │
└────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│         Monitoring (Prometheus + Grafana)                           │
└────────────────────────────────────────────────────────────────────┘
```

### Servicios Backend

| Servicio | Puerto | Propósito |
|----------|--------|----------|
| **ms-auth** | 3000 | Autenticación JWT, gestión de usuarios |
| **ms-core** | 3001 | Dominio: facturas, usuarios, permisos, ofertas |
| **bff_seis_app** | 3002 | API Gateway / Backend for Frontend |
| **ms-storage-orchestrator** | Async | Orquestación de almacenamiento (MinIO) |
| **worker-storage-processor** | Async | Procesamiento de documentos (OCR, indexación) |

### Frontends (Micro Frontend Architecture)

| App | Puerto | Tipo | Propósito |
|-----|--------|------|----------|
| **app-login-erp-seis** | 8082 | SPA | Autenticación y login |
| **seis-app-frontend** (Portal) | 8083 | SPA | Portal principal |
| **mfe-gestion-usuario** | 8084 | MFE | Gestión de usuarios |
| **mfe-dashboard-facturas** | 8085 | MFE | Dashboard de facturas |
| **mfe-publicador-facturas** | 8086 | MFE | Publicación de facturas |
| **mfe-ofertador-facturas** | 8087 | MFE | Ofertas de financiamiento |

## 🛠️ Tecnologías

### Backend Microservicios
- **NestJS 10** - Framework de Node.js para microservicios
- **TypeScript** - Lenguaje tipado
- **PostgreSQL 15** - Base de datos principal
- **Redis 7** - Cache, sesiones, job queue
- **TypeORM** - ORM para TypeScript

### Frontend
- **Angular 18** - Framework SPA
- **Module Federation** - Micro Frontends
- **RxJS** - Programación reactiva
- **Bootstrap/Tailwind** - Estilos

### Infraestructura
- **Docker & Docker Compose** - Containerización
- **HashiCorp Vault** - Gestión de secretos
- **MinIO** - Object storage compatible S3
- **Kong** - API Gateway (producción)

### Monitoring & Observabilidad
- **Prometheus** - Recolección de métricas
- **Grafana** - Visualización
- **Loki** - Agregación de logs
- **Promtail** - Shipper de logs

### Análisis de Código
- **CodeGraph (@colbymchenry/codegraph)** - Indexación de dependencias del monorepo
- **Graphify** - Visualización de grafo de código

---

## 📂 Estructura del Monorepo

```
SEIS_APP/
├── .codegraph/                          # Índice consolidado (generado - .gitignore)
├── .github/
│   └── copilot-instructions.md         # Guía para desarrollo con AI
├── MONOREPO_ARCHITECTURE.md             # Documentación de arquitectura
├── README-comandos.md                   # Guía de comandos útiles
│
├── BACKEND/                             # 🔧 Microservicios NestJS
│   ├── ms-auth/                         # 🔐 Autenticación JWT/OAuth
│   │   ├── src/ (auth, guards, jwt)
│   │   ├── config/
│   │   ├── test/
│   │   ├── Dockerfile
│   │   ├── docker-compose.yml
│   │   ├── package.json
│   │   ├── README.md
│   │   ├── GUARDS-GUIDE.md
│   │   ├── JWT-DEBUG-GUIDE.md
│   │   └── .codegraph/ (indexado ✅)
│   │
│   ├── ms-core/                         # 📋 Dominio principal
│   │   ├── src/ (factura, usuario, permisos, ofertas)
│   │   ├── config/
│   │   ├── test/
│   │   ├── Dockerfile
│   │   ├── docker-compose.yml
│   │   ├── package.json
│   │   ├── README.md
│   │   ├── GUARDS-GUIDE.md
│   │   ├── DOCKER-GUIDE.md
│   │   ├── DOCKER-SETUP-GUIDE.md
│   │   └── .codegraph/ (indexado ✅)
│   │
│   ├── ms-bodegaje/                     # 📦 Gestión de almacén (Java/Spring)
│   │   ├── src/
│   │   ├── pom.xml
│   │   ├── Dockerfile
│   │   ├── docker-compose.yml
│   │   ├── mvnw / mvnw.cmd
│   │   └── ms-bodegaje.md
│   │
│   ├── bff_seis_app/                    # 🌉 Backend for Frontend (API Gateway)
│   │   ├── src/ (auth, core, health)
│   │   ├── configs/
│   │   ├── test/
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   ├── README.md
│   │   └── .codegraph/ (indexado ✅)
│   │
│   └── storage/                         # 💾 Gestión de archivos
│       ├── ms-storage-orchestrator/     # Orquestación de MinIO
│       └── worker-storage-processor/    # Procesamiento async (OCR, indexación)
│
├── DB/db_seis_erp/                      # 🗄️ Base de Datos PostgreSQL
│   ├── init-db/
│   │   ├── 01_init_core.sql            # Core: usuarios, organizaciones, contactos
│   │   ├── 08_init_invoice.sql         # Dominio: facturas, ofertas, historial
│   │   └── 09_init_permisos.sql        # ABAC: acceso genérico y roles
│   ├── diagramas/                      # ER diagrams
│   ├── redis/                          # Configuración de Redis
│   ├── docker-compose.yml
│   ├── docker-compose.dev.yml
│   ├── pg_hba.conf
│   ├── start.sh
│   ├── test-connection.sh
│   └── README.md
│
├── FRONTEND/                            # 🎨 Aplicaciones Angular
│   ├── app-login-erp-seis/              # SPA de Login (puerto 8082)
│   │   ├── src/
│   │   │   ├── app/
│   │   │   ├── assets/
│   │   │   ├── environments/
│   │   │   └── styles/
│   │   ├── angular.json
│   │   ├── package.json
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   ├── proxy.conf.docker.json
│   │   ├── docker-compose.yml
│   │   └── README.md
│   │
│   ├── seis-app-frontend/               # Portal + Micro Frontends
│   │   ├── projects/
│   │   │   ├── portal/                 # Portal principal (8083)
│   │   │   ├── mfe-gestion-usuario/    # MFE (8084)
│   │   │   ├── mfe-dashboard-facturas/ # MFE (8085)
│   │   │   ├── mfe-publicador-facturas/# MFE (8086)
│   │   │   └── mfe-ofertador-facturas/ # MFE (8087)
│   │   ├── angular.json
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── README.md
│   │
│   ├── GUIA-NAVEGACION-MFE.md           # Arquitectura de Micro Frontends
│   ├── README-MFE-ARQUITECTURA.md       # Documentación MFE
│   └── readme.md
│
├── monitoring/                          # 📊 Observabilidad
│   ├── prometheus/
│   │   └── prometheus.yml
│   ├── grafana/
│   │   ├── dashboards/
│   │   └── provisioning/
│   ├── loki/
│   │   └── loki-config.yml
│   ├── promtail/
│   │   └── promtail-config.yml
│   └── monitoring.md
│
├── scripts/                             # 🛠️ Utilidades y automatización
│   ├── deploy-full-stack.sh
│   ├── cleanup.sh
│   ├── force-cleanup.sh
│   ├── init-vault.sh
│   ├── backup-vault.sh
│   ├── restore-vault.sh
│   ├── kong-config.sh
│   ├── setup-monitoring.sh
│   ├── validate-minio-setup.sh
│   └── monitoring/
│
├── vault/                               # 🔐 HashiCorp Vault Config
│   ├── config/
│   ├── policies/
│   ├── respaldo/
│   └── README.md
│
├── redis/                               # ⚡ Redis Config
│   └── redis.conf/
│
├── docker-compose-app-services.yml     # 🐳 Backend services + BFF
├── docker-compose-app-frontend.yml     # 🐳 Frontend applications
├── docker-compose-app-imfra.yml        # 🐳 Infraestructura (postgres, redis, vault, minio)
├── docker-clean-restart.sh             # Limpiar y reiniciar stack
├── kong-konga-init.sh                  # Configuración de Kong (API Gateway)
├── Makefile                             # 📝 Comandos comunes
├── minio-config.md                      # Documentación de MinIO
├── secrets-vault.json                   # Template de secretos (TEMPLATE)
└── snapshot_3.json                      # Snapshot de configuración
```

---

## 🔍 Análisis de Dependencias con CodeGraph

SEIS App utiliza **CodeGraph** para mapear dependencias en el monorepo. Esto permite:

✅ **Detectar impacto de cambios** - "¿Quién depende de esta función?"  
✅ **Evitar ciclos** - Detectar dependencias circulares  
✅ **Refactoring seguro** - Mover lógica sin romper nada  
✅ **Documentación viva** - El grafo se actualiza automáticamente  

### Estado de Indexación

| Módulo | Estado | Estado Análisis |
|--------|--------|-----------------|
| ms-auth | ✅ Indexado | Servicios NestJS, Guards, JWT |
| ms-core | ✅ Indexado | Dominio (Factura, Usuario, Permisos) |
| bff_seis_app | ✅ Indexado | Orquestación de servicios |
| ms-storage-orchestrator | ✅ Indexado | Orquestación de archivos |
| worker-storage-processor | ✅ Indexado | Procesamiento async |
| **Monorepo (raíz)** | ✅ Indexado | `.codegraph/codegraph.json` |

### Comandos CodeGraph Frecuentes

```bash
# 🔍 Buscar un símbolo en todo el monorepo
npx @colbymchenry/codegraph query "FacturaService" -j

# 📊 Ver qué se afecta si cambias un archivo
npx @colbymchenry/codegraph affected BACKEND/ms-auth/src/auth.service.ts

# 📋 Listar archivos indexados
npx @colbymchenry/codegraph files -j

# 🌐 Abrir UI interactiva (RECOMENDADO)
npx @colbymchenry/codegraph serve
# → Abre http://localhost:3333

# 📚 Ver contexto de un archivo
npx @colbymchenry/codegraph context BACKEND/ms-core/src/factura/factura.service.ts
```

**Más en:** [.github/copilot-instructions.md](.github/copilot-instructions.md)

---

## 📦 Prerequisitos

### Software Requerido

- **Docker** >= 20.10
- **Docker Compose** >= 2.0
- **Git**
- **Node.js** >= 18 (para desarrollo local)
- **Make** (opcional, pero recomendado)

### Recursos del Sistema

- **RAM**: 8GB mínimo, 16GB recomendado
- **CPU**: 4 cores mínimo
- **Disco**: 20GB espacio libre
- **Puertos libres**: 3000-3002 (backend), 5432 (postgres), 6379 (redis), 8082-8087 (frontends), 8200 (vault), 9000 (minio), 9090 (prometheus), 3030 (grafana)

### Verificar Prerequisitos

```bash
# Verificar Docker
docker --version
# Docker version 20.10.x o superior

# Verificar Docker Compose
docker-compose --version
# Docker Compose version 2.x.x o superior

# Verificar Node.js (para desarrollo local)
node --version
# v18+ recomendado

# Verificar puertos disponibles
# Linux/Mac
lsof -i :3000,3001,3002,5432,6379,8082

# Windows (PowerShell)
netstat -ano | findstr "3000 3001 3002 5432 6379"
```

---

## 🚀 Instalación Rápida

### Opción 1: Con Make (Recomendado)

```bash
# 1. Clonar repositorio
git clone https://github.com/tu-org/SEIS_APP.git
cd SEIS_APP

# 2. Levantar infraestructura
make dev-infra-up

# 3. Levantar servicios backend
make dev-backend-up

# 4. Levantar frontends
make dev-frontend-up

# 5. Verificar estado
make status

# 6. Ver URLs de acceso
make urls
```

### Opción 2: Con Docker Compose Directo

```bash
# 1. Clonar y entrar
git clone https://github.com/tu-org/SEIS_APP.git
cd SEIS_APP

# 2. Levantar infraestructura (postgres, redis, vault, minio)
docker-compose -f docker-compose-app-imfra.yml up -d

# 3. Esperar 30 segundos a que estabilice
sleep 30

# 4. Levantar servicios backend
docker-compose -f docker-compose-app-services.yml up -d

# 5. Levantar frontends
docker-compose -f docker-compose-app-frontend.yml up -d

# 6. Verificar
docker-compose -f docker-compose-app-services.yml ps
```

### Opción 3: Desarrollo Local (sin Docker)

```bash
# Backend - ms-auth
cd BACKEND/ms-auth
npm install
npm run start:dev

# En otra terminal - ms-core
cd BACKEND/ms-core
npm install
npm run start:dev

# En otra terminal - BFF
cd BACKEND/bff_seis_app
npm install
npm run start:dev

# En otra terminal - Frontend
cd FRONTEND/app-login-erp-seis
npm install
npm start
```
```bash
# 1. Clonar repositorio
git clone <tu-repositorio>
cd erp-system

# 2. Dar permisos a los scripts
chmod +x scripts/*.sh

# 3. Desplegar stack completo
bash scripts/deploy-full-stack.sh

# 4. Verificar
bash scripts/verify-all.sh
```

---

## ✅ Verificación

### Verificar Servicios Backend

```bash
# Ver status de todos los contenedores
docker-compose -f docker-compose-app-services.yml ps
docker-compose -f docker-compose-app-imfra.yml ps

# Health check de ms-auth
curl http://localhost:3000/health

# Health check de ms-core
curl http://localhost:3001/health

# Health check de BFF
curl http://localhost:3002/health

# Verificar PostgreSQL
docker-compose -f docker-compose-app-imfra.yml exec postgres pg_isready -U postgres

# Verificar Redis
docker-compose -f docker-compose-app-imfra.yml exec redis redis-cli ping
```

### Verificar Frontends

```bash
# app-login
curl http://localhost:8082/

# seis-app-frontend (portal)
curl http://localhost:8083/

# MFEs
curl http://localhost:8084/ # gestion-usuario
curl http://localhost:8085/ # dashboard-facturas
```

---

## 📍 URLs de Acceso

### Aplicaciones

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **Login** | http://localhost:8082 | User/Pass (ver .env) |
| **Portal SEIS** | http://localhost:8083 | Mismo usuario |
| **Gestión Usuario** | http://localhost:8084 | MFE integrado |
| **Dashboard Facturas** | http://localhost:8085 | MFE integrado |
| **Publicador Facturas** | http://localhost:8086 | MFE integrado |
| **Ofertador Facturas** | http://localhost:8087 | MFE integrado |

### APIs Backend

| Servicio | URL | Docs |
|----------|-----|------|
| **ms-auth** | http://localhost:3000 | /api/docs |
| **ms-core** | http://localhost:3001 | /api/docs |
| **BFF** | http://localhost:3002 | /api/docs |

### Infraestructura

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **Prometheus** | http://localhost:9090 | N/A |
| **Grafana** | http://localhost:3030 | admin/admin (cambiar) |
| **Vault** | http://localhost:8200 | Token en .vault-tokens |
| **MinIO** | http://localhost:9000 | minioadmin/minioadmin |
| **PostgreSQL** | localhost:5432 | postgres/password |
| **Redis** | localhost:6379 | N/A |

---

## 🧪 Desarrollo

### Reindexar CodeGraph después de cambios

```bash
# Desde la raíz del monorepo
npx @colbymchenry/codegraph init -i

# O en un proyecto específico
cd BACKEND/ms-core
npx @colbymchenry/codegraph init -i
```

### Ver UI Interactiva del Grafo

```bash
npx @colbymchenry/codegraph serve
# Abre http://localhost:3333
```

### Buscar Impacto de Cambios

```bash
# ¿Quién llama a esta función?
npx @colbymchenry/codegraph query "nombreFuncion" -j

# ¿Qué se afecta si cambio este archivo?
npx @colbymchenry/codegraph affected BACKEND/ms-core/src/factura/factura.service.ts

# ¿Qué archivos tienen esta clase?
npx @colbymchenry/codegraph query "FacturaService" -k class
```

### Testing

```bash
# Backend - ms-auth
cd BACKEND/ms-auth
npm run test

# Backend - ms-core
cd BACKEND/ms-core
npm run test

# Frontend
cd FRONTEND/app-login-erp-seis
npm run test
```

### Logs en Desarrollo

```bash
# Ver logs de todos los servicios
docker-compose -f docker-compose-app-services.yml logs -f

# Ver logs de un servicio específico
docker-compose -f docker-compose-app-services.yml logs -f ms_core

# Ver logs de infraestructura
docker-compose -f docker-compose-app-imfra.yml logs -f postgres
```

---

## 🐛 Troubleshooting

### Puerto Ya en Uso

```bash
# Encontrar qué proceso ocupa el puerto
# Linux/Mac
lsof -i :3000

# Windows (PowerShell)
netstat -ano | findstr ":3000"
```

### Base de Datos No Conecta

```bash
# Verificar que postgres esté corriendo
docker-compose -f docker-compose-app-imfra.yml ps postgres

# Ver logs de postgres
docker-compose -f docker-compose-app-imfra.yml logs postgres

# Reiniciar
docker-compose -f docker-compose-app-imfra.yml restart postgres
```

### Redis Desincronizado

```bash
# Limpiar cache de Redis
docker-compose -f docker-compose-app-imfra.yml exec redis redis-cli FLUSHALL

# Ver keys
docker-compose -f docker-compose-app-imfra.yml exec redis redis-cli KEYS '*'
```

### Vault Sin Acceso

```bash
# Ver si está inicializado
curl http://localhost:8200/v1/sys/health

# Reiniciar y re-inicializar
docker-compose -f docker-compose-app-imfra.yml restart vault
bash scripts/init-vault.sh
```

### Limpiar Todo y Empezar de Nuevo

```bash
# Detener y remover contenedores
docker-compose -f docker-compose-app-imfra.yml down -v
docker-compose -f docker-compose-app-services.yml down -v
docker-compose -f docker-compose-app-frontend.yml down -v

# Remover volúmenes (cuidado: pérdida de datos)
docker volume prune -f

# Reiniciar
make dev-infra-up
```

---

## 📚 Referencias

- **Arquitectura:** [MONOREPO_ARCHITECTURE.md](MONOREPO_ARCHITECTURE.md)
- **Directrices de Desarrollo:** [.github/copilot-instructions.md](.github/copilot-instructions.md)
- **Base de Datos:** [DB/db_seis_erp/README.md](DB/db_seis_erp/README.md)
- **Backend ms-auth:** [BACKEND/ms-auth/README.md](BACKEND/ms-auth/README.md)
- **Backend ms-core:** [BACKEND/ms-core/README.md](BACKEND/ms-core/README.md)
- **Frontend:** [FRONTEND/README.md](FRONTEND/readme.md)

---

## 📝 Licencia

Este proyecto es parte de SEIS App. Todos los derechos reservados.
docker restart seis_erp_postgres
```

### Script de Limpieza Total

```bash
# Crear script de limpieza
cat > scripts/force-cleanup.sh << 'EOF'
#!/bin/bash
set -e
echo "🧹 Limpieza total..."
docker-compose -f docker-compose-erp.yml down -v
docker ps -a | grep -E "vault|kong|seis|grafana|prometheus" | awk '{print $1}' | xargs -r docker rm -f
docker volume prune -f
docker network rm erp_network 2>/dev/null || true
docker network create erp_network
echo "✅ Limpieza completada"
EOF

chmod +x scripts/force-cleanup.sh

# Ejecutar
bash scripts/force-cleanup.sh
```

---

## 💻 Desarrollo

### Agregar Nuevo Servicio

1. Crear servicio en `docker-compose-erp.yml`
2. Agregar configuración en Vault: `bash scripts/init-vault.sh`
3. Configurar Kong si es necesario
4. Agregar métricas a Prometheus
5. Crear dashboard en Grafana

### Hot Reload en Desarrollo

Los servicios NestJS tienen hot reload habilitado:

```yaml
volumes:
  - ./BFF+AUTH/ms-auth:/app
  - /app/node_modules
```

Cualquier cambio en el código se reflejará automáticamente.

### Agregar Métricas Personalizadas

En NestJS:

```typescript
import { Injectable } from '@nestjs/common';
import { InjectMetric } from '@willsoto/nestjs-prometheus';
import { Counter, Histogram } from 'prom-client';

@Injectable()
export class MyService {
  constructor(
    @InjectMetric('http_requests_total') 
    private counter: Counter,
    
    @InjectMetric('http_request_duration_seconds') 
    private histogram: Histogram,
  ) {}

  async doSomething() {
    this.counter.inc();
    const end = this.histogram.startTimer();
    
    // Tu lógica aquí
    
    end();
  }
}
```

### Agregar Secreto en Vault

```bash
# Opción 1: CLI
docker exec vault_server vault kv put secret/mi-servicio \
  api_key=valor \
  secret=otro-valor

# Opción 2: API
curl -X POST http://localhost:8200/v1/secret/data/mi-servicio \
  -H "X-Vault-Token: myroot" \
  -d '{"data": {"api_key": "valor"}}'

# Opción 3: Agregar al script init-vault.sh
```

---

## 💾 Backup y Restore

### Backup de Vault

```bash
# Crear backup automático
bash scripts/backup-vault.sh

# Ubicación: backups/vault/vault_backup_YYYYMMDD_HHMMSS.json.gz
```

### Restore de Vault

```bash
# Restaurar interactivamente
bash scripts/restore-vault.sh

# Te mostrará lista de backups disponibles
```

### Backup de PostgreSQL

```bash
# Backup completo
make db-backup

# O manualmente:
docker exec seis_erp_postgres pg_dump -U desarrollo core_erp | \
  gzip > backups/database/db_backup_$(date +%Y%m%d_%H%M%S).sql.gz

# Backup de una tabla específica
docker exec seis_erp_postgres pg_dump -U desarrollo -t usuarios core_erp | \
  gzip > backups/database/usuarios_backup.sql.gz
```

### Restore de PostgreSQL

```bash
# Restaurar desde backup
gunzip < backups/database/db_backup_YYYYMMDD_HHMMSS.sql.gz | \
  docker exec -i seis_erp_postgres psql -U desarrollo core_erp
```

### Backup Completo del Sistema

```bash
# Script de backup completo
cat > scripts/backup-all.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="backups/full_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "🔐 Backup de Vault..."
bash scripts/backup-vault.sh
cp backups/vault/vault_backup_*.json.gz "$BACKUP_DIR/" 2>/dev/null || true

echo "🗄️ Backup de PostgreSQL..."
docker exec seis_erp_postgres pg_dump -U desarrollo core_erp | \
  gzip > "$BACKUP_DIR/postgres.sql.gz"

echo "📊 Backup de Grafana..."
docker exec grafana tar czf - /var/lib/grafana > "$BACKUP_DIR/grafana.tar.gz"

echo "✅ Backup completo en: $BACKUP_DIR"
EOF

chmod +x scripts/backup-all.sh
bash scripts/backup-all.sh
```

---

## 🧹 Limpieza

### Detener Servicios

```bash
# Con Make
make down

# Manual
docker-compose -f docker-compose-erp.yml down
```

### Limpiar Volúmenes (¡Elimina datos!)

```bash
# Con confirmación
make clean

# Manual
docker-compose -f docker-compose-erp.yml down -v
```

### Limpieza Total

```bash
# Detener y eliminar todo
docker-compose -f docker-compose-erp.yml down -v

# Eliminar contenedores huérfanos
docker ps -a | grep -E "vault|kong|seis|grafana" | awk '{print $1}' | xargs -r docker rm -f

# Eliminar volúmenes
docker volume prune -f

# Eliminar imágenes no usadas
docker image prune -a -f

# Eliminar red
docker network rm erp_network
```

### Limpiar Solo un Servicio

```bash
# Detener servicio
docker-compose -f docker-compose-erp.yml stop vault

# Eliminar contenedor
docker-compose -f docker-compose-erp.yml rm vault

# Eliminar volumen
docker volume rm vault_data vault_logs

# Reconstruir y levantar
docker-compose -f docker-compose-erp.yml up -d --build vault
```

---

## 👥 Equipo

- **DevOps**: Configuración de infraestructura y monitoring
- **Backend**: Microservicios NestJS
- **Frontend**: Aplicación Angular

---

## 📞 Soporte

¿Necesitas ayuda?

- 📧 Email: parra.sebastian91@gmail.com
- 💬 Issues: [GitHub Issues](https://github.com/parraSebastian91/erp-system/issues)


Made with ❤️ by Sebita