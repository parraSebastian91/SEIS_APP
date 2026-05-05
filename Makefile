. PHONY: help up down restart logs build clean vault-init status health validate-minio

# Variables
COMPOSE_FILE = docker-compose-erp.yml

# Colores
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
BLUE   := $(shell tput -Txterm setaf 4)
RESET  := $(shell tput -Txterm sgr0)

help:
	@echo ""
	@echo "$(BLUE)ERP System - Comandos Disponibles$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""

setup:  ## Crear estructura de directorios y archivos
	@echo "$(GREEN)📁 Creando estructura... $(RESET)"
	@bash scripts/deploy-full-stack. sh

up: setup ## Levantar todo el stack
	@echo "$(GREEN)✅ Stack levantado$(RESET)"

down: ## Detener todo el stack
	@echo "$(YELLOW)🛑 Deteniendo stack...$(RESET)"
	docker-compose -f $(COMPOSE_FILE) down
	@echo "$(GREEN)✅ Stack detenido$(RESET)"

restart: ## Reiniciar servicios
	docker-compose -f $(COMPOSE_FILE) restart

status: ## Ver estado de servicios
	@docker-compose -f $(COMPOSE_FILE) ps

health: ## Health check de servicios
	@echo ""
	@echo "$(BLUE)Health Check: $(RESET)"
	@echo "Frontend:        $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/ 2>/dev/null)"
	@echo "Vault:           $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8200/v1/sys/health 2>/dev/null)"
	@echo "Prometheus:     $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:9090/-/healthy 2>/dev/null)"
	@echo "Grafana:        $$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3030/api/health 2>/dev/null)"
	@echo ""

validate-minio: ## Validar setup de MinIO + webhook operativo
	@echo "$(BLUE)Validando MinIO y webhook...$(RESET)"
	@bash scripts/validate-minio-setup.sh

logs: ## Ver logs
	docker-compose -f $(COMPOSE_FILE) logs -f

clean: ## Limpiar todo (incluye volúmenes)
	@echo "$(YELLOW)⚠️  Esto eliminará todos los datos.  ¿Continuar?  [y/N]$(RESET)" && read ans && [ $${ans:-N} = y ]
	docker-compose -f $(COMPOSE_FILE) down -v
	@echo "$(GREEN)✅ Limpieza completada$(RESET)"

.DEFAULT_GOAL := help