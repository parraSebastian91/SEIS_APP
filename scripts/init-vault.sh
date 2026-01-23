#!/bin/bash

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-myroot}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Inicialización de Vault - ERP System          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# ===========================================================================
# 1. Esperar a que Vault esté disponible
# ===========================================================================
echo -e "${YELLOW}⏳ Esperando a que Vault esté disponible...${NC}"
RETRY_COUNT=0
MAX_RETRIES=30
until curl -sf "${VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "${RED}✗ Vault no está disponible después de ${MAX_RETRIES} intentos${NC}"
        exit 1
    fi
    echo "  Intento $RETRY_COUNT/$MAX_RETRIES..."
    sleep 2
done
echo -e "${GREEN}✓ Vault está disponible${NC}"
echo ""

# ===========================================================================
# 2. Habilitar el secrets engine KV v2
# ===========================================================================
echo -e "${CYAN}📦 Habilitando secrets engine KV v2...${NC}"
curl -sf -X POST "${VAULT_ADDR}/v1/sys/mounts/secret" \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "kv",
    "options": {
      "version":  "2"
    }
  }' 2>/dev/null || echo "  (Ya habilitado)"
echo -e "${GREEN}✓ KV v2 habilitado${NC}"
echo ""

# ===========================================================================
# 3. Configurar secretos de Base de Datos
# ===========================================================================
echo -e "${CYAN}🗄️  Configurando secretos de PostgreSQL...${NC}"
curl -sf -X POST "${VAULT_ADDR}/v1/secret/data/database" \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "host": "postgres",
      "port": "5432",
      "name": "core_erp",
      "username": "desarrollo",
      "password": "desarrollo123",
      "ssl_mode": "disable",
      "pool_size": "10",
      "connection_timeout": "30"
    }
  }'
echo -e "${GREEN}✓ Secretos de PostgreSQL configurados${NC}"

# ===========================================================================
# 4. Configurar secretos de Redis
# ===========================================================================
echo -e "${CYAN}📮 Configurando secretos de Redis...${NC}"
curl -sf -X POST "${VAULT_ADDR}/v1/secret/data/redis" \
  -H "X-Vault-Token:  ${VAULT_TOKEN}" \
  -H "Content-Type:  application/json" \
  -d '{
    "data": {
      "host": "redis",
      "port": "6379",
      "password": "",
      "db": "0",
      "ttl": "3600"
    }
  }'
echo -e "${GREEN}✓ Secretos de Redis configurados${NC}"

# ===========================================================================
# 5. Configurar secretos de Auth Service
# ===========================================================================
echo -e "${CYAN}🔐 Configurando secretos de Auth Service...${NC}"
curl -sf -X POST "${VAULT_ADDR}/v1/secret/data/auth-service" \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "jwt_secret": "your-super-secret-jwt-key-change-this-in-production",
      "jwt_expiration": "3600",
      "jwt_refresh_expiration": "604800",
      "bcrypt_rounds": "10",
      "session_secret": "your-session-secret-change-this",
      "cors_origins": "*",
      "rate_limit_max":  "100",
      "rate_limit_window_ms": "900000"
    }
  }'
echo -e "${GREEN}✓ Secretos de Auth Service configurados${NC}"

# ===========================================================================
# 6. Configurar secretos de Core Service
# ===========================================================================
echo -e "${CYAN}⚙️  Configurando secretos de Core Service...${NC}"
curl -sf -X POST "${VAULT_ADDR}/v1/secret/data/core-service" \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "api_key": "core-service-api-key-change-this",
      "encryption_key": "32-character-encryption-key!! ",
      "webhook_secret": "webhook-secret-change-this",
      "external_api_url": "https://api.external-service.com",
      "external_api_key": "external-api-key-here"
    }
  }'
echo -e "${GREEN}✓ Secretos de Core Service configurados${NC}"

# ===========================================================================
# 7. Configurar secretos de App Login (Frontend)
# ===========================================================================
echo -e "${CYAN}🎨 Configurando secretos de App Login...${NC}"
curl -sf -X POST "${VAULT_ADDR}/v1/secret/data/app-login" \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "api_auth_url": "/api/auth",
      "api_core_url": "/api/core",
      "api_base_url": "http://localhost:8000",
      "environment": "production",
      "enable_analytics": "false",
      "google_analytics_id": "",
      "sentry_dsn": ""
    }
  }'
echo -e "${GREEN}✓ Secretos de App Login configurados${NC}"

# ===========================================================================
# 8. Configurar secretos compartidos
# ===========================================================================
echo -e "${CYAN}🔗 Configurando secretos compartidos... ${NC}"
curl -sf -X POST "${VAULT_ADDR}/v1/secret/data/shared" \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "smtp_host": "smtp.gmail.com",
      "smtp_port": "587",
      "smtp_user": "noreply@yourcompany.com",
      "smtp_password": "your-smtp-password",
      "smtp_from": "ERP System <noreply@yourcompany.com>",
      "aws_access_key_id": "",
      "aws_secret_access_key": "",
      "aws_region": "us-east-1",
      "s3_bucket": "erp-uploads"
    }
  }'
echo -e "${GREEN}✓ Secretos compartidos configurados${NC}"

# ===========================================================================
# 9. Configurar secretos de Kong
# ===========================================================================
echo -e "${CYAN}🦍 Configurando secretos de Kong...${NC}"
curl -sf -X POST "${VAULT_ADDR}/v1/secret/data/kong" \
  -H "X-Vault-Token:  ${VAULT_TOKEN}" \
  -H "Content-Type:  application/json" \
  -d '{
    "data": {
      "admin_token": "kong-admin-token-change-this",
      "database_password": "kong",
      "session_secret": "kong-session-secret"
    }
  }'
