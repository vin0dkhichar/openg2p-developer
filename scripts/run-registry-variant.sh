#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

VARIANT="${1:-}"
registry_variant_validate "$VARIANT"

registry_variant_paths "$VARIANT"

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

  echo "Starting ${name} from ${dir} ..."
  (
    cd "$dir"
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
    if [[ -d venv ]]; then
      # shellcheck disable=SC1091
      source venv/bin/activate
    fi
    exec "$@"
  ) &
  echo "${name} pid=$!"
}

echo "${LABEL} native stack"
echo "One-time setup:"
echo "  make install-registry-extension VARIANT=${VARIANT}"
echo "  make ${VARIANT//-/_}-init"
echo

run_service "${VARIANT}-staff-api" "$API_DIR" "${GENERATED_DIR}/staff-portal-api.env" \
  python3 main.py run

run_service "${VARIANT}-celery-worker" "$CELERY_DIR" "${GENERATED_DIR}/celery-workers.env" \
  celery -A main worker -l info

if [[ -d "$UI_DIR" ]]; then
  run_service "${VARIANT}-staff-ui" "$UI_DIR" "${GENERATED_DIR}/staff-portal-ui.env" \
    npm run dev
else
  echo "Staff portal UI not found at ${UI_DIR}." >&2
  echo "Clone openg2p-registry-gen2-staff-portal-ui or set the variant UI path in .env." >&2
fi

wait
