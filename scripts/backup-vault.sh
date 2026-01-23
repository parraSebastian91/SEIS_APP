#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-myroot}"
BACKUP_DIR="./backups/vault"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Backup de Vault - ERP System              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Crear directorio de backups
mkdir -p "$BACKUP_DIR"

echo -e "${CYAN}📦 Creando backup de Vault...${NC}"

# Lista de paths a respaldar
PATHS=(
  "database"
  "redis"
  "auth-service"
  "core-service"
  "app-login"
  "shared"
  "kong"
)

BACKUP_FILE="${BACKUP_DIR}/vault_backup_${TIMESTAMP}.json"

echo "{" > "$BACKUP_FILE"
echo "  \"timestamp\": \"${TIMESTAMP}\"," >> "$BACKUP_FILE"
echo "  \"secrets\": {" >> "$BACKUP_FILE"

FIRST=true
for path in "${PATHS[@]}"; do
  echo -e "${YELLOW}  → Respaldando ${path}... ${NC}"
  
  SECRET=$(curl -sf -X GET "${VAULT_ADDR}/v1/secret/data/${path}" \
    -H "X-Vault-Token: ${VAULT_TOKEN}" 2>/dev/null || echo "{}")
  
  if [ "$SECRET" != "{}" ]; then
    if [ "$FIRST" = false ]; then
      echo "," >> "$BACKUP_FILE"
    fi
    echo "    \"${path}\": ${SECRET}" >> "$BACKUP_FILE"
    FIRST=false
    echo -e "${GREEN}    ✓ ${path} respaldado${NC}"
  else
    echo -e "${YELLOW}    ⚠ ${path} no encontrado${NC}"
  fi
done

echo "" >> "$BACKUP_FILE"
echo "  }" >> "$BACKUP_FILE"
echo "}" >> "$BACKUP_FILE"

# Comprimir backup
echo ""
echo -e "${CYAN}🗜️  Comprimiendo backup... ${NC}"
gzip -f "$BACKUP_FILE"
BACKUP_FILE="${BACKUP_FILE}.gz"

# Calcular hash
HASH=$(sha256sum "$BACKUP_FILE" | awk '{print $1}')

echo -e "${GREEN}✓ Backup completado${NC}"
echo ""
echo -e "${CYAN}📋 Información del backup:${NC}"
echo -e "  Archivo:   $(basename $BACKUP_FILE)"
echo -e "  Tamaño:   $(du -h $BACKUP_FILE | awk '{print $1}')"
echo -e "  SHA256:   $HASH"
echo -e "  Ubicación: $BACKUP_FILE"
echo ""

# Limpiar backups antiguos (mantener últimos 10)
echo -e "${CYAN}🧹 Limpiando backups antiguos...${NC}"
BACKUP_COUNT=$(ls -1 ${BACKUP_DIR}/vault_backup_*. json. gz 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 10 ]; then
  ls -1t ${BACKUP_DIR}/vault_backup_*.json.gz | tail -n +11 | xargs rm -f
  echo -e "${GREEN}✓ Backups antiguos eliminados${NC}"
else
  echo -e "${YELLOW}  No hay backups antiguos para eliminar${NC}"
fi

echo ""
echo -e "${GREEN}✅ Proceso de backup completado${NC}"
echo ""