echo -e "${GREEN}✓ Secretos de Kong configurados${NC}"

# ===========================================================================
# 10. Crear políticas
# ===========================================================================
echo ""
echo -e "${CYAN}📜 Creando políticas de acceso...${NC}"

# Política para auth-service
echo -e "${YELLOW}  → Creando política auth-service...${NC}"
curl -sf -X PUT "${VAULT_ADDR}/v1/sys/policies/acl/auth-service" \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "policy": "path \"secret/data/auth-service/*\" {\n  capabilities = [\"read\", \"list\"]\n}\npath \"secret/data/database/*\" {\n  capabilities = [\"read\"]\n}\npath \"secret/data/redis/*\" {\n  capabilities = [\"read\"]\n}\npath \"secret/data/shared/*\" {\n  capabilities = [\"read\"]\n}"
  }'
echo -e "${GREEN}  ✓ Política auth-service creada${NC}"

# Política para core-service
echo -e "${YELLOW}  → Creando política core-service... ${NC}"
curl -sf -X PUT "${VAULT_ADDR}/v1/sys/policies/acl/core-service" \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "policy": "path \"secret/data/core-service/*\" {\n  capabilities = [\"read\", \"list\"]\n}\npath \"secret/data/database/*\" {\n  capabilities = [\"read\"]\n}\npath \"secret/data/redis/*\" {\n  capabilities = [\"read\"]\n}\npath \"secret/data/shared/*\" {\n  capabilities = [\"read\"]\n}"
  }'
echo -e "${GREEN}  ✓ Política core-service creada${NC}"

# Política para app-login
echo -e "${YELLOW}  → Creando política app-login...${NC}"
curl -sf -X PUT "${VAULT_ADDR}/v1/sys/policies/acl/app-login" \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "policy": "path \"secret/data/app-login/*\" {\n  capabilities = [\"read\"]\n}\npath \"secret/data/shared/public/*\" {\n  capabilities = [\"read\"]\n}"
  }'
echo -e "${GREEN}  ✓ Política app-login creada${NC}"

# ===========================================================================
# 11. Crear tokens para cada servicio
# ===========================================================================
echo ""
echo -e "${CYAN}🎫 Generando tokens para servicios...${NC}"

# Token para auth-service
AUTH_TOKEN=$(curl -sf -X POST "${VAULT_ADDR}/v1/auth/token/create" \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "policies": ["auth-service"],
    "ttl": "768h",
    "renewable": true,
    "display_name": "auth-service-token"
  }' | grep -o '"client_token":"[^"]*' | cut -d'"' -f4)

echo -e "${GREEN}  ✓ Token para auth-service:  ${YELLOW}${AUTH_TOKEN}${NC}"

# Token para core-service
CORE_TOKEN=$(curl -sf -X POST "${VAULT_ADDR}/v1/auth/token/create" \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "policies": ["core-service"],
    "ttl": "768h",
    "renewable": true,
    "display_name": "core-service-token"
  }' | grep -o '"client_token":"[^"]*' | cut -d'"' -f4)

echo -e "${GREEN}  ✓ Token para core-service: ${YELLOW}${CORE_TOKEN}${NC}"

# ===========================================================================
# 12. Guardar tokens en archivo
# ===========================================================================
echo ""
echo -e "${CYAN}💾 Guardando tokens en archivo...${NC}"
cat > . vault-tokens << EOF
# Vault Tokens - NO COMMITEAR ESTE ARCHIVO
# Generado:  $(date)

VAULT_ADDR=${VAULT_ADDR}
VAULT_ROOT_TOKEN=${VAULT_TOKEN}

# Service Tokens
AUTH_SERVICE_VAULT_TOKEN=${AUTH_TOKEN}
CORE_SERVICE_VAULT_TOKEN=${CORE_TOKEN}

# Uso en . env: 
# VAULT_TOKEN=\${AUTH_SERVICE_VAULT_TOKEN} para auth-service
# VAULT_TOKEN=\${CORE_SERVICE_VAULT_TOKEN} para core-service
EOF

echo -e "${GREEN}✓ Tokens guardados en . vault-tokens${NC}"
echo -e "${RED}⚠️  IMPORTANTE:  Agregar . vault-tokens a .gitignore${NC}"

# ===========================================================================
# Resumen
# ===========================================================================
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          ✅ Vault configurado exitosamente             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📋 Información de acceso:${NC}"
echo ""
echo -e "  ${YELLOW}Vault UI:${NC}        ${VAULT_ADDR}/ui"
echo -e "  ${YELLOW}Root Token:${NC}      ${VAULT_TOKEN}"
echo ""
echo -e "${CYAN}🔑 Tokens de servicios guardados en:${NC} . vault-tokens"
echo ""
echo -e "${CYAN}📚 Secretos configurados:${NC}"
echo "  • database      → PostgreSQL credentials"
echo "  • redis         → Redis configuration"
echo "  • auth-service  → JWT, session secrets"
echo "  • core-service  → API keys, encryption"
echo "  • app-login     → Frontend configuration"
echo "  • shared        → SMTP, AWS, common configs"
echo "  • kong          → Kong admin tokens"
echo ""
echo -e "${CYAN}🔐 Políticas creadas:${NC}"
echo "  • auth-service  → Acceso a auth-service, database, redis"
echo "  • core-service  → Acceso a core-service, database, redis"
echo "  • app-login     → Acceso de solo lectura a configs públicas"
echo ""
echo -e "${YELLOW}⚠️  Próximos pasos:${NC}"
echo "  1. Actualizar .env con los tokens generados"
echo "  2. Reiniciar servicios para que usen Vault"
echo "  3. Verificar que los servicios pueden leer secretos"
echo "  4. En producción, usar tokens con TTL corto y rotación"
echo ""