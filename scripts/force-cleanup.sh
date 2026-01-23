#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🧹 Limpieza forzada de todos los servicios...${NC}"
echo ""

# 1. Detener docker-compose
echo -e "${YELLOW}Deteniendo servicios con docker-compose...${NC}"
docker-compose -f docker-compose-erp.yml down -v 2>/dev/null || true
echo ""

# 2. Eliminar contenedores específicos del proyecto
echo -e "${YELLOW}Eliminando contenedores del proyecto...${NC}"
docker ps -aq --filter "name=vault_server" | xargs -r docker rm -f
docker ps -aq --filter "name=seis_erp" | xargs -r docker rm -f
docker ps -aq --filter "name=kong" | xargs -r docker rm -f
docker ps -aq --filter "name=grafana" | xargs -r docker rm -f
docker ps -aq --filter "name=prometheus" | xargs -r docker rm -f
docker ps -aq --filter "name=ms_" | xargs -r docker rm -f
docker ps -aq --filter "name=app_login" | xargs -r docker rm -f
echo -e "${GREEN}✓ Contenedores eliminados${NC}"
echo ""

# 3. Eliminar volúmenes
echo -e "${YELLOW}Eliminando volúmenes...${NC}"
docker volume rm vault_data 2>/dev/null || true
docker volume rm vault_logs 2>/dev/null || true
docker volume rm seis_erp_postgres_data 2>/dev/null || true
docker volume rm seis_erp_redis_data 2>/dev/null || true
docker volume rm prometheus_data 2>/dev/null || true
docker volume rm grafana_data 2>/dev/null || true
echo -e "${GREEN}✓ Volúmenes eliminados${NC}"
echo ""

# 4. Verificar puertos
echo -e "${YELLOW}Verificando puertos...${NC}"
PORTS=(8200 8000 8001 3030 9090 5432 6379 3000 3001)
for PORT in "${PORTS[@]}"; do
    PID=$(lsof -ti:$PORT 2>/dev/null || true)
    if [ ! -z "$PID" ]; then
        echo -e "${RED}✗ Puerto $PORT ocupado por PID $PID${NC}"
        read -p "¿Matar proceso en puerto $PORT? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kill -9 $PID 2>/dev/null || sudo kill -9 $PID
            echo -e "${GREEN}  ✓ Proceso eliminado${NC}"
        fi
    else
        echo -e "${GREEN}✓ Puerto $PORT libre${NC}"
    fi
done
echo ""

# 5. Limpiar red (recrearla)
echo -e "${YELLOW}Limpiando red... ${NC}"
docker network rm erp_network 2>/dev/null || true
docker network create erp_network
echo -e "${GREEN}✓ Red recreada${NC}"
echo ""

echo -e "${GREEN}╔═══════════════════════════════════��════════════════════╗${NC}"
echo -e "${GREEN}║        ✅ Limpieza completada exitosamente             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Ahora puedes ejecutar: ${NC}"
echo -e "  bash scripts/deploy-full-stack.sh"
echo ""