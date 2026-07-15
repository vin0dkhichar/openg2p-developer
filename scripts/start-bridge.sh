#!/usr/bin/env bash
# Start G2P Bridge stack in the background (partner API, Celery, example bank).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/bridge.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/run-service.sh"

bridge_load_env
bridge_require_paths

bridge_free_ports

if ! bridge_installed; then
  echo "Installing G2P Bridge dependencies (first run) ..."
  bash "${ROOT_DIR}/scripts/install-bridge.sh"
fi

if ! bridge_db_migrated; then
  bash "${ROOT_DIR}/scripts/init-bridge.sh"
fi

run_service "g2p-bridge-partner-api" "$PARTNER_API_DIR" "$PARTNER_API_ENV" \
  python main.py run

bridge_wait_for_api

run_service "g2p-bridge-celery-worker" "$CELERY_WORKERS_DIR" "$CELERY_WORKER_ENV" \
  bash -c 'exec celery -A main.celery_app worker -Q g2p_bridge_queue -l info --concurrency="${G2P_BRIDGE_CELERY_CONCURRENCY:-2}"'

run_service "g2p-bridge-celery-beat" "$CELERY_BEAT_DIR" "$CELERY_BEAT_ENV" \
  bash -c 'exec celery -A main.celery_app beat -l info --schedule "/tmp/celery-beat-g2p-bridge-${G2P_BRIDGE_CELERY_BEAT_DB_DBNAME:-g2pbridgedb}.db"'

run_service "g2p-bridge-example-bank" "$EXAMPLE_BANK_API_DIR" "$EXAMPLE_BANK_ENV" \
  python main.py run

echo "G2P Bridge started."
echo "  Partner API  : $(bridge_partner_api_url)/docs"
echo "  Example bank : $(bridge_example_bank_url)/docs"
echo "  SPAR resolve : $(bridge_spar_mapper_resolve_url) (requires SPAR mapper on :${SPAR_MAPPER_API_PORT})"
