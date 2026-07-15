SHELL := /bin/bash
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

COMPOSE ?= docker compose
COMPOSE_FILES := \
	-f compose/docker-compose.infra.yml \
	-f compose/docker-compose.pbms.yml \
	-f compose/docker-compose.registry.yml \
	-f compose/docker-compose.bridge.yml \
	-f compose/docker-compose.spar.yml

COMPOSE_PROFILES := --profile infra --profile with-redis --profile pbms --profile farmer-registry --profile nsr-registry --profile farmer-registry-seed --profile nsr-registry-seed --profile bridge --profile spar --profile full

.DEFAULT_GOAL := help

.PHONY: help setup clone generate install-odoo install-iam install-awe install-registry-extension install-registry-ui install-registry-db-seed install-pbms-bg-tasks install-bridge install-spar \
	infra-ensure infra-up keycloak-init infra-down up down status logs clean \
	pbms-setup pbms-full-setup pbms-init init-pbms-bg-tasks init-bridge init-spar seed-spar-farmer-links \
	pbms-run pbms-stop free-native-stack free-spar-ports \
	start-pbms-bg-tasks start-spar start-bridge \
	verify-native-stack verify-pbms verify-registry verify-bridge verify-spar retry-bridge-fa \
	farmer-registry-run nsr-registry-run bridge-run spar-run iam-run awe-run \
	farmer-setup farmer-registry-init farmer-registry-migrate farmer-registry-seed farmer-registry-fix-seed-enums farmer-registry-validate-seed \
	nsr-setup nsr-registry-init nsr-registry-migrate nsr-registry-seed seed-registry iam-init awe-init \
	extension-package extension-setup extension-run extension-init extension-migrate extension-seed clone-profiles \
	up-infra up-pbms up-farmer-registry up-nsr-registry up-farmer-registry-seed up-nsr-registry-seed up-bridge up-spar up-full

help: ## Show available targets
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'

setup: clone generate ## Clone repos (PROFILE=registry) and generate local configs
	@echo "Setup complete (profile: $(or $(PROFILE),registry)). Next: make infra-up"

clone: ## Clone product repos for a profile (PROFILE=registry|national-social-registry|farmer-registry|pbms|bridge|spar|full)
	@bash scripts/clone-repos.sh "$(or $(PROFILE),registry)"

clone-profiles: ## List available clone/setup profiles
	@bash -c 'source scripts/lib/clone-profiles.sh; clone_profile_list'

generate: ## Generate Odoo conf and service env files from templates
	@bash scripts/generate-config.sh

install-odoo: ## Install Odoo 17 Python dependencies into a venv
	@bash scripts/install-odoo-deps.sh

install-pbms-bg-tasks: ## Install PBMS staff portal API and Celery Python dependencies
	@bash scripts/install-pbms-bg-tasks.sh

install-bridge: ## Install G2P Bridge partner API, Celery, and example bank Python dependencies
	@bash scripts/install-bridge.sh

install-spar: ## Install SPAR mapper and bene portal API Python dependencies
	@bash scripts/install-spar.sh

install-registry-extension: ## Install domain extension (VARIANT=farmer-registry|national-social-registry)
	@bash scripts/install-registry-extension.sh $(VARIANT)

install-registry-ui: ## Install npm deps for Gen2 staff portal UI repo(s)
	@bash scripts/install-registry-ui.sh

install-registry-db-seed: ## Install db-seed Python deps (VARIANT=farmer-registry|national-social-registry|custom)
	@test -n "$(VARIANT)" || (echo "Set VARIANT to your registry slug (e.g. disability-registry)" >&2; exit 1)
	@bash scripts/install-registry-db-seed.sh $(VARIANT)

install-iam: ## Install IAM staff portal API Python dependencies
	@bash scripts/install-iam.sh

install-awe: ## Install Approval Workflow Engine (AWE) Python dependencies
	@bash scripts/install-awe.sh

iam-init: generate ## Migrate IAM schema, seed login providers, and sync variant registry applications
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

