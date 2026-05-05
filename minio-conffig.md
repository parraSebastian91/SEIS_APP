# MinIO: configuracion operativa (SEIS_APP)

## Webhook oficial
- Destino unico: `http://ms-storage-service:3100/webhooks/minio`
- Configuracion en infraestructura: `docker-compose-app-imfra.yml`
  - `MINIO_NOTIFY_WEBHOOK_ENABLE_1=on`
  - `MINIO_NOTIFY_WEBHOOK_ENDPOINT_1` (parametrizable)

## Setup automatico por despliegue
El servicio `minio-setup` aplica de forma idempotente:
1. Creacion de bucket si no existe.
2. Politica publica de descarga.
3. Registro de eventos MinIO hacia webhook (`arn:minio:sqs::1:webhook`).
4. CORS para frontends locales.

## Validacion post-deploy
Ejecutar:

```bash
bash scripts/validate-minio-setup.sh
```

O via Makefile:

```bash
make validate-minio
```

La validacion comprueba:
1. Salud de `ms-storage-service`.
2. Existencia de bucket y politica publica.
3. Regla de eventos hacia webhook.
4. Carga real de archivo de prueba y recepcion en logs.