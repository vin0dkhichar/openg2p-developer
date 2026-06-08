SHELL := /bin/bash
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

COMPOSE ?= docker compose
COMPOSE_FILES := \
	-f compose/docker-compose.infra.yml \
	-f compose/docker-compose.pbms.yml \
	-f compose/docker-compose.registry.yml \
	-f compose/docker-compose.bridge.yml \
	-f compose/docker-compose.spar.yml

COMPOSE_PROFILES := --profile infra --profile pbms --profile farmer-registry --profile nsr-registry --profile bridge --profile spar --profile full

.DEFAULT_GOAL := help

.PHONY: help setup clone generate install-odoo install-registry-extension infra-up infra-down up down status logs clean \
	pbms-run farmer-registry-run nsr-registry-run bridge-run spar-run \
	up-infra up-pbms up-farmer-registry up-nsr-registry up-bridge up-spar up-full

help: ## Show available targets
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'

setup: clone generate ## Clone repos and generate local configs
	@echo "Setup complete. Next: make infra-up"

clone: ## Clone/update OpenG2P product repositories
	@bash scripts/clone-repos.sh

generate: ## Generate Odoo conf and service env files from templates
	@bash scripts/generate-config.sh

install-odoo: ## Install Odoo 17 Python dependencies into a venv
	@bash scripts/install-odoo-deps.sh

install-registry-extension: ## Install domain extension (VARIANT=farmer-registry|national-social-registry)
	@bash scripts/install-registry-extension.sh $(VARIANT)

infra-up: ## Start shared infrastructure (Postgres, Redis, MinIO, Keycloak)
	@test -f .env || cp .env.example .env
	@$(COMPOSE) $(COMPOSE_FILES) --profile infra up -d
	@echo "Infrastructure started."
	@echo "  Postgres: localhost:$${POSTGRES_PORT:-5432}"
	@echo "  Redis:    localhost:$${REDIS_PORT:-6379}"
	@echo "  MinIO:    http://localhost:9000 (console :9001)"
	@echo "  Keycloak: http://localhost:8080 (admin/admin by default)"

infra-down: ## Stop shared infrastructure
	@$(COMPOSE) $(COMPOSE_FILES) --profile infra down

up: infra-up ## Alias for infra-up

down: ## Stop all compose services
	@$(COMPOSE) $(COMPOSE_FILES) $(COMPOSE_PROFILES) down

status: ## Show compose service status
	@$(COMPOSE) $(COMPOSE_FILES) ps

logs: ## Tail infrastructure logs
	@$(COMPOSE) $(COMPOSE_FILES) --profile infra logs -f

clean: ## Stop services and remove volumes (destructive)
	@$(COMPOSE) $(COMPOSE_FILES) $(COMPOSE_PROFILES) down -v

up-infra: infra-up ## Start only shared infrastructure

up-pbms: infra-up ## Start infra + containerized PBMS image
	@$(COMPOSE) $(COMPOSE_FILES) --profile pbms up -d

up-farmer-registry: generate infra-up ## Start infra + containerized Farmer Registry
	@$(COMPOSE) $(COMPOSE_FILES) --profile farmer-registry up -d

up-nsr-registry: generate infra-up ## Start infra + containerized National Social Registry
	@$(COMPOSE) $(COMPOSE_FILES) --profile nsr-registry up -d

up-bridge: generate infra-up ## Start infra + containerized G2P Bridge (if images exist)
	@$(COMPOSE) $(COMPOSE_FILES) --profile bridge up -d

up-spar: infra-up ## Start infra for SPAR native development
	@echo "SPAR runs natively. Use: make spar-run"

up-full: generate infra-up ## Start infra + all container profiles
	@$(COMPOSE) $(COMPOSE_FILES) --profile full up -d

pbms-run: generate ## Run PBMS Odoo natively (recommended for development)
	@bash scripts/run-pbms.sh

farmer-registry-run: generate ## Run Farmer Registry Gen2 natively
	@bash scripts/run-registry-variant.sh farmer-registry

nsr-registry-run: generate ## Run National Social Registry Gen2 natively
	@bash scripts/run-registry-variant.sh national-social-registry

bridge-run: generate ## Run G2P Bridge services natively
	@bash scripts/run-bridge.sh

spar-run: generate ## Run SPAR APIs natively
	@bash scripts/run-spar.sh
