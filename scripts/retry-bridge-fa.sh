#!/usr/bin/env bash
# Reset FA resolution ERROR batches to PENDING (run after SPAR is up).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/bridge.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/spar.sh"

bridge_load_env
spar_load_env

if ! curl -sf "$(bridge_spar_mapper_url)/docs" >/dev/null 2>&1; then
  echo "ERROR: SPAR mapper API is not running on port ${SPAR_MAPPER_API_PORT}." >&2
  echo "  Run: make spar-run && make verify-spar" >&2
  exit 1
fi

bridge_retry_fa_resolution_errors

PGPASSWORD="${POSTGRES_PASSWORD}" psql \
  -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U postgres -d "${BRIDGE_DB_NAME}" \
  -c "SELECT fa_resolution_status, COUNT(*) FROM disbursement_batch_control GROUP BY fa_resolution_status ORDER BY fa_resolution_status;"
