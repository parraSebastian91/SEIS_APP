# Configuración para modo desarrollo
# En producción usar storage backend persistente

ui = true

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
}

storage "file" {
  path = "/vault/data"
}

api_addr = "http://0.0.0.0:8200"
cluster_addr = "https://0.0.0.0:8201"

# Telemetría para Prometheus
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = false
}

# Logs
log_level = "info"
log_format = "json"