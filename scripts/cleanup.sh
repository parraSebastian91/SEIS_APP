#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🧹 Limpiando servicios anteriores...${NC}"

# Detener todos los contenedores del proyecto
docker-compose -f docker-compose-erp.yml down

# Eliminar contenedores que puedan estar huérfanos
docker ps -a | grep -E "vault_server|vault" | awk '{print $1}' | xargs -r docker rm -f

# Verificar puertos liberados
echo ""
echo -e "${YELLOW}Verificando puertos... ${NC}"
for PORT in 8200 8000 8001 3030 9090 5432 6379; do
    if lsof -Pi :$PORT -sTCP: LISTEN -t >/dev/null 2>&1 ; then
        echo -e "${RED}✗ Puerto $PORT está ocupado${NC}"
    else
        echo -e "${GREEN}✓ Puerto $PORT está libre${NC}"
    fi
done

echo ""
echo -e "${GREEN}✅ Limpieza completada${NC}"
echo -e "${YELLOW}Ahora puedes ejecutar:  bash scripts/deploy-full-stack.sh${NC}"