#!/bin/bash

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# CONFIGURACIÓN
# =============================================================================

# Definir servicios en orden de inicio
SERVICES=(
    "services/postgres"
    "services/redis"
    "services/auth-service"
    "services/user-service"
    "services/organization-service"
    "services/api-gateway"
)

# Red compartida
NETWORK_NAME="erp_network"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Docker Hard Clean & Restart Script                  ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo ""

# =============================================================================
# 1. ADVERTENCIA Y CONFIRMACIÓN
# =============================================================================
echo -e "${YELLOW}⚠️  ADVERTENCIA: Este script realizará: ${NC}"
echo -e "   • Detener todos los contenedores"
echo -e "   • Eliminar todos los contenedores"
echo -e "   • Eliminar todas las imágenes"
echo -e "   • Eliminar todos los volúmenes"
echo -e "   • Eliminar todas las redes personalizadas"
echo -e "   • Limpiar caché de build"
echo ""
echo -e "${RED}⚠️  SE PERDERÁN TODOS LOS DATOS EN VOLÚMENES${NC}"
echo ""

read -p "¿Estás seguro de continuar? (escribe 'SI' para confirmar): " confirmacion

if [ "$confirmacion" != "SI" ]; then
    echo -e "${RED}❌ Operación cancelada${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Confirmación recibida.  Iniciando limpieza...${NC}"
echo ""

# =============================================================================
# 2. DETENER DOCKER COMPOSE (si existe)
# =============================================================================
echo -e "${BLUE}[1/9]${NC} 🛑 Deteniendo servicios de Docker Compose..."

if [ -f "docker-compose.yml" ] || [ -f "docker-compose. yaml" ]; then
    docker-compose down -v --remove-orphans 2>/dev/null || true
    echo -e "${GREEN}✓ Docker Compose detenido${NC}"
else
    echo -e "${YELLOW}⚠ No se encontró docker-compose.yml${NC}"
fi

echo ""

# =============================================================================
# 3. DETENER TODOS LOS CONTENEDORES
# =============================================================================
echo -e "${BLUE}[2/9]${NC} 🛑 Deteniendo todos los contenedores..."

if [ "$(docker ps -aq)" ]; then
    docker stop $(docker ps -aq) 2>/dev/null || true
    echo -e "${GREEN}✓ Contenedores detenidos${NC}"
else
    echo -e "${YELLOW}⚠ No hay contenedores corriendo${NC}"
fi

echo ""

# =============================================================================
# 4. ELIMINAR TODOS LOS CONTENEDORES
# =============================================================================
echo -e "${BLUE}[3/9]${NC} 🗑️  Eliminando todos los contenedores..."

if [ "$(docker ps -aq)" ]; then
    docker rm -f $(docker ps -aq) 2>/dev/null || true
    echo -e "${GREEN}✓ Contenedores eliminados:  $(docker ps -aq 2>/dev/null | wc -l)${NC}"
else
    echo -e "${YELLOW}⚠ No hay contenedores para eliminar${NC}"
fi

echo ""

# =============================================================================
# 5. ELIMINAR TODAS LAS IMÁGENES
# =============================================================================
echo -e "${BLUE}[4/9]${NC} 🗑️  Eliminando todas las imágenes..."

if [ "$(docker images -aq)" ]; then
    docker rmi -f $(docker images -aq) 2>/dev/null || true
    echo -e "${GREEN}✓ Imágenes eliminadas${NC}"
else
    echo -e "${YELLOW}⚠ No hay imágenes para eliminar${NC}"
fi

echo ""

# =============================================================================
# 6. ELIMINAR TODOS LOS VOLÚMENES
# =============================================================================
echo -e "${BLUE}[5/9]${NC} 🗑️  Eliminando todos los volúmenes..."

if [ "$(docker volume ls -q)" ]; then
    docker volume rm $(docker volume ls -q) 2>/dev/null || true
    echo -e "${GREEN}✓ Volúmenes eliminados${NC}"
else
    echo -e "${YELLOW}⚠ No hay volúmenes para eliminar${NC}"
fi

echo ""

# =============================================================================
# 7. ELIMINAR TODAS LAS REDES PERSONALIZADAS
# =============================================================================
echo -e "${BLUE}[6/9]${NC} 🗑️  Eliminando redes personalizadas..."

