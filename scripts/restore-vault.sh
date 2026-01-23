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
BACKUP_DIR="./backups/vault"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║             Restore de Vault - ERP System              ║${NC}"
echo -e "${BLUE}╚══════════════���═════════════════════════════════════════╝${NC}"
echo ""

# Listar backups disponibles
echo -e "${CYAN}📋 Backups disponibles: ${NC}"
echo ""

BACKUPS=($(ls -1t ${BACKUP_DIR}/vault_backup_*.json.gz 2>/dev/null))

if [ ${#BACKUPS[@]} -eq 0 ]; then
  echo -e "${RED}✗ No se encontraron backups${NC}"
  exit 1
fi

for i in "${! BACKUPS[@]}"; do
  BACKUP_FILE="${BACKUPS[$i]}"
  SIZE=$(du -h "$BACKUP_FILE" | awk '{print $1}')
  DATE=$(basename "$BACKUP_FILE" | sed 's/vault_backup_//; s/. json.gz//')
  echo -e "  ${YELLOW}[$((i+1))]${NC} $DATE (${SIZE})"
done

echo ""
read -p "Selecciona el backup a restaurar [1-${#BACKUPS[@]}]: " SELECTION

if [[ !  "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt ${#BACKUPS[@]} ]; then
  echo -e "${RED}✗ Selección inválida${NC}"
  exit 1
fi

SELECTED_BACKUP="${BACKUPS[$((SELECTION-1))]}"

echo ""
echo -e "${YELLOW}⚠️  ADVERTENCIA: Este proceso sobrescribirá los secretos actuales${NC}"
read -p "¿Estás seguro de continuar? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo -e "${YELLOW}Operación cancelada${NC}"
  exit 0
fi

echo ""
echo -e "${CYAN}📦 Restaurando backup:  $(basename $SELECTED_BACKUP)${NC}"
echo ""

# Descomprimir backup
TEMP_FILE="/tmp/vault_restore_$$.json"
gunzip -c "$SELECTED_BACKUP" > "$TEMP_FILE"

# Leer y restaurar secretos
echo -e "${CYAN}🔄 Restaurando secretos...${NC}"

# Extraer paths del backup
PATHS=$(jq -r '.secrets | keys[]' "$TEMP_FILE" 2>/dev/null)

if [ -z "$PATHS" ]; then
  echo -e "${RED}✗ Error leyendo backup${NC}"
  rm -f "$TEMP_FILE"
  exit 1
fi

for path in $PATHS; do
  echo -e "${YELLOW}  → Restaurando ${path}...${NC}"
  
  # Extraer secreto
  SECRET_DATA=$(jq -c ". secrets. \"${path}\".data. data" "$TEMP_FILE")
  
  if [ "$SECRET_DATA" != "null" ]; then
    # Restaurar secreto
    curl -sf -X POST "${VAULT_ADDR}/v1/secret/data/${path}" \
      -H "X-Vault-Token: ${VAULT_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"data\": ${SECRET_DATA}}" > /dev/null
    
    echo -e "${GREEN}    ✓ ${path} restaurado${NC}"
  else
    echo -e "${YELLOW}    ⚠ ${path} sin datos${NC}"
  fi
done

# Limpiar archivo temporal
rm -f "$TEMP_FILE"

echo ""
echo -e "${GREEN}✅ Restore completado exitosamente${NC}"
echo ""
echo -e "${YELLOW}💡 Recuerda reiniciar los servicios para que carguen los nuevos secretos: ${NC}"
echo -e "   docker-compose -f docker-compose-erp.yml restart auth-service ms_core"
echo ""