#!/usr/bin/env bash
# Start PBMS staff portal API and Celery beat/worker (background).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/pbms-bg-tasks.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/run-service.sh"

pbms_bg_tasks_load_env
pbms_bg_tasks_require_paths

if ! pbms_bg_tasks_installed; then
  echo "Installing PBMS bg-task dependencies (first run) ..."
  bash "${ROOT_DIR}/scripts/install-pbms-bg-tasks.sh"
fi

pbms_bg_tasks_ensure_bgtask_db
pbms_bg_tasks_wait_redis

if ! PGPASSWORD="${POSTGRES_PASSWORD}" psql \
  -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U postgres -d "${PBMS_BGTASK_DB_NAME}" \
  -tc "SELECT to_regclass('public.beneficiary_list_details')" 2>/dev/null | grep -q beneficiary_list_details; then
  bash "${ROOT_DIR}/scripts/init-pbms-bg-tasks.sh"
fi

pbms_bg_tasks_ensure_bridge_models

# Singleton Celery beat (shared /tmp schedule file) + stop orphans from prior runs.
run_service_stop_celery_beats "${PBMS_BGTASK_DB_NAME}"
run_service_stop "pbms-staff-api" "openg2p_pbms_staff_portal_api.main" "${STAFF_API_DIR}"
run_service_stop "pbms-celery-beat" "openg2p_bg_task_celery_beat_producers.main.celery_app beat" "celery-beat-pbms-bgtaskdb" "${CELERY_BEAT_DIR}"
run_service_stop "pbms-celery-beat-worker" "openg2p_bg_task_celery_beat_producers.main.celery_app worker -Q celery" "${CELERY_BEAT_DIR}"
run_service_stop "pbms-celery-worker" "bg_task_worker_queue" "pbms_celery_worker_app" "${CELERY_WORKERS_DIR}"

run_service "pbms-staff-api" "$STAFF_API_DIR" "$STAFF_API_ENV" \
  python -m openg2p_pbms_staff_portal_api.main run
run_service_verify "pbms-staff-api"

# Beat scheduler (singleton) + dedicated worker for beat-producer tasks on queue "celery".
run_service "pbms-celery-beat" "$CELERY_BEAT_DIR" "$CELERY_BEAT_ENV" \
  bash -c 'exec celery -A openg2p_bg_task_celery_beat_producers.main.celery_app beat -l info --schedule "/tmp/celery-beat-pbms-${BG_TASK_CELERY_BEAT_DB_DBNAME}.db"'
run_service_verify "pbms-celery-beat"

run_service "pbms-celery-beat-worker" "$CELERY_BEAT_DIR" "$CELERY_BEAT_ENV" \
  bash -c 'exec celery -A openg2p_bg_task_celery_beat_producers.main.celery_app worker -Q celery -l info --concurrency=1'
run_service_verify "pbms-celery-beat-worker"

run_service "pbms-celery-worker" "$CELERY_WORKERS_DIR" "$CELERY_WORKERS_ENV" \
  bash -c 'export PYTHONPATH="'"${ROOT_DIR}"'/scripts${PYTHONPATH:+:$PYTHONPATH}"; exec celery -A pbms_celery_worker_app.celery_app worker -Q bg_task_worker_queue -l info --concurrency="${PBMS_CELERY_CONCURRENCY:-2}"'
run_service_verify "pbms-celery-worker" || {
  echo "Hint: with PBMS_WITH_BRIDGE=true, run: make install-pbms-bg-tasks  (after make clone PROFILE=bridge)" >&2
  exit 1
}

run_service_assert_single "PBMS Celery beat" "openg2p_bg_task_celery_beat_producers.main.celery_app beat" 1

echo "PBMS background tasks started."
echo "  Staff Portal API: $(pbms_bg_tasks_staff_api_url)/docs"
