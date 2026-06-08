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
REGISTRY_ROOT="${OPENG2P_WORKSPACE}/registry-platform"

API_DIR="${REGISTRY_ROOT}/apis/openg2p-registry-staff-portal-api"
CELERY_DIR="${REGISTRY_ROOT}/celery/openg2p-registry-celery-workers"
UI_DIR="${REGISTRY_ROOT}/ui/staff-portal-ui"

"${ROOT_DIR}/scripts/infra-wait.sh"
"${ROOT_DIR}/scripts/generate-config.sh" >/dev/null

if [[ ! -d "$API_DIR" ]]; then
  echo "Registry platform not found. Run: make clone" >&2
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

echo "Registry Gen2 native stack"
echo "Ensure Python venvs/deps are installed in each project (see README)."

run_service "registry-staff-api" "$API_DIR" "${ROOT_DIR}/generated/registry/staff-portal-api.env" \
  python3 main.py run

run_service "registry-celery-worker" "$CELERY_DIR" "${ROOT_DIR}/generated/registry/celery-workers.env" \
  celery -A main worker -l info

if [[ -d "$UI_DIR" ]]; then
  run_service "registry-staff-ui" "$UI_DIR" "${ROOT_DIR}/generated/registry/staff-portal-ui.env" \
    npm run dev
fi

wait
