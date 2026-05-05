#!/bin/bash

set -euo pipefail

INFRA_COMPOSE_FILE="${INFRA_COMPOSE_FILE:-./../docker-compose-app-imfra.yml}"
MINIO_INTERNAL_ENDPOINT="${MINIO_INTERNAL_ENDPOINT:-http://minio:9000}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin123}"
MINIO_BUCKET="${MINIO_BUCKET:-seis-app}"
MINIO_NOTIFY_TARGET_ARN="${MINIO_NOTIFY_TARGET_ARN:-arn:minio:sqs::1:webhook}"
STORAGE_HEALTH_URL="${STORAGE_HEALTH_URL:-http://localhost:${STORAGE_SERVICE_PORT:-3100}/health}"

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  echo "[ERROR] Docker Compose no disponible"
  exit 1
fi

compose() {
  $COMPOSE_CMD "$@"
}

run_mc() {
  compose -f "$INFRA_COMPOSE_FILE" run --rm --no-deps --entrypoint /bin/sh minio-setup -c "$1"
}



echo "[INFO] Validando bucket y acceso publico en MinIO"
run_mc "
  set -e
  mc alias set local $MINIO_INTERNAL_ENDPOINT $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
  mc ls local/$MINIO_BUCKET >/dev/null
  mc anonymous get local/$MINIO_BUCKET | grep -qi download
"

echo "[INFO] Validando reglas de eventos configuradas"
run_mc "
  set -e
  mc alias set local $MINIO_INTERNAL_ENDPOINT $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
  mc event list local/$MINIO_BUCKET | grep -q '$MINIO_NOTIFY_TARGET_ARN'
"

TEST_KEY="healthcheck/$(date +%s)-webhook.txt"
TEST_CONTENT="minio webhook smoke test"

echo "[INFO] Subiendo archivo de prueba: $TEST_KEY"
run_mc "
  set -e
  mc alias set local $MINIO_INTERNAL_ENDPOINT $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD
  echo '$TEST_CONTENT' > /tmp/healthcheck.txt
  mc cp /tmp/healthcheck.txt local/$MINIO_BUCKET/$TEST_KEY
"

echo "[INFO] Verificando recepcion del webhook en logs de ms_storage_service"
if ! docker logs ms_storage_service --since 30s 2>&1 | grep -q "$TEST_KEY"; then
  echo "[ERROR] No se detecto el objeto de prueba en logs de webhook de ms_storage_service"
  echo "[HINT] Revisa logs: docker logs ms_storage_service --since 5m"
  exit 1
fi

echo "[OK] MinIO quedo validado: bucket publico, eventos activos y webhook operativo"
