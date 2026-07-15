#!/usr/bin/env bash
# Stop native SPAR processes only (does not touch Bridge or PBMS).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/spar.sh"

spar_load_env

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
  # shellcheck disable=SC2086
  kill -9 $pids 2>/dev/null || true
}

free_port "${SPAR_MAPPER_API_PORT}" "SPAR mapper API"
free_port "${SPAR_BENE_API_PORT}" "SPAR bene portal API"
stop_matching_processes "SPAR mapper API" "uvicorn main:app.*--port ${SPAR_MAPPER_API_PORT}"
stop_matching_processes "SPAR mapper API" "spar/core/mapper-partner-api"
stop_matching_processes "SPAR bene API" "uvicorn main:app.*--port ${SPAR_BENE_API_PORT}"
stop_matching_processes "SPAR bene API" "spar/core/bene-portal-api"

rm -f "${ROOT_DIR}/generated/run/spar-mapper-api.pid" \
      "${ROOT_DIR}/generated/run/spar-bene-api.pid" 2>/dev/null || true

echo "SPAR ports cleared."
