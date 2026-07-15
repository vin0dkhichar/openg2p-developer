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

if [[ "${SPAR_AUTO_SEED_FARMER_LINKS:-true}" == "true" ]]; then
  bash "${ROOT_DIR}/scripts/seed-spar-farmer-links.sh" || true
fi

run_service "spar-mapper-api" "$MAPPER_API_DIR" "$MAPPER_API_ENV" \
  python main.py run

run_service "spar-bene-api" "$BENE_API_DIR" "$BENE_API_ENV" \
  python main.py run

echo "SPAR started."
echo "  Mapper API : $(spar_mapper_api_url)/docs"
echo "  Bene API   : http://localhost:${SPAR_BENE_API_PORT}/docs"
