#!/usr/bin/env bash
# Start SPAR APIs in the background (mapper partner + bene portal).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/spar.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/run-service.sh"

spar_load_env
spar_require_paths

if ! spar_installed; then
  echo "Installing SPAR dependencies (first run) ..."
  bash "${ROOT_DIR}/scripts/install-spar.sh"
fi

if ! spar_db_migrated; then
  bash "${ROOT_DIR}/scripts/init-spar.sh"
fi

spar_seed_farmer_links_if_needed

run_service_stop "spar-mapper-api" "uvicorn main:app.*--port ${SPAR_MAPPER_API_PORT}" "spar/core/mapper-partner-api" "${MAPPER_API_DIR}"
run_service_stop "spar-bene-api" "uvicorn main:app.*--port ${SPAR_BENE_API_PORT}" "spar/core/bene-portal-api" "${BENE_API_DIR}"

# Exec uvicorn directly — `python main.py run` uses subprocess.run() and the parent
# process receives SIGTERM when anything stops/restarts SPAR, killing uvicorn too.
run_service "spar-mapper-api" "$MAPPER_API_DIR" "$MAPPER_API_ENV" \
  uvicorn main:app --workers 1 --host 0.0.0.0 --port "${SPAR_MAPPER_API_PORT}"
run_service_verify "spar-mapper-api" "" 3
run_service_record_port "spar-mapper-api" "${SPAR_MAPPER_API_PORT}"

spar_wait_for_mapper

run_service "spar-bene-api" "$BENE_API_DIR" "$BENE_API_ENV" \
  uvicorn main:app --workers 1 --host 0.0.0.0 --port "${SPAR_BENE_API_PORT}"
run_service_verify "spar-bene-api" "" 3
run_service_record_port "spar-bene-api" "${SPAR_BENE_API_PORT}"

echo "SPAR started."
echo "  Mapper API : $(spar_mapper_api_url)/docs"
echo "  Bene API   : http://localhost:${SPAR_BENE_API_PORT}/docs"
