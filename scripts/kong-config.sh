#!/bin/bash

# =============================================================================
# Script de Configuración de Kong para SEIS ERP
# =============================================================================
# Configura servicios y rutas en Kong para el API Gateway
# Uso: ./kong-config.sh
# =============================================================================

set -e

KONG_ADMIN_URL="${KONG_ADMIN_URL:-http://localhost:8001}"

echo "🔧 Configurando Kong API Gateway..."
echo "🌐 Kong Admin URL: $KONG_ADMIN_URL"
echo ""

# Función para crear servicio
create_service() {
    local service_name=$1
    local service_url=$2
    
    echo "📦 Creando servicio: $service_name"
    
    # Eliminar servicio si existe
    curl -s -X DELETE "$KONG_ADMIN_URL/services/$service_name" > /dev/null 2>&1 || true
    
    # Crear servicio
    curl -s -X POST "$KONG_ADMIN_URL/services" \
        -d "name=$service_name" \
        -d "url=$service_url" \
        -d "connect_timeout=60000" \
        -d "write_timeout=60000" \
        -d "read_timeout=60000" \
        > /dev/null
    
    echo "✅ Servicio $service_name creado"
}

# Función para crear ruta
create_route() {
    local service_name=$1
    local route_path=$2
    local route_name=$3
    
    echo "🛣️  Creando ruta: $route_name -> $route_path"
    
    curl -s -X POST "$KONG_ADMIN_URL/services/$service_name/routes" \
        -d "name=$route_name" \
        -d "paths[]=$route_path" \
        -d "strip_path=true" \
        > /dev/null
    
    echo "✅ Ruta $route_name creada"
}

# Función para crear ruta sin strip (mantiene el path base)
create_route_no_strip() {
    local service_name=$1
    local route_path=$2
    local route_name=$3
    
    echo "🛣️  Creando ruta (sin strip): $route_name -> $route_path"
    
    curl -s -X POST "$KONG_ADMIN_URL/services/$service_name/routes" \
        -d "name=$route_name" \
        -d "paths[]=$route_path" \
        -d "strip_path=false" \
        > /dev/null
    
    echo "✅ Ruta $route_name creada (sin strip)"
}

# Función para agregar plugin de CORS
add_cors_plugin() {
    local service_name=$1
    
    echo "🔐 Agregando plugin CORS a: $service_name"
    
    curl -s -X POST "$KONG_ADMIN_URL/services/$service_name/plugins" \
        -d "name=cors" \
        -d "config.origins=*" \
        -d "config.methods=GET" \
        -d "config.methods=POST" \
        -d "config.methods=PUT" \
        -d "config.methods=PATCH" \
        -d "config.methods=DELETE" \
        -d "config.methods=OPTIONS" \
        -d "config.headers=Accept" \
        -d "config.headers=Accept-Version" \
        -d "config.headers=Content-Length" \
        -d "config.headers=Content-MD5" \
        -d "config.headers=Content-Type" \
        -d "config.headers=Date" \
        -d "config.headers=Authorization" \
        -d "config.exposed_headers=X-Auth-Token" \
        -d "config.credentials=true" \
        -d "config.max_age=3600" \
        > /dev/null
    
    echo "✅ Plugin CORS agregado"
}

# =============================================================================
# SERVICIOS BACKEND
# =============================================================================

echo ""
echo "🔹 Configurando servicios backend..."
echo ""

# Servicio de Autenticación
create_service "auth-service" "http://auth-service:3000"
create_route "auth-service" "/api/auth" "auth-route"
add_cors_plugin "auth-service"

echo ""

# Servicio Core
create_service "core-service" "http://ms_core:3001"
create_route "core-service" "/api/core" "core-route"
add_cors_plugin "core-service"

echo ""

# =============================================================================
# APLICACIONES FRONTEND
# =============================================================================

echo ""
echo "🔹 Configurando aplicaciones frontend..."
echo ""

# Aplicación de Login
create_service "app-login" "http://app_login:80"
create_route "app-login" "/login" "login-route"

echo ""

# Portal (Shell)
create_service "app-portal" "http://app_portal:80"
create_route "app-portal" "/portal" "portal-route"

echo ""

# =============================================================================
# MICROFRONTENDS (MFE)
# =============================================================================

echo ""
echo "🔹 Configurando Microfrontends..."
echo ""

# MFE Gestión de Usuarios
create_service "mfe-gestion-usuario" "http://app_mfe_gestion_usuario:80"
create_route_no_strip "mfe-gestion-usuario" "/mfe-gestion-usuario" "mfe-usuario-route"
add_cors_plugin "mfe-gestion-usuario"

echo ""

# MFE Dashboard de Facturas
create_service "mfe-dashboard-facturas" "http://app_mfe_dashboard_facturas:80"
create_route_no_strip "mfe-dashboard-facturas" "/mfe-dashboard-facturas" "mfe-dashboard-facturas-route"
add_cors_plugin "mfe-dashboard-facturas"

echo ""

# MFE Publicador de Facturas
create_service "mfe-publicador-facturas" "http://app_mfe_publicador_facturas:80"
create_route_no_strip "mfe-publicador-facturas" "/mfe-publicador-facturas" "mfe-publicador-facturas-route"
add_cors_plugin "mfe-publicador-facturas"

echo ""

# =============================================================================
# VERIFICACIÓN
# =============================================================================

echo ""
echo "✅ Configuración de Kong completada"
echo ""
echo "📋 Servicios configurados:"
curl -s "$KONG_ADMIN_URL/services" | grep -o '"name":"[^"]*"' | sed 's/"name":"/  - /' | sed 's/"$//' || echo "  (No se pudieron listar)"

echo ""
echo "📋 Rutas configuradas:"
curl -s "$KONG_ADMIN_URL/routes" | grep -o '"name":"[^"]*"' | sed 's/"name":"/  - /' | sed 's/"$//' || echo "  (No se pudieron listar)"

echo ""
echo "🌐 URLs de acceso:"
echo "  - Login:          http://localhost:8000/login"
echo "  - Portal:         http://localhost:8000/portal"
echo "  - Auth API:       http://localhost:8000/api/auth"
echo "  - Core API:       http://localhost:8000/api/core"
echo "  - MFE Usuario:    http://localhost:8000/mfe-gestion-usuario"
echo "  - MFE Dashboard:  http://localhost:8000/mfe-dashboard-facturas"
echo "  - MFE Publicador: http://localhost:8000/mfe-publicador-facturas"
echo ""
echo "🎉 ¡Listo para usar!"
