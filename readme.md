# 🏢 ERP System - Full Stack con Microservicios

Sistema ERP empresarial completo construido con arquitectura de microservicios, incluyendo gestión de secretos con HashiCorp Vault y stack completo de monitoring con Prometheus y Grafana.

## 📋 Tabla de Contenidos

- [Arquitectura](#-arquitectura)
- [Tecnologías](#-tecnologías)
- [Prerequisitos](#-prerequisitos)
- [Instalación Rápida](#-instalación-rápida)
- [Instalación Detallada](#-instalación-detallada)
- [Verificación](#-verificación)
- [URLs de Acceso](#-urls-de-acceso)
- [Configuración de Vault](#-configuración-de-vault)
- [Monitoring con Grafana](#-monitoring-con-grafana)
- [Comandos Útiles](#-comandos-útiles)
- [Troubleshooting](#-troubleshooting)
- [Desarrollo](#-desarrollo)
- [Backup y Restore](#-backup-y-restore)
- [Limpieza](#-limpieza)

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                    Cliente (Browser)                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Kong API Gateway (:8000)                        │
├─────────────────────────────────────────────────────────────┤
│  /              →  app-login (Angular + Nginx)              │
│  /api/auth      →  auth-service (NestJS :3000)              │
│  /api/core      →  core-service (NestJS :3001)              │
└──────────┬──────────────────────┬───────────────────────────┘
           │                      │
           ▼                      ▼
┌──────────────────┐   ┌──────────────────┐
│  PostgreSQL      │   │  Redis           │
│  :5432           │   │  :6379           │
└──────────────────┘   └──────────────────┘
           │                      │
           └──────────┬───────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│          Vault - Secrets Management (:8200)                  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│        Monitoring Stack (Prometheus + Grafana)               │
│                                                              │
│  Prometheus (:9090) ← Node Exporter (:9100)                 │
│        ↓             ← Postgres Exporter (:9187)            │
│  Grafana (:3030)     ← Redis Exporter (:9121)               │
└─────────────────────────────────────────────────────────────┘
```

## 🛠️ Tecnologías

### Backend
- **NestJS** - Framework de Node.js para microservicios
- **PostgreSQL 15** - Base de datos principal
- **Redis 7** - Cache y sesiones
- **TypeORM** - ORM para TypeScript

### Frontend
- **Angular 18** - Framework de frontend
- **Nginx** - Servidor web para producción

### Infrastructure
- **Kong 3.5** - API Gateway
- **Konga** - UI de administración para Kong
- **HashiCorp Vault** - Gestión de secretos
- **Docker & Docker Compose** - Containerización

### Monitoring
- **Prometheus** - Recolección de métricas
- **Grafana** - Visualización de métricas
- **Node Exporter** - Métricas del sistema
- **PostgreSQL Exporter** - Métricas de base de datos
- **Redis Exporter** - Métricas de cache

---

## 📦 Prerequisitos

### Software Requerido

- **Docker** >= 20.10
- **Docker Compose** >= 2.0
- **Git**
- **Bash** (Linux/Mac) o **Git Bash** (Windows)
- **Make** (opcional, pero recomendado)

### Recursos del Sistema

- **RAM**: 8GB mínimo, 16GB recomendado
- **CPU**: 4 cores mínimo
- **Disco**: 20GB espacio libre
- **Puertos libres**: 3000, 3001, 3030, 5432, 6379, 8000, 8001, 8200, 9090, 9100, 9121, 9187

### Verificar Prerequisitos

```bash
# Verificar Docker
docker --version
# Docker version 20.10.x o superior

# Verificar Docker Compose
docker-compose --version
# Docker Compose version 2.x.x o superior

# Verificar que Docker está corriendo
docker ps

# Verificar puertos disponibles
lsof -i :8000,8001,8200,3030,9090,5432,6379,3000,3001
# No debería devolver nada
```

---

## 🚀 Instalación Rápida

### Opción 1: Con Make (Recomendado)

```bash
# 1. Clonar repositorio
git clone <tu-repositorio>
cd erp-system

# 2. Levantar todo el stack
make up

# 3. Esperar a que termine (5-10 minutos)

# 4. Verificar estado
make status
make health

# 5. Ver URLs de acceso
make urls
```

### Opción 2: Con Scripts

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

## 📖 Instalación Detallada

### Paso 1: Preparación del Entorno

```bash
# Clonar repositorio
git clone <tu-repositorio>
cd erp-system

# Crear archivo .env (opcional, usa valores por defecto)
cp .env.example .env

# Editar configuración si es necesario
nano .env
```

### Paso 2: Crear Red de Docker

```bash
# Crear red compartida
docker network create erp_network

# Verificar
docker network ls | grep erp_network
```

### Paso 3: Crear Estructura de Directorios

```bash
# Crear directorios necesarios
mkdir -p monitoring/prometheus
mkdir -p monitoring/grafana/provisioning/datasources
mkdir -p monitoring/grafana/provisioning/dashboards
mkdir -p monitoring/grafana/provisioning/plugins
mkdir -p monitoring/grafana/provisioning/notifiers
mkdir -p monitoring/grafana/provisioning/alerting
mkdir -p monitoring/grafana/dashboards
mkdir -p vault/config
mkdir -p vault/policies
mkdir -p scripts
mkdir -p backups/vault
mkdir -p backups/database
```

### Paso 4: Levantar Servicios Base

```bash
# PostgreSQL y Redis
docker-compose -f docker-compose-erp.yml up -d postgres redis

# Esperar a que estén saludables (~15 segundos)
docker-compose -f docker-compose-erp.yml ps

# Verificar logs
docker-compose -f docker-compose-erp.yml logs postgres redis
```

### Paso 5: Levantar y Configurar Vault

```bash
# Levantar Vault
docker-compose -f docker-compose-erp.yml up -d vault

# Esperar 10 segundos
sleep 10

# Inicializar Vault con secretos
bash scripts/init-vault.sh

# Verificar
curl http://localhost:8200/v1/sys/health
```

**📝 Nota**: El script `init-vault.sh` creará:
- Secretos para todos los servicios
- Políticas de acceso
- Tokens por servicio
- Archivo `.vault-tokens` con los tokens generados

### Paso 6: Levantar Servicios de Aplicación

```bash
# Auth y Core services
docker-compose -f docker-compose-erp.yml up -d auth-service ms_core

# Verificar logs
docker-compose -f docker-compose-erp.yml logs -f auth-service ms_core
```

### Paso 7: Levantar Kong API Gateway

```bash
# Kong y sus dependencias
docker-compose -f docker-compose-erp.yml up -d kong-db kong-migration kong

# Esperar 15 segundos
sleep 15

# Configurar Kong
bash setup-kong-frontend.sh

# Verificar
curl http://localhost:8001/
```

### Paso 8: Levantar Frontend

```bash
# App Angular
docker-compose -f docker-compose-erp.yml up -d --build app-login

# Verificar
curl -I http://localhost:8000/
```

### Paso 9: Levantar Stack de Monitoring

```bash
# Exporters
docker-compose -f docker-compose-erp.yml up -d \
  node-exporter \
  postgres-exporter \
  redis-exporter

# Prometheus
docker-compose -f docker-compose-erp.yml up -d prometheus

# Grafana
docker-compose -f docker-compose-erp.yml up -d grafana

# Verificar
curl http://localhost:9090/-/healthy
curl http://localhost:3030/api/health
```

### Paso 10: Herramientas de Administración (Opcional)

```bash
# Konga, PgAdmin, Portainer
docker-compose -f docker-compose-erp.yml --profile admin-tools up -d

# Acceder a:
# - Konga: http://localhost:1337
# - PgAdmin: http://localhost:5050
# - Portainer: http://localhost:9000
```

---

## ✅ Verificación

### Script de Verificación Automática

```bash
# Verificar todos los servicios
bash scripts/verify-all.sh
```

### Verificación Manual

```bash
# Ver estado de contenedores
docker-compose -f docker-compose-erp.yml ps

# Deberías ver todos como "Up" y con (healthy) los que tienen healthcheck

# Verificar logs
docker-compose -f docker-compose-erp.yml logs --tail=50

# Probar endpoints
curl http://localhost:8000/                    # Frontend (200)
curl http://localhost:8200/v1/sys/health       # Vault (200)
curl http://localhost:3030/api/health          # Grafana (200)
curl http://localhost:9090/-/healthy           # Prometheus (200)
curl http://localhost:3000/health              # Auth Service (200)
curl http://localhost:3001/health              # Core Service (200)
curl http://localhost:8001/                    # Kong Admin (200)
```

### Verificar Health Checks

```bash
# Ver solo contenedores saludables
docker ps --filter "health=healthy"

# Debería mostrar:
# - postgres
# - redis
# - vault_server
# - kong_gateway
# - ms_auth_app
# - ms_core
# - grafana
# - prometheus
```

---

## 🌐 URLs de Acceso

### Aplicación Principal

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **Frontend** | http://localhost:8000 | - |
| **API (via Kong)** | http://localhost:8000/api/* | - |

### Seguridad

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **Vault UI** | http://localhost:8200/ui | Token: `myroot` |

### Monitoring

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **Grafana** | http://localhost:3030 | admin / admin123 |
| **Prometheus** | http://localhost:9090 | - |

### API Gateway

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **Kong Admin** | http://localhost:8001 | - |
| **Konga UI** | http://localhost:1337 | (Configurar en primer acceso) |

### Herramientas de Admin

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **PgAdmin** | http://localhost:5050 | admin@erp.local / admin123 |
| **Portainer** | http://localhost:9000 | (Configurar en primer acceso) |

### Servicios Directos (Solo para desarrollo)

| Servicio | URL | Descripción |
|----------|-----|-------------|
| **Auth Service** | http://localhost:3000/health | Health check |
| **Core Service** | http://localhost:3001/health | Health check |
| **Node Exporter** | http://localhost:9100/metrics | Métricas del sistema |
| **Postgres Exporter** | http://localhost:9187/metrics | Métricas de PostgreSQL |
| **Redis Exporter** | http://localhost:9121/metrics | Métricas de Redis |

---

## 🔐 Configuración de Vault

### Acceder a Vault UI

```bash
# Abrir en navegador
open http://localhost:8200/ui

# Token de acceso (desarrollo)
Token: myroot
```

### Ver Secretos Configurados

```bash
# Listar todos los secretos
docker exec vault_server vault kv list secret/

# Ver secreto específico
docker exec vault_server vault kv get secret/database
docker exec vault_server vault kv get secret/auth-service
```

### Tokens de Servicios

Los tokens generados están en `.vault-tokens`:

```bash
# Ver tokens
cat .vault-tokens

# Contenido ejemplo:
# VAULT_ROOT_TOKEN=myroot
# AUTH_SERVICE_VAULT_TOKEN=hvs.CAESIxxx...
# CORE_SERVICE_VAULT_TOKEN=hvs.CAESIyyy...
```

### Crear Nuevo Secreto

```bash
# Desde CLI
docker exec vault_server vault kv put secret/mi-servicio \
  api_key=mi-clave-secreta \
  password=mi-password

# Desde API
curl -X POST http://localhost:8200/v1/secret/data/mi-servicio \
  -H "X-Vault-Token: myroot" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "api_key": "mi-clave-secreta",
      "password": "mi-password"
    }
  }'
```

### Backup de Vault

```bash
# Crear backup
bash scripts/backup-vault.sh

# Los backups se guardan en: backups/vault/
# Formato: vault_backup_YYYYMMDD_HHMMSS.json.gz
```

### Restore de Vault

```bash
# Restaurar desde backup
bash scripts/restore-vault.sh

# Te mostrará una lista de backups disponibles
# Selecciona el número correspondiente
```

---

## 📊 Monitoring con Grafana

### Acceder a Grafana

```bash
# Abrir en navegador
open http://localhost:3030

# Credenciales
Usuario: admin
Password: admin123
```

### Verificar Datasource

1. Ve a **Configuration** (⚙️) → **Data Sources**
2. Deberías ver **Prometheus** configurado
3. Click en **Prometheus** → **Save & Test**
4. Debería mostrar: ✅ "Data source is working"

### Importar Dashboards Pre-configurados

En Grafana, ve a **+ → Import** y usa estos IDs:

```bash
# Dashboard de Node Exporter (métricas del sistema)
ID: 1860
Nombre: Node Exporter Full

# Dashboard de PostgreSQL
ID: 9628
Nombre: PostgreSQL Database

# Dashboard de Redis
ID: 11835
Nombre: Redis Dashboard

# Dashboard de Docker
ID: 893
Nombre: Docker and System Monitoring

# Dashboard de Kong
ID: 7424
Nombre: Kong Official Dashboard
```

### Crear Dashboard Personalizado

1. Click en **+ → Dashboard**
2. **Add panel**
3. En la query de Prometheus:

```promql
# CPU usage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memoria usada
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Requests en Kong
rate(kong_http_requests_total[5m])

# Conexiones a PostgreSQL
pg_stat_database_numbackends{datname="core_erp"}

# Comandos en Redis
rate(redis_commands_processed_total[1m])
```

### Queries Útiles de Prometheus

```promql
# Ver todos los servicios activos
up

# CPU por contenedor
rate(container_cpu_usage_seconds_total[5m])

# Memoria por contenedor
container_memory_usage_bytes

# Disco disponible
node_filesystem_avail_bytes

# Latencia de Kong
histogram_quantile(0.95, kong_latency_bucket)
```

---

## 🔧 Comandos Útiles

### Con Make

```bash
make help              # Ver todos los comandos disponibles
make up                # Levantar todo el stack
make down              # Detener todo
make restart           # Reiniciar servicios
make status            # Ver estado de servicios
make health            # Health check de todos los servicios
make logs              # Ver logs en tiempo real
make logs-app          # Logs solo de aplicación
make logs-vault        # Logs de Vault
make logs-monitoring   # Logs de monitoring
make build             # Construir imágenes
make rebuild           # Reconstruir sin cache
make vault-init        # Inicializar Vault
make vault-ui          # Abrir Vault UI
make grafana           # Abrir Grafana
make prometheus        # Abrir Prometheus
make backup-vault      # Backup de Vault
make restore-vault     # Restore de Vault
make db-shell          # Conectar a PostgreSQL
make db-backup         # Backup de PostgreSQL
make redis-cli         # Conectar a Redis CLI
make clean             # Limpiar todo (¡cuidado!)
make urls              # Mostrar todas las URLs
```

### Docker Compose Manual

```bash
# Levantar servicios
docker-compose -f docker-compose-erp.yml up -d

# Levantar servicios específicos
docker-compose -f docker-compose-erp.yml up -d postgres redis vault

# Detener servicios
docker-compose -f docker-compose-erp.yml down

# Ver logs
docker-compose -f docker-compose-erp.yml logs -f

# Ver logs de un servicio
docker-compose -f docker-compose-erp.yml logs -f auth-service

# Ver estado
docker-compose -f docker-compose-erp.yml ps

# Reiniciar servicio
docker-compose -f docker-compose-erp.yml restart auth-service

# Reconstruir imagen
docker-compose -f docker-compose-erp.yml build auth-service

# Detener y eliminar volúmenes (¡cuidado!)
docker-compose -f docker-compose-erp.yml down -v
```

### Docker Directo

```bash
# Ver todos los contenedores
docker ps

# Ver logs de un contenedor
docker logs -f vault_server
docker logs --tail 100 grafana

# Ejecutar comando en contenedor
docker exec -it seis_erp_postgres psql -U desarrollo -d core_erp
docker exec -it seis_erp_redis redis-cli
docker exec -it vault_server sh

# Ver uso de recursos
docker stats

# Inspeccionar red
docker network inspect erp_network

# Ver volúmenes
docker volume ls
```

---

## 🐛 Troubleshooting

### Puerto Ya en Uso

```bash
# Ver qué está usando el puerto
lsof -i :8200

# Matar proceso
kill -9 <PID>

# O usar sudo
sudo kill -9 <PID>
```

### Servicio No Inicia

```bash
# Ver logs del servicio
docker logs <nombre-contenedor>

# Ejemplos:
docker logs vault_server
docker logs grafana
docker logs kong_gateway

# Reiniciar servicio
docker restart <nombre-contenedor>
```

### Error "Address Already in Use"

```bash
# Limpiar contenedores anteriores
docker-compose -f docker-compose-erp.yml down

# Eliminar contenedores huérfanos
docker ps -a | grep -E "vault|kong|grafana" | awk '{print $1}' | xargs docker rm -f

# Limpiar volúmenes
docker volume prune -f

# Intentar nuevamente
bash scripts/deploy-full-stack.sh
```

### Vault No Se Conecta

```bash
# Verificar que Vault esté corriendo
docker ps | grep vault

# Ver logs
docker logs vault_server

# Verificar salud
curl http://localhost:8200/v1/sys/health

# Reiniciar Vault
docker restart vault_server

# Reinicializar
bash scripts/init-vault.sh
```

### Grafana No Muestra Datos

```bash
# Verificar que Prometheus esté corriendo
curl http://localhost:9090/-/healthy

# Verificar datasource en Grafana
curl -u admin:admin123 http://localhost:3030/api/datasources

# Ver logs de Grafana
docker logs grafana | grep -i "datasource\|prometheus"

# Reiniciar Grafana
docker restart grafana
```

### Kong Devuelve 502

```bash
# Verificar que los servicios backend estén up
docker ps | grep -E "auth-service|ms_core|app-login"

# Ver configuración de Kong
curl http://localhost:8001/services
curl http://localhost:8001/routes

# Reconfigurar Kong
bash setup-kong-frontend.sh

# Ver logs
docker logs kong_gateway
```

### Base de Datos No Conecta

```bash
# Verificar PostgreSQL
docker exec seis_erp_postgres pg_isready

# Conectar manualmente
docker exec -it seis_erp_postgres psql -U desarrollo -d core_erp

# Ver logs
docker logs seis_erp_postgres

# Reiniciar
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

## 📚 Estructura del Proyecto

```
erp-system/
├── BFF+AUTH/
│   └── ms-auth/              # Servicio de autenticación
│       ├── src/
│       ├── Dockerfile
│       └── package.json
├── BUSSINES/
│   └── ms-core/              # Servicio core del ERP
│       ├── src/
│       ├── Dockerfile
│       └── package.json
├── FRONTEND/
│   └── app-login-erp-seis/   # Aplicación Angular
│       ├── src/
│       ├── Dockerfile
│       └── package.json
├── DB/
│   └── db_seis_erp/
│       └── init-db/          # Scripts de inicialización
├── monitoring/
│   ├── prometheus/
│   │   └── prometheus.yml
│   └── grafana/
│       ├── provisioning/
│       │   ├── datasources/
│       │   └── dashboards/
│       └── dashboards/
├── vault/
│   ├── config/
│   └── policies/
├── scripts/
│   ├── deploy-full-stack.sh
│   ├── init-vault.sh
│   ├── backup-vault.sh
│   ├── restore-vault.sh
│   ├── verify-all.sh
│   └── fix-grafana-complete.sh
├── backups/
│   ├── vault/
│   └── database/
├── docker-compose-erp.yml
├── .env
├── .gitignore
├── Makefile
└── README.md
```

---

## 📦 Estructura de Submódulos

Este repositorio utiliza Git Submodules para gestionar los proyectos internos. Cada servicio tiene su propio repositorio:

| Directorio | Repositorio | Descripción |
|------------|-------------|-------------|
| `BFF+AUTH/ms-auth` | [erp-ms-auth](https://github.com/tu-organizacion/erp-ms-auth) | Servicio de autenticación |
| `BUSSINES/ms-core` | [erp-ms-core](https://github.com/tu-organizacion/erp-ms-core) | Servicio core del ERP |
| `FRONTEND/app-login-erp-seis` | [erp-frontend](https://github.com/tu-organizacion/erp-frontend) | Aplicación Angular |
| `DB/db_seis_erp` | [erp-database](https://github.com/tu-organizacion/erp-database) | Scripts de base de datos |

### Clonar con Submódulos

```bash
# Clonar el repositorio principal con todos los submódulos
git clone --recurse-submodules https://github.com/tu-organizacion/erp-system.git

# O si ya clonaste el repo sin submódulos
git submodule update --init --recursive
```

### Actualizar Submódulos

```bash
# Actualizar todos los submódulos a la última versión
git submodule update --remote --merge

# Actualizar un submódulo específico
git submodule update --remote BFF+AUTH/ms-auth
```

### Trabajar con Submódulos

```bash
# Hacer cambios en un submódulo
cd BFF+AUTH/ms-auth
git checkout -b feature/nueva-funcionalidad
# ... hacer cambios ...
git add .
git commit -m "Nueva funcionalidad"
git push origin feature/nueva-funcionalidad

# Volver al repo principal y actualizar la referencia
cd ../..
git add BFF+AUTH/ms-auth
git commit -m "Actualizar referencia de ms-auth"
git push
```

### Ver Estado de Submódulos

```bash
# Ver el estado de todos los submódulos
git submodule status

# Ver cambios en submódulos
git submodule foreach git status

# Ver diferencias
git diff --submodule
```

---

## 🤝 Contribuir

1. Fork el proyecto
2. Crear feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit cambios (`git commit -m 'Add AmazingFeature'`)
4. Push al branch (`git push origin feature/AmazingFeature`)
5. Abrir Pull Request

---

## 📄 Licencia

Este proyecto está bajo licencia MIT.

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


---

## 🎯 Roadmap

- [ ] Agregar tests automatizados
- [ ] Implementar CI/CD con GitHub Actions
- [ ] Migrar a Kubernetes
- [ ] Agregar más dashboards de Grafana
- [ ] Implementar alertas con Alertmanager
- [ ] Agregar Loki para logs centralizados
- [ ] Implementar tracing con Jaeger
- [ ] Agregar autenticación OAuth2

---

**⭐ Si este proyecto te fue útil, dale una estrella en GitHub!**

---

Made with ❤️ by [Tu Equipo]