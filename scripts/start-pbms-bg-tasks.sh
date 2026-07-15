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

run_service "pbms-staff-api" "$STAFF_API_DIR" "$STAFF_API_ENV" \
  python -m openg2p_pbms_staff_portal_api.main run

run_service "pbms-celery-beat" "$CELERY_BEAT_DIR" "$CELERY_BEAT_ENV" \
  bash -c 'exec celery -A openg2p_bg_task_celery_beat_producers.main.celery_app worker --beat -Q celery -l info --schedule "/tmp/celery-beat-pbms-${BG_TASK_CELERY_BEAT_DB_DBNAME}.db"'

run_service "pbms-celery-worker" "$CELERY_WORKERS_DIR" "$CELERY_WORKERS_ENV" \
  bash -c 'exec celery -A openg2p_bg_task_celery_workers.main.celery_app worker -Q bg_task_worker_queue -l info --concurrency="${PBMS_CELERY_CONCURRENCY:-2}"'

echo "PBMS background tasks started."
echo "  Staff Portal API: $(pbms_bg_tasks_staff_api_url)/docs"
