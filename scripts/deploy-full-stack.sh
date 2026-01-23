#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-myroot}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Despliegue Completo ERP + Vault + Monitoring     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# ===========================================================================
# Verificar prerequisitos
# ===========================================================================
echo -e "${CYAN}🔍 Verificando prerequisitos...${NC}"

# Verificar Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker no está instalado${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Docker instalado${NC}"

# Verificar Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}✗ Docker Compose no está instalado${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Docker Compose instalado${NC}"

echo ""

# ===========================================================================
# Crear estructura de directorios
# ===========================================================================
echo -e "${CYAN}📁 Creando estructura de directorios...${NC}"

mkdir -p monitoring/prometheus
mkdir -p monitoring/grafana/provisioning/datasources
mkdir -p monitoring/grafana/provisioning/dashboards
mkdir -p monitoring/grafana/dashboards
mkdir -p vault/config
mkdir -p vault/policies
mkdir -p scripts
mkdir -p backups/vault
mkdir -p backups/database

echo -e "${GREEN}✓ Estructura creada${NC}"
echo ""

# ===========================================================================
# Crear prometheus.yml si no existe
# ===========================================================================
if [ ! -f "monitoring/prometheus/prometheus.yml" ]; then
    echo -e "${CYAN}📝 Creando prometheus.yml... ${NC}"
    cat > monitoring/prometheus/prometheus.yml << 'PROMEOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'erp-cluster'
    environment: 'development'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets:  ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'redis'
    static_configs: 
      - targets: ['redis-exporter:9121']

  - job_name: 'kong'
    static_configs: 
      - targets: ['kong: 8001']
    metrics_path: '/metrics'

  - job_name: 'auth-service'
    static_configs:
      - targets: ['auth-service:3000']
    metrics_path:  '/metrics'

  - job_name: 'core-service'
    static_configs:
      - targets: ['ms_core:3001']
    metrics_path: '/metrics'
PROMEOF
    echo -e "${GREEN}✓ prometheus.yml creado${NC}"
fi

# ===========================================================================
# Crear datasource de Grafana si no existe
# ===========================================================================
if [ ! -f "monitoring/grafana/provisioning/datasources/datasource.yml" ]; then
    echo -e "${CYAN}📝 Creando datasource de Grafana...${NC}"
    cat > monitoring/grafana/provisioning/datasources/datasource.yml << 'GRAFEOF'
apiVersion: 1

datasources:
  - name:  Prometheus
    type: prometheus
    access: proxy
    url:  http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"
GRAFEOF
    echo -e "${GREEN}✓ Datasource creado${NC}"
fi

# ===========================================================================
# Crear dashboard provisioning
# ===========================================================================
if [ ! -f "monitoring/grafana/provisioning/dashboards/dashboard.yml" ]; then
    echo -e "${CYAN}📝 Creando dashboard provisioning...${NC}"
    cat > monitoring/grafana/provisioning/dashboards/dashboard.yml << 'DASHEOF'
apiVersion: 1

providers: 
  - name: 'default'
    orgId: 1
    folder:  'ERP Dashboards'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
DASHEOF
    echo -e "${GREEN}✓ Dashboard provisioning creado${NC}"
fi

echo ""

# ===========================================================================
# 1. Crear red si no existe
# ===========================================================================
echo -e "${CYAN}🌐 Creando red Docker...${NC}"
docker network create erp_network 2>/dev/null && echo -e "${GREEN}✓ Red creada${NC}" || echo -e "${YELLOW}  (Red ya existe)${NC}"
echo ""

# ===========================================================================
# 2. Levantar servicios base (sin monitoring)
# ===========================================================================
echo -e "${CYAN}🚀 Levantando servicios base...${NC}"
docker-compose -f docker-compose-erp.yml up -d postgres redis
echo -e "${GREEN}✓ PostgreSQL y Redis iniciados${NC}"
echo ""

# Esperar a que estén healthy
echo -e "${YELLOW}⏳ Esperando a que los servicios base estén listos...${NC}"
sleep 10

# ===========================================================================
# 3. Levantar Vault
# ===========================================================================
echo -e "${CYAN}🔐 Levantando Vault...${NC}"
docker-compose -f docker-compose-erp.yml up -d vault
echo -e "${GREEN}✓ Vault iniciado${NC}"
echo ""

# Esperar a que Vault esté listo
echo -e "${YELLOW}⏳ Esperando a que Vault esté listo...${NC}"
sleep 10

# ===========================================================================
# 4. Inicializar Vault
# ===========================================================================
if [ -f "scripts/init-vault.sh" ]; then
    echo -e "${CYAN}🔐 Inicializando Vault...${NC}"
    bash scripts/init-vault.sh
    echo ""
else
    echo -e "${YELLOW}⚠ scripts/init-vault.sh no encontrado, saltando inicialización de Vault${NC}"
    echo ""
fi

# ===========================================================================
# 5. Levantar servicios de aplicación
# ===========================================================================
echo -e "${CYAN}🎯 Levantando servicios de aplicación...${NC}"
docker-compose -f docker-compose-erp.yml up -d auth-service ms_core
echo -e "${GREEN}✓ Servicios de aplicación iniciados${NC}"
echo ""

