#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_SUPERUSER="${POSTGRES_SUPERUSER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
AWE_API_PORT="${AWE_API_PORT:-8030}"

"${ROOT_DIR}/scripts/infra-wait.sh"
"${ROOT_DIR}/scripts/generate-config.sh" >/dev/null

if ! PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_SUPERUSER}" -d postgres -tc \
  "SELECT 1 FROM pg_database WHERE datname = 'awe'" | grep -q 1; then
  echo "[awe-init] Creating database awe ..."
  PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_SUPERUSER}" -d postgres \
    -c "CREATE DATABASE awe OWNER postgres"
fi

started_temp=false
if ! curl -sf "http://localhost:${AWE_API_PORT}/v1/awe/health" >/dev/null 2>&1; then
  echo "[awe-init] Starting AWE temporarily to create schema ..."
  bash "${ROOT_DIR}/scripts/run-awe.sh" >/tmp/openg2p-awe-init.log 2>&1 &
  awe_pid=$!
  started_temp=true
  for _ in $(seq 1 60); do
    if curl -sf "http://localhost:${AWE_API_PORT}/v1/awe/health" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  if ! curl -sf "http://localhost:${AWE_API_PORT}/v1/awe/health" >/dev/null 2>&1; then
    echo "[awe-init] AWE did not become ready. Log:" >&2
    tail -30 /tmp/openg2p-awe-init.log >&2 || true
    kill "$awe_pid" 2>/dev/null || true
    exit 1
  fi
fi

"${ROOT_DIR}/scripts/seed-awe-callback-secret.sh"

if [[ "$started_temp" == true ]]; then
  kill "$awe_pid" 2>/dev/null || true
  sleep 1
  echo "[awe-init] Temporary AWE process stopped. Run: make awe-run"
else
  echo "[awe-init] AWE already running on port ${AWE_API_PORT}"
fi

echo "[awe-init] Done."