farmer-registry-fix-seed-enums: ## Fix legacy farmer seed enum values in DB (source_of_income etc.)
	@bash scripts/fix-farmer-registry-seeded-enums.sh

farmer-registry-validate-seed: ## Validate farmer seed/DB data against extension schemas
	@bash scripts/validate-farmer-registry-seed.sh

farmer-setup: generate infra-up ## One-time Farmer Registry bootstrap: IAM, AWE, migrate, and seed (honours LOAD_SAMPLE_DATA in .env)
	@bash scripts/farmer-setup.sh

nsr-setup: generate infra-up ## One-time NSR bootstrap: IAM, AWE, migrate, and seed (honours LOAD_SAMPLE_DATA in .env)
	@bash scripts/nsr-setup.sh

nsr-registry-init: generate ## Migrate schema and seed NSR configuration
	@VARIANT=national-social-registry bash scripts/init-registry-variant.sh national-social-registry

nsr-registry-migrate: generate ## Migrate NSR schema only
	@VARIANT=national-social-registry bash scripts/migrate-registry-db.sh national-social-registry

nsr-registry-seed: generate ## Seed NSR configuration and optional sample data
	@VARIANT=national-social-registry bash scripts/seed-registry-db.sh national-social-registry

seed-registry: generate ## Seed a registry variant (VARIANT=farmer-registry|national-social-registry|custom)
	@test -n "$(VARIANT)" || (echo "Set VARIANT to your registry slug" >&2; exit 1)
	@VARIANT=$(VARIANT) bash scripts/seed-registry-db.sh $(VARIANT)

extension-package: ## Bootstrap empty extension product (NAME=disability-registry, optional REPO_URL=, SETUP=1)
	@bash scripts/bootstrap-extension-package.sh "$(NAME)" "$(REPO_URL)"

extension-setup: generate infra-up ## One-time setup for custom extension (NAME=disability-registry)
	@test -n "$(NAME)" || (echo "Set NAME=your-extension-slug (same as extension-package)" >&2; exit 1)
	@bash scripts/registry-setup.sh "$(NAME)"

extension-init: generate ## Migrate + seed custom extension configuration (NAME=disability-registry)
	@test -n "$(NAME)" || (echo "Set NAME=your-extension-slug" >&2; exit 1)
	@VARIANT=$(NAME) bash scripts/init-registry-variant.sh "$(NAME)"

extension-migrate: generate ## Migrate custom extension schema only (NAME=disability-registry)
	@test -n "$(NAME)" || (echo "Set NAME=your-extension-slug" >&2; exit 1)
	@VARIANT=$(NAME) bash scripts/migrate-registry-db.sh "$(NAME)"

extension-seed: generate ## Seed custom extension configuration (NAME=disability-registry)
	@test -n "$(NAME)" || (echo "Set NAME=your-extension-slug" >&2; exit 1)
	@VARIANT=$(NAME) bash scripts/seed-registry-db.sh "$(NAME)"

extension-run: generate ## Run custom extension natively (NAME=disability-registry)
	@test -n "$(NAME)" || (echo "Set NAME=your-extension-slug" >&2; exit 1)
	@bash scripts/run-registry-variant.sh "$(NAME)"

infra-ensure: ## Start infra containers if stopped (no Keycloak provisioning)
	@test -f .env || cp .env.example .env
	@bash -c 'set -a; source .env; set +a; \
		profiles=(--profile infra); \
		if [[ "$${USE_EXTERNAL_REDIS:-false}" != "true" ]]; then profiles+=(--profile with-redis); fi; \
		$(COMPOSE) $(COMPOSE_FILES) "$${profiles[@]}" up -d'

keycloak-init: infra-ensure ## Provision Keycloak staff realm and OIDC clients
	@bash -c 'set -a; source .env; set +a; $(COMPOSE) -f compose/docker-compose.infra.yml --profile infra up keycloak-init --abort-on-container-exit' || true

