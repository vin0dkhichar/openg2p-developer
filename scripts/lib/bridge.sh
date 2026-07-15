#!/usr/bin/env bash
# Paths and helpers for native G2P Bridge (partner API + Celery + example bank).

bridge_load_env() {
  BRIDGE_DEV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  cd "$BRIDGE_DEV_ROOT"

  if [[ -f .env ]]; then
    # shellcheck disable=SC1091
    source .env
  fi

  OPENG2P_WORKSPACE="${OPENG2P_WORKSPACE:-../openg2p-workspace}"
  OPENG2P_WORKSPACE="$(cd "$BRIDGE_DEV_ROOT" && cd "$OPENG2P_WORKSPACE" && pwd)"
  BRIDGE_ROOT="${OPENG2P_WORKSPACE}/g2p-bridge"
  GENERATED_DIR="${BRIDGE_DEV_ROOT}/generated/bridge"

  G2P_BRIDGE_API_PORT="${G2P_BRIDGE_API_PORT:-8002}"
  G2P_BRIDGE_EXAMPLE_BANK_PORT="${G2P_BRIDGE_EXAMPLE_BANK_PORT:-8003}"
  G2P_BRIDGE_REDIS_DB="${G2P_BRIDGE_REDIS_DB:-2}"
  EXAMPLE_BANK_REDIS_DB="${EXAMPLE_BANK_REDIS_DB:-3}"
  SPAR_MAPPER_API_PORT="${SPAR_MAPPER_API_PORT:-8004}"

  POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
  POSTGRES_PORT="${POSTGRES_PORT:-5432}"
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
  REDIS_HOST="${REDIS_HOST:-localhost}"
  REDIS_PORT="${REDIS_PORT:-6379}"

  BRIDGE_DB_NAME="${BRIDGE_DB_NAME:-g2pbridgedb}"
  EXAMPLE_BANK_DB_NAME="${EXAMPLE_BANK_DB_NAME:-examplebankdb}"

  MODELS_DIR="${BRIDGE_ROOT}/core/models"
  PARTNER_API_DIR="${BRIDGE_ROOT}/core/partner-api"
  CELERY_BEAT_DIR="${BRIDGE_ROOT}/core/celery-beat-producers"
  CELERY_WORKERS_DIR="${BRIDGE_ROOT}/core/celery-workers"
  EXAMPLE_BANK_API_DIR="${BRIDGE_ROOT}/example-bank/openg2p-example-bank-api"
  EXAMPLE_BANK_MODELS_DIR="${BRIDGE_ROOT}/example-bank/openg2p-example-bank-models"

  EXTENSIONS_DIR="${BRIDGE_ROOT}/extensions"
  BANK_CONNECTORS_DIR="${EXTENSIONS_DIR}/bank-connectors"
  MAPPER_CONNECTORS_DIR="${EXTENSIONS_DIR}/mapper-connectors"
  GEO_RESOLVER_DIR="${EXTENSIONS_DIR}/geo-resolver"
  WAREHOUSE_ALLOCATOR_DIR="${EXTENSIONS_DIR}/warehouse-allocator"
  AGENCY_ALLOCATOR_DIR="${EXTENSIONS_DIR}/agency-allocator"
  NOTIFICATION_CONNECTORS_DIR="${EXTENSIONS_DIR}/notification-connectors"

  PARTNER_API_ENV="${GENERATED_DIR}/partner-api.env"
  CELERY_BEAT_ENV="${GENERATED_DIR}/celery-beat.env"
  CELERY_WORKER_ENV="${GENERATED_DIR}/celery-worker.env"
  EXAMPLE_BANK_ENV="${GENERATED_DIR}/example-bank.env"
}