# No eliminar las redes por defecto (bridge, host, none)
CUSTOM_NETWORKS=$(docker network ls --filter type=custom -q)
if [ ! -z "$CUSTOM_NETWORKS" ]; then
    echo "$CUSTOM_NETWORKS" | xargs docker network rm 2>/dev/null || true
    echo -e "${GREEN}✓ Redes personalizadas eliminadas${NC}"
else
    echo -e "${YELLOW}⚠ No hay redes personalizadas para eliminar${NC}"
fi

echo ""

# =============================================================================
# 8. LIMPIAR CACHÉ Y RECURSOS NO UTILIZADOS
# =============================================================================
echo -e "${BLUE}[7/9]${NC} 🧹 Limpiando caché de build y recursos no utilizados..."

docker system prune -af --volumes 2>/dev/null || true
docker builder prune -af 2>/dev/null || true

echo -e "${GREEN}✓ Caché limpiada${NC}"
echo ""

# =============================================================================
# 9. MOSTRAR ESTADO ACTUAL
# =============================================================================
echo -e "${BLUE}[8/9]${NC} 📊 Estado actual de Docker:"
echo ""
echo -e "${YELLOW}Contenedores: ${NC} $(docker ps -a | wc -l | awk '{print $1-1}')"
echo -e "${YELLOW}Imágenes:${NC} $(docker images | wc -l | awk '{print $1-1}')"
echo -e "${YELLOW}Volúmenes:${NC} $(docker volume ls | wc -l | awk '{print $1-1}')"
echo -e "${YELLOW}Redes: ${NC} $(docker network ls | wc -l | awk '{print $1-1}')"
echo ""

# =============================================================================
# 10. LEVANTAR SERVICIOS
# =============================================================================
echo -e "${BLUE}[9/9]${NC} 🚀 Levantando servicios..."
echo ""

# Crear red compartida
echo -e "${BLUE}🌐 Creando red compartida:  ${NETWORK_NAME}${NC}"
docker network create $NETWORK_NAME 2>/dev/null || echo -e "${YELLOW}  Red ya existe${NC}"
echo ""

# Levantar cada servicio
for service_path in "${SERVICES[@]}"; do
    service_name=$(basename $service_path)
    
    echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}📦 Iniciando:  ${service_name}${NC}"
    echo -e "${YELLOW}────────────────────────────────────────────────────────${NC}"
    
    if [ !  -d "$service_path" ]; then
        echo -e "${RED}  ✗ Directorio no encontrado: $service_path${NC}"
        continue
    fi
    
    if [ !  -f "$service_path/docker-compose.yml" ]; then
        echo -e "${RED}  ✗ docker-compose.yml no encontrado en: $service_path${NC}"
        continue
    fi
    
    cd $service_path
    
    # Build
    echo -e "${BLUE}  → Construyendo... ${NC}"
    docker-compose build --no-cache
    
    # Up
    echo -e "${BLUE}  → Levantando...${NC}"
    docker-compose up -d
    
    # Esperar
    echo -e "${BLUE}  → Esperando...${NC}"
    sleep 10
    
    # Verificar
    if docker-compose ps | grep -q "Up"; then
        echo -e "${GREEN}  ✓ $service_name iniciado correctamente${NC}"
    else
        echo -e "${RED}  ✗ $service_name falló al iniciar${NC}"
        docker-compose logs --tail=20
    fi
    
    cd - > /dev/null
    echo ""
done

echo -e "${GREEN}✅ Todos los servicios procesados${NC}"
echo ""

# Verificar todos los servicios
echo -e "${BLUE}📊 Estado general: ${NC}"
for service_path in "${SERVICES[@]}"; do
    if [ -d "$service_path" ]; then
        cd $service_path
        docker-compose ps
        cd - > /dev/null
    fi
done

echo ""
echo -e "${GREEN}✨ Proceso completado${NC}"
# =============================================================================
# RESUMEN FINAL
# =============================================================================
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✅ PROCESO COMPLETADO                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📝 Comandos útiles:${NC}"
echo -e "   • Ver logs en tiempo real:     ${YELLOW}docker-compose logs -f${NC}"
echo -e "   • Ver estado de servicios:    ${YELLOW}docker-compose ps${NC}"
echo -e "   • Reiniciar un servicio:      ${YELLOW}docker-compose restart <servicio>${NC}"
echo -e "   • Detener servicios:          ${YELLOW}docker-compose down${NC}"
echo -e "   • Ver logs de un servicio:    ${YELLOW}docker-compose logs -f <servicio>${NC}"
echo ""
echo -e "${GREEN}✨ Todo listo para trabajar! ${NC}"
echo ""