#!/usr/bin/env bash
# Start SPAR only (mapper + bene portal). Does not start or stop Bridge/PBMS.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/spar.sh"
spar_load_env

if spar_mapper_healthy && spar_bene_healthy; then
  echo "SPAR already running."
  echo "  Mapper : $(spar_mapper_api_url)/docs"
  echo "  Bene   : http://localhost:${SPAR_BENE_API_PORT}/docs"
  exit 0
fi

echo "Starting SPAR ..."
bash "${ROOT_DIR}/scripts/free-spar-ports.sh"
bash "${ROOT_DIR}/scripts/start-spar.sh"

if ! spar_mapper_healthy; then
  echo "ERROR: SPAR mapper API did not come up on port ${SPAR_MAPPER_API_PORT}." >&2
  echo "  Check: tail -30 generated/run/spar-mapper-api.log" >&2
  exit 1
fi

echo
echo "SPAR started in background (this command exits; SPAR keeps running)."
echo "  Logs   : generated/run/spar-mapper-api.log"
echo "  Verify : make verify-spar"
