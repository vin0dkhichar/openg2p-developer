#!/usr/bin/env bash
# Stop native processes on Bridge + SPAR ports before restart.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/bridge.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/spar.sh"

bridge_load_env
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
}

free_port "${G2P_BRIDGE_API_PORT}" "G2P Bridge partner API"
free_port "${G2P_BRIDGE_EXAMPLE_BANK_PORT}" "Example bank API"
free_port "${SPAR_MAPPER_API_PORT}" "SPAR mapper API"
free_port "${SPAR_BENE_API_PORT}" "SPAR bene portal API"

stop_matching_processes "G2P Bridge Celery" "openg2p_g2p_bridge_celery"
stop_matching_processes "G2P Bridge partner API" "openg2p_g2p_bridge_partner_api"
stop_matching_processes "Example bank API" "openg2p_example_bank_api"
stop_matching_processes "SPAR mapper API" "openg2p_spar_mapper_partner_api"
stop_matching_processes "SPAR bene API" "openg2p_spar_bene_portal_api"

rm -f "/tmp/celery-beat-g2p-bridge-${BRIDGE_DB_NAME}.db" 2>/dev/null || true

echo "Bridge + SPAR ports cleared."
