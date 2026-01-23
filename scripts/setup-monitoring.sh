#!/bin/bash

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Setup de Monitoring Stack - ERP System         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# ===========================================================================
# 1. Verificar que los servicios de monitoring están corriendo
# ===========================================================================
echo -e "${CYAN}🔍 Verificando servicios de monitoring...${NC}"

check_service() {
    local service=$1
    local url=$2
    
    if curl -sf "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ $service está disponible${NC}"
        return 0
    else
        echo -e "${RED}  ✗ $service NO está disponible${NC}"
        return 1
    fi
}

echo ""
check_service "Prometheus" "http://localhost:9090/-/healthy"
check_service "Grafana" "http://localhost:3030/api/health"
check_service "Loki" "http://localhost:3100/ready"
check_service "Node Exporter" "http://localhost:9100/metrics"

echo ""

# ===========================================================================
# 2. Importar dashboards predefinidos a Grafana
# ===========================================================================
echo -e "${CYAN}📊 Importando dashboards a Grafana...${NC}"

GRAFANA_URL="http://localhost:3030"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin123}"

# Esperar a que Grafana esté listo
echo -e "${YELLOW}⏳ Esperando a que Grafana esté listo...${NC}"
RETRY_COUNT=0
MAX_RETRIES=30
until curl -sf -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" "${GRAFANA_URL}/api/health" > /dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "${RED}✗ Grafana no está disponible${NC}"
        exit 1
    fi
    sleep 2
done
echo -e "${GREEN}✓ Grafana está listo${NC}"

# Importar dashboard de Docker
echo -e "${YELLOW}  ��� Importando Docker Dashboard...${NC}"
curl -sf -X POST "${GRAFANA_URL}/api/dashboards/db" \
  -u "${GRAFANA_USER}: ${GRAFANA_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "dashboard":  {
      "id": null,
      "title": "Docker Container Metrics",
      "tags": ["docker", "cadvisor"],
      "timezone": "browser",
      "schemaVersion": 16,
      "version": 0,
      "refresh": "30s"
    },
    "folderId": 0,
    "overwrite": true
  }' > /dev/null && echo -e "${GREEN}  ✓ Docker Dashboard importado${NC}"

# Importar dashboard de PostgreSQL
echo -e "${YELLOW}  → Importando PostgreSQL Dashboard...${NC}"
curl -sf -X POST "${GRAFANA_URL}/api/dashboards/db" \
  -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
  -H "Content-Type:  application/json" \
  -d '{
    "dashboard": {
      "id": null,
      "title": "PostgreSQL Metrics",
      "tags": ["postgresql", "database"],
      "timezone": "browser",
      "schemaVersion": 16,
      "version": 0,
      "refresh": "30s"
    },
    "folderId": 0,
    "overwrite": true
  }' > /dev/null && echo -e "${GREEN}  ✓ PostgreSQL Dashboard importado${NC}"

# Importar dashboard de Redis
echo -e "${YELLOW}  → Importando Redis Dashboard...${NC}"
curl -sf -X POST "${GRAFANA_URL}/api/dashboards/db" \
  -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "dashboard": {
      "id": null,
      "title": "Redis Metrics",
      "tags": ["redis", "cache"],
      "timezone": "browser",
      "schemaVersion":  16,
      "version":  0,
      "refresh":  "30s"
    },
    "folderId": 0,
    "overwrite": true
  }' > /dev/null && echo -e "${GREEN}  ✓ Redis Dashboard importado${NC}"

# Importar dashboard de Node. js
echo -e "${YELLOW}  → Importando Node. js Dashboard...${NC}"
curl -sf -X POST "${GRAFANA_URL}/api/dashboards/db" \
  -u "${GRAFANA_USER}: ${GRAFANA_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "dashboard":  {
      "id": null,
      "title": "Node. js Application Metrics",
      "tags": ["nodejs", "nestjs", "backend"],
      "timezone": "browser",
      "schemaVersion":  16,
      "version":  0,
      "refresh":  "30s"
    },
    "folderId": 0,
    "overwrite": true
  }' > /dev/null && echo -e "${GREEN}  ✓ Node.js Dashboard importado${NC}"

