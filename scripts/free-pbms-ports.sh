#!/usr/bin/env bash
# Stop native processes on PBMS service ports before restart.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/pbms-bg-tasks.sh"

pbms_bg_tasks_load_env

if [[ -f "${ROOT_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
fi

PBMS_HTTP_PORT="${PBMS_HTTP_PORT:-8069}"

free_port() {
  local port="$1"
  local label="$2"
  local pids=""

  if command -v lsof >/dev/null 2>&1; then
    pids="$(lsof -tiTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true)"
  fi
  if [[ -z "$pids" ]] && command -v fuser >/dev/null 2>&1; then
    pids="$(fuser -n tcp "${port}" 2>/dev/null | tr -cs '0-9' '\n' | sed '/^$/d' || true)"
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
  # shellcheck disable=SC2086
  kill -9 $pids 2>/dev/null || true
}

free_port "${PBMS_HTTP_PORT}" "PBMS Odoo"
free_port "${PBMS_STAFF_API_PORT}" "PBMS staff portal API"
free_port "8000" "PBMS staff portal API (legacy default bind port)"

stop_matching_processes "PBMS Celery beat" "openg2p_bg_task_celery_beat_producers.main.celery_app beat"
stop_matching_processes "PBMS Celery beat worker" "openg2p_bg_task_celery_beat_producers.main.celery_app worker -Q celery"
stop_matching_processes "PBMS Celery beat" "celery-beat-pbms-bgtaskdb"
stop_matching_processes "PBMS Celery beat" "${CELERY_BEAT_DIR}"
stop_matching_processes "PBMS Celery worker" "${CELERY_WORKERS_DIR}"
stop_matching_processes "PBMS Celery worker" "bg_task_worker_queue"
stop_matching_processes "PBMS Celery worker" "pbms_celery_worker_app"
stop_matching_processes "PBMS staff portal API" "openg2p_pbms_staff_portal_api.main"

BEAT_SCHEDULE="/tmp/celery-beat-pbms-${PBMS_BGTASK_DB_NAME}.db"
if [[ -f "$BEAT_SCHEDULE" ]]; then
  echo "Removing stale Celery beat schedule ${BEAT_SCHEDULE} ..."
  rm -f "$BEAT_SCHEDULE"
fi

echo "PBMS ports cleared."
