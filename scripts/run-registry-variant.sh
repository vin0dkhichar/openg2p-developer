#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

VARIANT="${1:-}"
registry_variant_validate "$VARIANT"

if [[ -f "${ROOT_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
fi

registry_variant_ensure_run_ready "$VARIANT"
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

  local venv_python=""
  if venv_python="$(registry_variant_venv_python "$dir" 2>/dev/null)"; then
    :
  elif [[ "$*" == *python* ]] || [[ "$*" == *celery* ]]; then
    echo "Skipping ${name}: Python venv missing in ${dir}." >&2
    echo "  Run: make install-registry-extension VARIANT=${VARIANT} (API/Celery) or make install-iam (IAM)" >&2
    return 0
  fi

  echo "Starting ${name} from ${dir} ..."
  (
    cd "$dir"
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
    if [[ -n "$venv_python" ]]; then
      # shellcheck disable=SC1091
      source venv/bin/activate
    fi
    if [[ "${1:-}" == "python" && -n "$venv_python" ]]; then
      shift
      exec "$venv_python" "$@"
    else
      exec "$@"
    fi
  ) &
  echo "${name} pid=$!"
}

echo "${LABEL} native stack"
echo "Dependencies are auto-installed on first run (API, Celery, IAM, AWE, Staff UI)."
case "$VARIANT" in
  farmer-registry) SETUP_HINT="make farmer-setup" ;;
  national-social-registry) SETUP_HINT="make nsr-setup" ;;
  *) SETUP_HINT="make extension-setup NAME=${VARIANT}" ;;
esac
echo "One-time DB setup if not done yet: ${SETUP_HINT}"
echo

AWE_DIR="${OPENG2P_WORKSPACE}/awe"
AWE_ENV="${ROOT_DIR}/generated/awe/awe-api.env"
AWE_API_PORT="${AWE_API_PORT:-8030}"
AWE_UI_PORT="${AWE_UI_PORT:-8031}"

wait_for_awe_health() {
  local i
  for i in $(seq 1 30); do
    if curl -sf "http://localhost:${AWE_API_PORT}/v1/awe/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "AWE API did not become ready on port ${AWE_API_PORT}." >&2
  return 1
}

start_awe_admin_ui() {
  local ui_dir="${AWE_DIR}/ui"
  if [[ ! -d "$ui_dir" || ! -f "${ui_dir}/package.json" ]]; then
    echo "AWE admin UI not found at ${ui_dir}. Run: make install-awe" >&2
    return 0
  fi
  if ! command -v npx >/dev/null 2>&1; then
    echo "npx not found; skipping AWE admin UI." >&2
    return 0
  fi
  echo "Starting awe-admin-ui from ${ui_dir} (port ${AWE_UI_PORT}, API proxy -> ${AWE_API_PORT}) ..."
  bash "${ROOT_DIR}/scripts/lib/ensure-awe-ui-vite-config.sh" "$ui_dir"
  bash "${ROOT_DIR}/scripts/lib/ensure-awe-ui-config.sh" "$ui_dir"
  (
    cd "$ui_dir"
    exec npx vite --config .openg2p-vite.config.mjs
  ) &
  echo "awe-admin-ui pid=$!"
}
if [[ -f "$AWE_ENV" && -d "${AWE_DIR}/venv" ]]; then
  run_service "awe-api" "$AWE_DIR" "$AWE_ENV" \
    bash -c 'exec uvicorn awe.main:app --host "${UVICORN_HOST:-0.0.0.0}" --port "${UVICORN_PORT}" --log-level info'
  if ! wait_for_awe_health; then
    exit 1
  fi
  start_awe_admin_ui
else
  echo "AWE not ready. Run: make install-awe && make awe-init" >&2
fi

run_service "${VARIANT}-staff-api" "$API_DIR" "${GENERATED_DIR}/staff-portal-api.env" \
  python -m openg2p_registry_staff_portal_api.main run

run_service "${VARIANT}-celery-worker" "$CELERY_DIR" "${GENERATED_DIR}/celery-workers.env" \
  bash -c 'exec celery -A main:celery_app worker -Q "${REGISTRY_CELERY_WORKERS_WORKER_QUEUE}" -l info --concurrency="${REGISTRY_CELERY_CONCURRENCY:-2}"'

CELERY_BEAT_DIR="${REGISTRY_ROOT}/celery/openg2p-registry-celery-beat-producers"
if registry_variant_venv_python "$CELERY_BEAT_DIR" >/dev/null 2>&1 \
  && [[ -f "${GENERATED_DIR}/celery-beat.env" ]]; then
  run_service "${VARIANT}-celery-beat" "$CELERY_BEAT_DIR" "${GENERATED_DIR}/celery-beat.env" \
    bash -c 'exec celery -A main:celery_app worker --beat -l info --concurrency="${REGISTRY_CELERY_CONCURRENCY:-2}" --schedule "/tmp/celery-beat-${REGISTRY_CELERY_BEAT_DB_DBNAME}.db"'
else
  echo "Celery beat not ready. Run: make install-registry-extension VARIANT=${VARIANT} && make generate" >&2
fi

IAM_API_DIR="${OPENG2P_WORKSPACE}/iam-service/iam-staff-portal-api"
IAM_ENV="${ROOT_DIR}/generated/iam/staff-portal-api.env"
if [[ -f "$IAM_ENV" ]] && registry_variant_venv_python "$IAM_API_DIR" >/dev/null 2>&1; then
  run_service "iam-staff-api" "$IAM_API_DIR" "$IAM_ENV" \
    python -m iam_staff_portal_api.main run
else
  echo "IAM staff API not ready. Run: make install-iam && make iam-init" >&2
fi

if [[ -d "$UI_DIR" ]]; then
  if [[ ! -x "${UI_DIR}/node_modules/.bin/next" ]]; then
    echo "Staff UI dependencies missing at ${UI_DIR}. Run: make install-registry-ui" >&2
  else
    cp "${GENERATED_DIR}/staff-portal-ui.env" "${UI_DIR}/.env.local"
    run_service "${VARIANT}-staff-ui" "$UI_DIR" "${GENERATED_DIR}/staff-portal-ui.env" \
      bash -c 'exec npm run dev -- -p "${PORT:-3000}"'
  fi
else
  echo "Staff portal UI not found at ${UI_DIR}." >&2
  echo "Clone registry-platform (ui/staff-portal-ui) or set the variant UI path in .env." >&2
fi

echo
echo "${LABEL} URLs:"
echo "  Staff UI : http://localhost:$(source "${GENERATED_DIR}/staff-portal-ui.env" && echo "${PORT}")"
echo "  Staff API: http://localhost:$(source "${GENERATED_DIR}/staff-portal-api.env" && echo "${REGISTRY_STAFF_PORTAL_API_APP_PORT}")/docs"
echo "  IAM API  : http://localhost:${IAM_STAFF_PORT:-8020}"
echo "  AWE API  : http://localhost:${AWE_API_PORT:-8030}/v1/awe/health"
echo "  AWE Admin: http://localhost:${AWE_UI_PORT:-8031}/  (login: staff/staff via Keycloak awe-admin-portal)"
echo "  AWE Docs : http://localhost:${AWE_API_PORT:-8030}/v1/awe/docs"
echo

wait