# Importar dashboard de Kong
echo -e "${YELLOW}  → Importando Kong Dashboard... ${NC}"
curl -sf -X POST "${GRAFANA_URL}/api/dashboards/db" \
  -u "${GRAFANA_USER}:${GRAFANA_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{
    "dashboard": {
      "id": null,
      "title": "Kong API Gateway Metrics",
      "tags":  ["kong", "api-gateway"],
      "timezone": "browser",
      "schemaVersion": 16,
      "version": 0,
      "refresh": "30s"
    },
    "folderId": 0,
    "overwrite":  true
  }' > /dev/null && echo -e "${GREEN}  ✓ Kong Dashboard importado${NC}"

echo ""

# ===========================================================================
# 3. Verificar targets de Prometheus
# ===========================================================================
echo -e "${CYAN}🎯 Verificando targets de Prometheus...${NC}"

TARGETS=$(curl -sf "http://localhost:9090/api/v1/targets" | \
  python3 -c "import sys, json; data = json.load(sys.stdin); \
  active = data['data']['activeTargets']; \
  print(f'Total targets: {len(active)}'); \
  [print(f'  • {t[\"labels\"][\"job\"]}: {t[\"health\"]}') for t in active]" 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "$TARGETS"
else
    echo -e "${YELLOW}⚠ No se pudo verificar targets (Prometheus puede estar iniciando)${NC}"
fi

echo ""

# ===========================================================================
# 4. Verificar métricas básicas
# ===========================================================================
echo -e "${CYAN}📈 Verificando que las métricas están siendo recolectadas...${NC}"

check_metrics() {
    local query=$1
    local name=$2
    
    local result=$(curl -sf -G "http://localhost:9090/api/v1/query" \
      --data-urlencode "query=${query}" | \
      python3 -c "import sys, json; data = json. load(sys.stdin); \
      print('OK' if data['data']['result'] else 'EMPTY')" 2>/dev/null)
    
    if [ "$result" = "OK" ]; then
        echo -e "${GREEN}  ✓ $name${NC}"
    else
        echo -e "${YELLOW}  ⚠ $name (aún no hay datos)${NC}"
    fi
}

check_metrics "up" "Servicios activos"
check_metrics "node_cpu_seconds_total" "CPU del host"
check_metrics "container_memory_usage_bytes" "Memoria de contenedores"
check_metrics "pg_up" "PostgreSQL"
check_metrics "redis_up" "Redis"

echo ""

# ===========================================================================
# 5. Crear carpetas para dashboards personalizados
# ===========================================================================
echo -e "${CYAN}📁 Creando estructura de dashboards...${NC}"

mkdir -p monitoring/grafana/dashboards/custom
mkdir -p monitoring/grafana/dashboards/imported

echo -e "${GREEN}✓ Estructura creada${NC}"

# ===========================================================================
# 6. Resumen final
# ===========================================================================
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       ✅ Monitoring Stack configurado exitosamente     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📊 URLs de acceso:${NC}"
echo ""
echo -e "  ${YELLOW}Grafana:${NC}        http://localhost:3030"
echo -e "    Usuario:       ${GRAFANA_USER}"
echo -e "    Password:     ${GRAFANA_PASSWORD}"
echo ""
echo -e "  ${YELLOW}Prometheus: ${NC}     http://localhost:9090"
echo -e "  ${YELLOW}Loki: ${NC}           http://localhost:3100"
echo ""
echo -e "${CYAN}📈 Dashboards disponibles:${NC}"
echo "  • Docker Container Metrics"
echo "  • PostgreSQL Metrics"
echo "  • Redis Metrics"
echo "  • Node.js Application Metrics"
echo "  • Kong API Gateway Metrics"
echo ""
echo -e "${YELLOW}💡 Tips:${NC}"
echo "  • Explora Grafana para crear dashboards personalizados"
echo "  • Usa Loki en Grafana para ver logs agregados"
echo "  • Configura alertas en Prometheus para notificaciones"
echo ""