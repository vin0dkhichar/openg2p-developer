#!/usr/bin/env bash
# Migrate bgtaskdb schema for PBMS staff portal API / Celery workers.
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/pbms-bg-tasks.sh"

pbms_bg_tasks_load_env
"${PBMS_DEV_ROOT}/scripts/infra-wait.sh"
"${PBMS_DEV_ROOT}/scripts/generate-config.sh" >/dev/null
pbms_bg_tasks_require_paths

if ! pbms_bg_tasks_installed; then
  echo "PBMS bg-task venvs missing. Run: make install-pbms-bg-tasks" >&2
  exit 1
fi

pbms_bg_tasks_ensure_bgtask_db

echo "[pbms-bg-init] Migrating ${PBMS_BGTASK_DB_NAME} ..."
(
  cd "$STAFF_API_DIR"
  set -a
  # shellcheck disable=SC1090
  source "$STAFF_API_ENV"
  set +a
  # shellcheck disable=SC1091
  source venv/bin/activate
  python -m openg2p_pbms_staff_portal_api.main migrate
)

echo "[pbms-bg-init] Done."
