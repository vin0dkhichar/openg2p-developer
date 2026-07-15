#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/bridge.sh"

bridge_load_env
"${ROOT_DIR}/scripts/infra-wait.sh"
"${ROOT_DIR}/scripts/generate-config.sh" >/dev/null
bridge_require_paths

if ! bridge_installed; then
  echo "G2P Bridge venvs missing. Run: make install-bridge" >&2
  exit 1
fi

migrate_service() {
  local dir="$1"
  local env_file="$2"
  local label="$3"

  echo "[bridge-init] Migrating ${label} ..."
  (
    cd "$dir"
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
    # shellcheck disable=SC1091
    source venv/bin/activate
    python main.py migrate
  )
}

migrate_service "$PARTNER_API_DIR" "$PARTNER_API_ENV" "${BRIDGE_DB_NAME} (partner-api)"
migrate_service "$CELERY_WORKERS_DIR" "$CELERY_WORKER_ENV" "${BRIDGE_DB_NAME} (celery-workers)"
migrate_service "$EXAMPLE_BANK_API_DIR" "$EXAMPLE_BANK_ENV" "${EXAMPLE_BANK_DB_NAME} (example-bank)"

echo "[bridge-init] Done."