bridge_require_paths() {
  local missing=0
  for path in "$BRIDGE_ROOT" "$MODELS_DIR" "$PARTNER_API_DIR" "$CELERY_BEAT_DIR" \
    "$CELERY_WORKERS_DIR" "$EXAMPLE_BANK_API_DIR" "$MAPPER_CONNECTORS_DIR" \
    "$BANK_CONNECTORS_DIR"; do
    if [[ ! -d "$path" ]]; then
      echo "Missing ${path}. Run: make clone PROFILE=bridge" >&2
      missing=1
    fi
  done
  for env_file in "$PARTNER_API_ENV" "$CELERY_BEAT_ENV" "$CELERY_WORKER_ENV" "$EXAMPLE_BANK_ENV"; do
    if [[ ! -f "$env_file" ]]; then
      echo "Missing ${env_file}. Run: make generate" >&2
      missing=1
    fi
  done
  return "$missing"
}

bridge_installed() {
  [[ -x "${PARTNER_API_DIR}/venv/bin/python" ]] \
    && [[ -x "${CELERY_WORKERS_DIR}/venv/bin/python" ]] \
    && [[ -x "${CELERY_BEAT_DIR}/venv/bin/python" ]] \
    && [[ -x "${EXAMPLE_BANK_API_DIR}/venv/bin/python" ]]
}

bridge_partner_api_url() {
  echo "http://localhost:${G2P_BRIDGE_API_PORT}"
}

bridge_example_bank_url() {
  echo "http://localhost:${G2P_BRIDGE_EXAMPLE_BANK_PORT}"
}

bridge_spar_mapper_resolve_url() {
  echo "http://localhost:${SPAR_MAPPER_API_PORT}/mapper/resolve"
}

bridge_db_migrated() {
  PGPASSWORD="${POSTGRES_PASSWORD}" psql \
    -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U postgres -d "${BRIDGE_DB_NAME}" \
    -tc "SELECT to_regclass('public.disbursement_envelope')" 2>/dev/null | grep -q disbursement_envelope
}

bridge_wait_for_api() {
  local url="${1:-$(bridge_partner_api_url)}"
  local attempts="${2:-30}"
  echo "Waiting for G2P Bridge partner API at ${url} ..."
  for ((i = 1; i <= attempts; i++)); do
    if curl -sf "${url}/docs" >/dev/null 2>&1 || curl -sf "${url}/ping" >/dev/null 2>&1; then
      echo "G2P Bridge partner API is ready."
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for G2P Bridge partner API at ${url}" >&2
  return 1
}

bridge_free_ports() {
  free_port() {
    local port="$1"
    local label="$2"
    local pids=""
    if command -v lsof >/dev/null 2>&1; then
      pids="$(lsof -tiTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true)"
    fi
    if [[ -z "$pids" ]]; then
      return 0
    fi
    echo "Stopping ${label} (port ${port}) ..."
    # shellcheck disable=SC2086
    kill $pids 2>/dev/null || true
    sleep 1
  }

  stop_matching_processes() {
    local label="$1"
    local pattern="$2"
    local pids
    pids="$(pgrep -f "$pattern" 2>/dev/null || true)"
    if [[ -z "$pids" ]]; then
      return 0
    fi
    echo "Stopping ${label} ..."
    # shellcheck disable=SC2086
    kill $pids 2>/dev/null || true
    sleep 1
  }

  free_port "${G2P_BRIDGE_API_PORT}" "G2P Bridge partner API"
  free_port "${G2P_BRIDGE_EXAMPLE_BANK_PORT}" "Example bank API"
  stop_matching_processes "G2P Bridge Celery worker" "celery -A main.celery_app worker -Q g2p_bridge_queue"
  stop_matching_processes "G2P Bridge Celery beat" "celery -A main.celery_app beat"
  stop_matching_processes "G2P Bridge Celery beat" "celery-beat-g2p-bridge"
  pkill -f "g2p-bridge/core/partner-api.*main.py run" 2>/dev/null || true
  pkill -f "openg2p-example-bank-api.*main.py run" 2>/dev/null || true
  sleep 1
  rm -f /tmp/celery-beat-g2p-bridge-*.db 2>/dev/null || true
}