infra-up: infra-ensure keycloak-init ## Start shared infrastructure (Postgres, Redis, MinIO, Keycloak)
	@bash -c 'set -a; source .env; set +a; \
		echo "Infrastructure started."; \
		echo "  Postgres: localhost:$${POSTGRES_PORT:-5432}"; \
		if [[ "$${USE_EXTERNAL_REDIS:-false}" == "true" ]]; then \
			echo "  Redis:    external ($${REDIS_HOST:-localhost}:$${REDIS_PORT:-6379})"; \
		else \
			echo "  Redis:    localhost:$${REDIS_PORT:-6379} (Docker)"; \
		fi; \
		echo "  MinIO:    http://localhost:9000 (console :9001)"; \
		echo "  Keycloak: http://localhost:8080 (admin/admin by default)"; \
		echo "  Staff realm + OIDC clients are provisioned automatically (see keycloak/README.md)"; \
		echo "  Dev SSO user: staff / staff (override in .env)"; \
		echo "  Re-provision Keycloak only: make keycloak-init"'

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

pbms-setup: ## One-time PBMS bootstrap (infra, deps, registry, Odoo + bg-task DBs)
	@bash scripts/pbms-setup.sh

pbms-full-setup: ## One-time PBMS + SPAR + Bridge bootstrap (disbursement-ready)
	@bash scripts/pbms-full-setup.sh

pbms-init: generate ## Bootstrap pbmsdb with Odoo base modules (first-time only)
	@bash scripts/init-pbms.sh

init-pbms-bg-tasks: generate ## Migrate bgtaskdb schema for PBMS background tasks
	@bash scripts/init-pbms-bg-tasks.sh

init-bridge: generate ## Migrate g2pbridgedb and examplebankdb for G2P Bridge
	@bash scripts/init-bridge.sh

init-spar: generate ## Migrate spardb and seed SPAR strategies
	@bash scripts/init-spar.sh

seed-spar-farmer-links: ## Link farmer registry internal_record_id → bank account in SPAR
	@bash scripts/seed-spar-farmer-links.sh

pbms-run: ## Run PBMS + registry + Odoo (does not start SPAR or Bridge)
	@bash scripts/run-pbms.sh

start-pbms-bg-tasks: generate ## Start PBMS staff API + Celery only
	@bash scripts/start-pbms-bg-tasks.sh

start-bridge: generate ## Start G2P Bridge only (run start-spar first for FA resolution)
	@bash scripts/run-bridge.sh

free-spar-ports: ## Stop SPAR processes only (leave PBMS/Bridge running)
	@bash scripts/free-spar-ports.sh

free-native-stack: ## Stop all native PBMS/registry/bridge/spar processes (clean restart)
	@bash scripts/free-native-stack.sh

pbms-stop: free-native-stack ## Stop full native stack (Celery, APIs, Odoo) — does not stop Docker infra

verify-native-stack: ## Verify pbms+registry (pass COMPONENTS=spar bridge pbms registry)
	@bash scripts/verify-native-stack.sh $(COMPONENTS)

verify-pbms: ## Verify PBMS Celery only
	@bash scripts/verify-native-stack.sh pbms

verify-registry: ## Verify registry Celery only
	@bash scripts/verify-native-stack.sh registry

verify-bridge: ## Verify Bridge Celery only
	@bash scripts/verify-native-stack.sh bridge

verify-spar: ## Verify SPAR mapper API only
	@bash scripts/verify-native-stack.sh spar

retry-bridge-fa: ## Reset FA ERROR batches to PENDING (requires SPAR running)
	@bash scripts/retry-bridge-fa.sh

farmer-registry-run: generate ## Run Farmer Registry Gen2 natively
	@bash scripts/run-registry-variant.sh farmer-registry

nsr-registry-run: generate ## Run National Social Registry Gen2 natively
	@bash scripts/run-registry-variant.sh national-social-registry

bridge-run: generate ## Alias for start-bridge
	@bash scripts/run-bridge.sh

start-spar: ## Start SPAR (no config regen)
	@bash scripts/run-spar.sh

spar-run: generate start-spar ## Regenerate config then start SPAR
