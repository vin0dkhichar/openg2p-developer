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

spar_mapper_healthy() {
  curl -sf "$(spar_mapper_api_url)/docs" >/dev/null 2>&1
}

spar_bene_healthy() {
  curl -sf "http://localhost:${SPAR_BENE_API_PORT}/docs" >/dev/null 2>&1
}

spar_wait_for_mapper() {
  local url="${1:-$(spar_mapper_api_url)}"
  local attempts="${2:-30}"
  echo "Waiting for SPAR mapper API at ${url} ..."
  for ((i = 1; i <= attempts; i++)); do
    if curl -sf "${url}/docs" >/dev/null 2>&1 || curl -sf "${url}/ping" >/dev/null 2>&1; then
      echo "SPAR mapper API is ready."
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for SPAR mapper API at ${url}" >&2
  return 1
}

spar_seed_farmer_links_if_needed() {
  if [[ "${SPAR_AUTO_SEED_FARMER_LINKS:-true}" != "true" ]]; then
    return 0
  fi
  if ! spar_db_migrated; then
    return 0
  fi
  local linked
  linked="$(PGPASSWORD="${SPAR_DB_PASSWORD}" psql \
    -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${SPAR_DB_USER}" -d "${SPAR_DB_NAME}" \
    -tc "SELECT COUNT(*) FROM id_fa_mappings WHERE active = true;" 2>/dev/null | tr -d '[:space:]')"
  if [[ -n "$linked" && "$linked" -gt 0 ]]; then
    echo "[spar-seed] Skipping seed — ${linked} active ID→FA mappings already present."
    return 0
  fi
  bash "${SPAR_DEV_ROOT}/scripts/seed-spar-farmer-links.sh" || true
}

spar_db_migrated() {
  PGPASSWORD="${SPAR_DB_PASSWORD}" psql \
    -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${SPAR_DB_USER}" -d "${SPAR_DB_NAME}" \
    -tc "SELECT to_regclass('public.id_fa_mappings')" 2>/dev/null | grep -q id_fa_mappings
}
