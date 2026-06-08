#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VARIANT="${1:-}"
if [[ -z "$VARIANT" || ( "$VARIANT" != "farmer-registry" && "$VARIANT" != "national-social-registry" ) ]]; then
  echo "Usage: $0 {farmer-registry|national-social-registry}" >&2
  exit 1
fi

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

resolve_path() {
  local path="$1"
  if [[ "$path" != /* ]]; then
    path="${ROOT_DIR}/${path}"
  fi
  local dir part
  dir="$(dirname "$path")"
  part="$(basename "$path")"
  echo "$(cd "$dir" && pwd)/${part}"
}

OPENG2P_WORKSPACE="$(resolve_path "${OPENG2P_WORKSPACE:-../openg2p-workspace}")"
REGISTRY_ROOT="${OPENG2P_WORKSPACE}/registry-platform"
GENERATED_DIR="${ROOT_DIR}/generated/${VARIANT}"

API_DIR="${REGISTRY_ROOT}/apis/openg2p-registry-staff-portal-api"
CELERY_DIR="${REGISTRY_ROOT}/celery/openg2p-registry-celery-workers"
UI_DIR="${REGISTRY_ROOT}/ui/staff-portal-ui"

case "$VARIANT" in
  farmer-registry)
    PRODUCT_REPO="${OPENG2P_WORKSPACE}/farmer-registry"
    EXTENSION_DIR="${PRODUCT_REPO}/farmer-extension"
    LABEL="Farmer Registry"
    ;;
  national-social-registry)
    PRODUCT_REPO="${OPENG2P_WORKSPACE}/national-social-registry"
    EXTENSION_DIR="${PRODUCT_REPO}/nsr-extension"
    LABEL="National Social Registry"
    ;;
esac

"${ROOT_DIR}/scripts/infra-wait.sh"
"${ROOT_DIR}/scripts/generate-config.sh" >/dev/null

if [[ ! -d "$API_DIR" ]]; then
  echo "Registry platform not found at ${REGISTRY_ROOT}. Run: make clone" >&2
  exit 1
fi

if [[ ! -d "$EXTENSION_DIR" ]]; then
  echo "Extension not found at ${EXTENSION_DIR}. Run: make clone" >&2
  exit 1
fi

if [[ ! -f "${GENERATED_DIR}/staff-portal-api.env" ]]; then
  echo "Missing generated env files. Run: make generate" >&2
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

echo "${LABEL} native stack"
echo "Install deps once with:"
echo "  make install-registry-extension VARIANT=${VARIANT}"
echo

run_service "${VARIANT}-staff-api" "$API_DIR" "${GENERATED_DIR}/staff-portal-api.env" \
  python3 main.py run

run_service "${VARIANT}-celery-worker" "$CELERY_DIR" "${GENERATED_DIR}/celery-workers.env" \
  celery -A main worker -l info

if [[ -d "$UI_DIR" ]]; then
  run_service "${VARIANT}-staff-ui" "$UI_DIR" "${GENERATED_DIR}/staff-portal-ui.env" \
    npm run dev
fi

wait
