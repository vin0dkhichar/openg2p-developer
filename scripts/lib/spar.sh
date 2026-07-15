#!/usr/bin/env bash
# Paths and helpers for native SPAR (mapper + bene portal APIs).

spar_load_env() {
  SPAR_DEV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  cd "$SPAR_DEV_ROOT"

  if [[ -f .env ]]; then
    # shellcheck disable=SC1091
    source .env
  fi

  OPENG2P_WORKSPACE="${OPENG2P_WORKSPACE:-../openg2p-workspace}"
  OPENG2P_WORKSPACE="$(cd "$SPAR_DEV_ROOT" && cd "$OPENG2P_WORKSPACE" && pwd)"
  SPAR_ROOT="${OPENG2P_WORKSPACE}/spar"
  GENERATED_DIR="${SPAR_DEV_ROOT}/generated/spar"

  SPAR_MAPPER_API_PORT="${SPAR_MAPPER_API_PORT:-8004}"
  SPAR_BENE_API_PORT="${SPAR_BENE_API_PORT:-8005}"
  SPAR_DB_NAME="${SPAR_DB_NAME:-spardb}"
  SPAR_DB_USER="${SPAR_DB_USER:-sparuser}"
  SPAR_DB_PASSWORD="${SPAR_DB_PASSWORD:-password}"
  SPAR_BANK_STRATEGY_ID="${SPAR_BANK_STRATEGY_ID:-5}"
  SPAR_EXAMPLE_BANK_CODE="${SPAR_EXAMPLE_BANK_CODE:-EXAMPLE-BANK}"
  SPAR_EXAMPLE_BRANCH_CODE="${SPAR_EXAMPLE_BRANCH_CODE:-MAIN}"
  SPAR_REGISTRY_DB_NAME="${SPAR_REGISTRY_DB_NAME:-farmer_registry_db}"

  POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
  POSTGRES_PORT="${POSTGRES_PORT:-5432}"
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"

  MODELS_DIR="${SPAR_ROOT}/core/models"
  MAPPER_CORE_DIR="${SPAR_ROOT}/core/mapper-core"
  MAPPER_API_DIR="${SPAR_ROOT}/core/mapper-partner-api"
  BENE_API_DIR="${SPAR_ROOT}/core/bene-portal-api"

  MAPPER_API_ENV="${GENERATED_DIR}/mapper-partner-api.env"
  BENE_API_ENV="${GENERATED_DIR}/bene-portal-api.env"
}

spar_require_paths() {
  local missing=0
  for path in "$SPAR_ROOT" "$MODELS_DIR" "$MAPPER_CORE_DIR" "$MAPPER_API_DIR" "$BENE_API_DIR"; do
    if [[ ! -d "$path" ]]; then
      echo "Missing ${path}. Run: make clone PROFILE=spar" >&2
      missing=1
    fi
  done
  for env_file in "$MAPPER_API_ENV" "$BENE_API_ENV"; do
    if [[ ! -f "$env_file" ]]; then
      echo "Missing ${env_file}. Run: make generate" >&2
      missing=1
    fi
  done
  return "$missing"
}

spar_installed() {
  [[ -x "${MAPPER_API_DIR}/venv/bin/python" ]] \
    && [[ -x "${BENE_API_DIR}/venv/bin/python" ]]
}

spar_mapper_api_url() {
  echo "http://localhost:${SPAR_MAPPER_API_PORT}"
}

spar_db_migrated() {
  PGPASSWORD="${SPAR_DB_PASSWORD}" psql \
    -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${SPAR_DB_USER}" -d "${SPAR_DB_NAME}" \
    -tc "SELECT to_regclass('public.id_fa_mappings')" 2>/dev/null | grep -q id_fa_mappings
}
