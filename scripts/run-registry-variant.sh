#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

VARIANT="${1:-}"
registry_variant_validate "$VARIANT"

registry_variant_paths "$VARIANT"

"${ROOT_DIR}/scripts/infra-wait.sh"
"${ROOT_DIR}/scripts/id-generator-wait.sh"
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

bash "${ROOT_DIR}/scripts/free-variant-ports.sh" "$VARIANT"

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
echo "  make install-iam && make iam-init"
echo "  make install-awe && make awe-init"
echo "  make ${VARIANT//-/_}-init"
echo

AWE_DIR="${OPENG2P_WORKSPACE}/awe"
AWE_ENV="${ROOT_DIR}/generated/awe/awe-api.env"
if [[ -f "$AWE_ENV" && -d "${AWE_DIR}/venv" ]]; then
  run_service "awe-api" "$AWE_DIR" "$AWE_ENV" \
    bash -c 'exec uvicorn awe.main:app --host "${UVICORN_HOST:-0.0.0.0}" --port "${UVICORN_PORT}" --log-level info'
else
  echo "AWE not ready. Run: make install-awe && make awe-init" >&2
fi

run_service "${VARIANT}-staff-api" "$API_DIR" "${GENERATED_DIR}/staff-portal-api.env" \
  python -m openg2p_registry_staff_portal_api.main run

run_service "${VARIANT}-celery-worker" "$CELERY_DIR" "${GENERATED_DIR}/celery-workers.env" \
  bash -c 'exec celery -A main worker -Q "${REGISTRY_CELERY_WORKERS_WORKER_QUEUE}" -l info'

CELERY_BEAT_DIR="${REGISTRY_ROOT}/celery/openg2p-registry-celery-beat-producers"
if [[ -d "${CELERY_BEAT_DIR}/venv" && -f "${GENERATED_DIR}/celery-beat.env" ]]; then
  run_service "${VARIANT}-celery-beat" "$CELERY_BEAT_DIR" "${GENERATED_DIR}/celery-beat.env" \
    bash -c 'exec celery -A main worker --beat -l info --schedule "/tmp/celery-beat-${REGISTRY_CELERY_BEAT_DB_DBNAME}.db"'
else
  echo "Celery beat not ready. Run: make install-registry-extension VARIANT=${VARIANT} && make generate" >&2
fi

IAM_API_DIR="${OPENG2P_WORKSPACE}/openg2p-iam-service/iam-staff-portal-api"
IAM_ENV="${ROOT_DIR}/generated/iam/staff-portal-api.env"
if [[ -f "$IAM_ENV" && -d "$IAM_API_DIR/venv" ]]; then
  run_service "iam-staff-api" "$IAM_API_DIR" "$IAM_ENV" \
    python -m iam_staff_portal_api.main run
else
  echo "IAM staff API not ready. Run: make install-iam && make iam-init" >&2
fi

if [[ -d "$UI_DIR" ]]; then
  cp "${GENERATED_DIR}/staff-portal-ui.env" "${UI_DIR}/.env.local"
  run_service "${VARIANT}-staff-ui" "$UI_DIR" "${GENERATED_DIR}/staff-portal-ui.env" \
    npm run dev
else
  echo "Staff portal UI not found at ${UI_DIR}." >&2
  echo "Clone openg2p-registry-gen2-staff-portal-ui or set the variant UI path in .env." >&2
fi

wait