# Esperar
sleep 5

# ===========================================================================
# 6. Levantar Kong
# ===========================================================================
echo -e "${CYAN}🦍 Levantando Kong...${NC}"
docker-compose -f docker-compose-erp.yml up -d kong-db kong-migration kong
echo -e "${GREEN}✓ Kong iniciado${NC}"
echo ""

# Esperar a que Kong esté listo
echo -e "${YELLOW}⏳ Esperando a que Kong esté listo...${NC}"
sleep 15

# ===========================================================================
# 7. Configurar Kong
# ===========================================================================
if [ -f "setup-kong-frontend.sh" ]; then
    echo -e "${CYAN}⚙️ Configurando Kong...${NC}"
    bash setup-kong-frontend.sh
    echo ""
else
    echo -e "${YELLOW}⚠ setup-kong-frontend.sh no encontrado, saltando configuración de Kong${NC}"
    echo ""
fi

# ===========================================================================
# 8. Levantar frontend
# ===========================================================================
echo -e "${CYAN}🎨 Levantando frontend... ${NC}"
docker-compose -f docker-compose-erp. yml up -d --build app-login
echo -e "${GREEN}✓ Frontend iniciado${NC}"
echo ""

# ===========================================================================
# 9. Levantar exporters primero
# ===========================================================================
echo -e "${CYAN}📊 Levantando exporters de métricas...${NC}"
docker-compose -f docker-compose-erp.yml up -d \
  node-exporter \
  cadvisor \
  postgres-exporter \
  redis-exporter
echo -e "${GREEN}✓ Exporters iniciados${NC}"
echo ""

sleep 5

# ===========================================================================
# 10. Levantar Prometheus
# ===========================================================================
echo -e "${CYAN}📊 Levantando Prometheus... ${NC}"
docker-compose -f docker-compose-erp. yml up -d prometheus
echo -e "${GREEN}✓ Prometheus iniciado${NC}"
echo ""

sleep 5

# ===========================================================================
# 11. Levantar Grafana
# ===========================================================================
echo -e "${CYAN}📈 Levantando Grafana...${NC}"
docker-compose -f docker-compose-erp.yml up -d grafana
echo -e "${GREEN}✓ Grafana iniciado${NC}"
echo ""

# ===========================================================================
# 12. Levantar herramientas de admin (opcional)
# ===========================================================================
echo -e "${CYAN}🛠️ Levantando herramientas de administración...${NC}"
docker-compose -f docker-compose-erp.yml --profile admin-tools up -d 2>/dev/null || \
  echo -e "${YELLOW}  (Herramientas de admin no configuradas o ya levantadas)${NC}"
echo ""

# ===========================================================================
# 13. Esperar a que todo esté listo
# ===========================================================================
echo -e "${YELLOW}⏳ Esperando a que todos los servicios estén listos... ${NC}"
sleep 10
echo ""

# ===========================================================================
# 14. Verificar estado
# ===========================================================================
echo -e "${CYAN}🔍 Verificando estado de servicios...${NC}"
docker-compose -f docker-compose-erp.yml ps
echo ""

# ===========================================================================
# Resumen final
# ===========================================================================
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            ✅ Stack Completo Desplegado                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📱 Aplicaciones: ${NC}"
echo -e "  ${YELLOW}Frontend: ${NC}        http://localhost:8000/"
echo ""
echo -e "${CYAN}🔐 Seguridad:${NC}"
echo -e "  ${YELLOW}Vault UI:${NC}        http://localhost:8200/ui"
echo -e "  ${YELLOW}Token:${NC}           myroot (ver . vault-tokens para tokens de servicios)"
echo ""
echo -e "${CYAN}📊 Monitoring:${NC}"
echo -e "  ${YELLOW}Grafana:${NC}         http://localhost:3030 (admin/admin123)"
echo -e "  ${YELLOW}Prometheus:${NC}      http://localhost:9090"
echo ""
echo -e "${CYAN}🛠️ Administración:${NC}"
echo -e "  ${YELLOW}Kong Admin:${NC}      http://localhost:8001"
echo -e "  ${YELLOW}Konga:${NC}           http://localhost:1337"
echo -e "  ${YELLOW}PgAdmin:${NC}         http://localhost:5050"
echo -e "  ${YELLOW}Portainer:${NC}       http://localhost:9000"
echo ""
echo -e "${CYAN}📊 Exporters:${NC}"
echo -e "  ${YELLOW}Node Exporter:${NC}   http://localhost:9100/metrics"
echo -e "  ${YELLOW}cAdvisor:${NC}        http://localhost:8080"
echo -e "  ${YELLOW}Postgres: ${NC}        http://localhost:9187/metrics"
echo -e "  ${YELLOW}Redis:${NC}           http://localhost:9121/metrics"
echo ""
echo -e "${GREEN}🎉 ¡Sistema listo para usar!${NC}"
echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo -e "  • Accede a Grafana para ver dashboards"
echo -e "  • Revisa Vault UI para gestionar secretos"
echo -e "  • Usa 'make logs' para ver logs en tiempo real"
echo -e "  • Usa 'make health' para verificar el estado"
echo ""