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

if [[ "${BRIDGE_REQUIRE_SPAR:-true}" == "true" ]]; then
  bridge_wait_for_spar_mapper
elif ! curl -sf "$(bridge_spar_mapper_url)/docs" >/dev/null 2>&1; then
  echo "WARN: SPAR mapper API is not up on port ${SPAR_MAPPER_API_PORT}."
  echo "      FA resolution will fail until you run: make spar-run"
fi

bridge_free_ports

if ! bridge_installed; then
  echo "Installing G2P Bridge dependencies (first run) ..."
  bash "${ROOT_DIR}/scripts/install-bridge.sh"
fi

if ! bridge_db_migrated; then
  bash "${ROOT_DIR}/scripts/init-bridge.sh"
fi

BRIDGE_BEAT_TOKEN="${BRIDGE_DB_NAME:-g2pbridgedb}"
run_service_stop_celery_beats "${BRIDGE_BEAT_TOKEN}"
run_service_stop "g2p-bridge-partner-api" "g2p-bridge/core/partner-api" "main:app"
run_service_stop "g2p-bridge-celery-worker" "g2p-bridge/core/celery-workers.*g2p_bridge_queue" "${CELERY_WORKERS_DIR}"
run_service_stop "g2p-bridge-celery-beat" "g2p-bridge/core/celery-beat-producers.*celery_app beat" "celery-beat-g2p-bridge" "${CELERY_BEAT_DIR}"
run_service_stop "g2p-bridge-celery-beat-worker" "g2p-bridge/core/celery-beat-producers.*worker -Q celery" "${CELERY_BEAT_DIR}"
run_service_stop "g2p-bridge-example-bank" "openg2p-example-bank-api" "${EXAMPLE_BANK_API_DIR}"

run_service "g2p-bridge-partner-api" "$PARTNER_API_DIR" "$PARTNER_API_ENV" \
  python main.py run

bridge_wait_for_api

run_service "g2p-bridge-celery-worker" "$CELERY_WORKERS_DIR" "$CELERY_WORKER_ENV" \
  bash -c 'exec celery -A main.celery_app worker -Q g2p_bridge_queue -l info --concurrency="${G2P_BRIDGE_CELERY_CONCURRENCY:-2}"'
run_service_verify "g2p-bridge-celery-worker"

# Beat scheduler + worker for beat-producer tasks (mapper_resolution_beat_producer, etc.).
# Helm uses `worker --beat`; we split so only one beat owns the schedule file (see PBMS).
run_service "g2p-bridge-celery-beat" "$CELERY_BEAT_DIR" "$CELERY_BEAT_ENV" \
  bash -c 'exec celery -A main.celery_app beat -l info --schedule "/tmp/celery-beat-g2p-bridge-${G2P_BRIDGE_CELERY_BEAT_DB_DBNAME:-g2pbridgedb}.db"'
run_service_verify "g2p-bridge-celery-beat"

run_service "g2p-bridge-celery-beat-worker" "$CELERY_BEAT_DIR" "$CELERY_BEAT_ENV" \
  bash -c 'exec celery -A main.celery_app worker -Q celery -l info --concurrency=1'
run_service_verify "g2p-bridge-celery-beat-worker"

if curl -sf "$(bridge_spar_mapper_url)/docs" >/dev/null 2>&1; then
  bridge_retry_fa_resolution_errors
fi

run_service "g2p-bridge-example-bank" "$EXAMPLE_BANK_API_DIR" "$EXAMPLE_BANK_ENV" \
  python main.py run
run_service_verify "g2p-bridge-example-bank"

run_service_assert_single "Bridge Celery beat" "g2p-bridge/core/celery-beat-producers.*celery_app beat" 1

echo "G2P Bridge started."
echo "  Partner API  : $(bridge_partner_api_url)/docs"
echo "  Example bank : $(bridge_example_bank_url)/docs"
echo "  SPAR resolve : $(bridge_spar_mapper_resolve_url) (requires SPAR mapper on :${SPAR_MAPPER_API_PORT})"
