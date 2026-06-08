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
SPAR_ROOT="${OPENG2P_WORKSPACE}/openg2p-spar"

MAPPER_DIR="${SPAR_ROOT}/core/mapper-partner-api"
BENE_DIR="${SPAR_ROOT}/core/bene-portal-api"

"${ROOT_DIR}/scripts/infra-wait.sh"
"${ROOT_DIR}/scripts/generate-config.sh" >/dev/null

if [[ ! -d "$SPAR_ROOT" ]]; then
  echo "SPAR repo not found. Run: make clone" >&2
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

echo "SPAR native stack"
echo "Ensure Python venvs/deps are installed in each project (see README)."

run_service "spar-mapper-api" "$MAPPER_DIR" "${ROOT_DIR}/generated/spar/mapper-partner-api.env" \
  python3 main.py run

run_service "spar-bene-api" "$BENE_DIR" "${ROOT_DIR}/generated/spar/bene-portal-api.env" \
  python3 main.py run

wait
