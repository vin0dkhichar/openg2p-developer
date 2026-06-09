SHELL := /bin/bash
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

COMPOSE ?= docker compose
COMPOSE_FILES := \
	-f compose/docker-compose.infra.yml \
	-f compose/docker-compose.pbms.yml \
	-f compose/docker-compose.registry.yml \
	-f compose/docker-compose.bridge.yml \
	-f compose/docker-compose.spar.yml

COMPOSE_PROFILES := --profile infra --profile pbms --profile farmer-registry --profile nsr-registry --profile farmer-registry-seed --profile nsr-registry-seed --profile bridge --profile spar --profile full

.DEFAULT_GOAL := help

.PHONY: help setup clone generate install-odoo install-iam install-awe install-registry-extension install-registry-ui install-registry-db-seed \
	infra-up infra-down up down status logs clean \
	pbms-run farmer-registry-run nsr-registry-run bridge-run spar-run iam-run awe-run \
	farmer-registry-init farmer-registry-migrate farmer-registry-seed \
	nsr-setup nsr-registry-init nsr-registry-migrate nsr-registry-seed seed-registry iam-init awe-init \
	up-infra up-pbms up-farmer-registry up-nsr-registry up-farmer-registry-seed up-nsr-registry-seed up-bridge up-spar up-full

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

install-registry-ui: ## Install npm deps for Gen2 staff portal UI repo(s)
	@bash scripts/install-registry-ui.sh

install-registry-db-seed: ## Install db-seed Python deps (VARIANT=national-social-registry)
	@VARIANT=$(or $(VARIANT),national-social-registry) bash scripts/install-registry-db-seed.sh

install-iam: ## Install IAM staff portal API Python dependencies
	@bash scripts/install-iam.sh

install-awe: ## Install Approval Workflow Engine (AWE) Python dependencies
	@bash scripts/install-awe.sh

iam-init: generate ## Migrate IAM schema and seed login providers
	@bash scripts/init-iam.sh

awe-init: generate ## Initialise AWE schema and registry webhook callback secret
	@bash scripts/init-awe.sh

iam-run: generate ## Run IAM staff portal API natively
	@bash scripts/run-iam.sh

awe-run: generate ## Run AWE API natively
	@bash scripts/run-awe.sh

farmer-registry-init: generate ## Migrate schema and seed Farmer Registry configuration
	@VARIANT=farmer-registry bash scripts/init-registry-variant.sh farmer-registry

farmer-registry-migrate: generate ## Migrate Farmer Registry schema only
	@VARIANT=farmer-registry bash scripts/migrate-registry-db.sh farmer-registry

farmer-registry-seed: generate ## Seed Farmer Registry configuration and optional sample data
	@VARIANT=farmer-registry bash scripts/seed-registry-db.sh farmer-registry

nsr-setup: generate infra-up ## One-time NSR bootstrap: IAM, AWE, migrate, and seed (honours LOAD_SAMPLE_DATA in .env)
	@bash scripts/nsr-setup.sh

nsr-registry-init: generate ## Migrate schema and seed NSR configuration
	@VARIANT=national-social-registry bash scripts/init-registry-variant.sh national-social-registry

nsr-registry-migrate: generate ## Migrate NSR schema only
	@VARIANT=national-social-registry bash scripts/migrate-registry-db.sh national-social-registry

nsr-registry-seed: generate ## Seed NSR configuration and optional sample data
	@VARIANT=national-social-registry bash scripts/seed-registry-db.sh national-social-registry

seed-registry: generate ## Seed a registry variant (VARIANT=farmer-registry|national-social-registry)
	@test -n "$(VARIANT)" || (echo "Set VARIANT=farmer-registry or VARIANT=national-social-registry" >&2; exit 1)
	@VARIANT=$(VARIANT) bash scripts/seed-registry-db.sh $(VARIANT)

infra-up: ## Start shared infrastructure (Postgres, Redis, MinIO, Keycloak)
	@test -f .env || cp .env.example .env
	@bash -c 'set -a; source .env; set +a; $(COMPOSE) $(COMPOSE_FILES) --profile infra up -d'
	@bash -c 'set -a; source .env; set +a; $(COMPOSE) -f compose/docker-compose.infra.yml --profile infra up keycloak-init --abort-on-container-exit' || true
	@bash -c 'set -a; source .env; set +a; \
		echo "Infrastructure started."; \
		echo "  Postgres: localhost:$${POSTGRES_PORT:-5432}"; \
		echo "  Redis:    localhost:$${REDIS_PORT:-6379}"; \
		echo "  MinIO:    http://localhost:9000 (console :9001)"; \
		echo "  Keycloak: http://localhost:8080 (admin/admin by default)"; \
		echo "  Staff realm + OIDC clients are provisioned automatically (see keycloak/README.md)"; \
		echo "  Dev SSO user: staff / staff (override in .env)"'

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

up-farmer-registry-seed: generate infra-up ## Run Farmer Registry db-seed container (after migrate)
	@$(COMPOSE) $(COMPOSE_FILES) --profile farmer-registry-seed up --abort-on-container-exit

up-nsr-registry-seed: generate infra-up ## Run NSR db-seed container (after migrate)
	@$(COMPOSE) $(COMPOSE_FILES) --profile nsr-registry-seed up --abort-on-container-exit

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
