#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

OPENG2P_WORKSPACE="${OPENG2P_WORKSPACE:-../openg2p-workspace}"
OPENG2P_WORKSPACE="$(cd "$ROOT_DIR" && cd "$OPENG2P_WORKSPACE" && pwd)"
BRIDGE_ROOT="${OPENG2P_WORKSPACE}/g2p-bridge"

PARTNER_API_DIR="${BRIDGE_ROOT}/core/partner-api"
CELERY_DIR="${BRIDGE_ROOT}/core/celery-workers"
CELERY_BEAT_DIR="${BRIDGE_ROOT}/core/celery-beat-producers"
EXAMPLE_BANK_DIR="${BRIDGE_ROOT}/example-bank/openg2p-example-bank-api"

"${ROOT_DIR}/scripts/infra-wait.sh"
"${ROOT_DIR}/scripts/generate-config.sh" >/dev/null

if [[ ! -d "$BRIDGE_ROOT" ]]; then
  echo "G2P Bridge repo not found. Run: make clone" >&2
  exit 1
fi

run_service() {
  local name="$1"
  local dir="$2"
  local env_file="$3"
  shift 3

  if [[ ! -d "$dir" ]]; then
    echo "Skipping ${name}: directory not found (${dir})" >&2
    return 0
  fi

  echo "Starting ${name}..."
  (
    cd "$dir"
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
    exec "$@"
  ) &
  echo "${name} pid=$!"
}

echo "G2P Bridge native stack"
echo "Ensure Python venvs/deps are installed in each project (see README)."

run_service "g2p-bridge-partner-api" "$PARTNER_API_DIR" "${ROOT_DIR}/generated/bridge/partner-api.env" \
  python3 main.py run

run_service "g2p-bridge-celery-worker" "$CELERY_DIR" "${ROOT_DIR}/generated/bridge/celery-worker.env" \
  celery -A main worker -l info

run_service "g2p-bridge-celery-beat" "$CELERY_BEAT_DIR" "${ROOT_DIR}/generated/bridge/celery-beat.env" \
  celery -A main beat -l info

run_service "g2p-bridge-example-bank" "$EXAMPLE_BANK_DIR" "${ROOT_DIR}/generated/bridge/example-bank.env" \
  python3 main.py run

wait
