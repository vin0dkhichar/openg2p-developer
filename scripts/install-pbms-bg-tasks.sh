#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/pbms-bg-tasks.sh"

pbms_bg_tasks_load_env
pbms_bg_tasks_require_paths

FASTAPI_COMMON='git+https://github.com/openg2p/openg2p-fastapi-common@develop#subdirectory=openg2p-fastapi-common'
# fastapi-cache2 (registry adapters) imports starlette templating, which needs jinja2
# (PBMS Dockerfiles install this explicitly; it is not always pulled transitively).
PBMS_COMMON_PIP_DEPS=(
  "$FASTAPI_COMMON"
  openg2p-fastapi-auth
  greenlet
  jinja2
)

install_project() {
  local project_dir="$1"
  shift
  local -a extras=("$@")

  bash "${ROOT_DIR}/scripts/install-python-project.sh" "$project_dir"

  (
    cd "$project_dir"
    # shellcheck disable=SC1091
    source venv/bin/activate
    pip install "${PBMS_COMMON_PIP_DEPS[@]}"
    local dep
    for dep in "${extras[@]}"; do
      dep="$(cd "$dep" && pwd)"
      pip install -e "$dep"
    done
  )
}

echo "Installing PBMS background-task Python packages ..."

install_project "$BG_TASK_MODELS_DIR"
install_project "$PBMS_MODELS_DIR"
install_project "$REGISTRY_ADAPTERS_DIR" "$BG_TASK_MODELS_DIR" "$PBMS_MODELS_DIR"

install_project "$STAFF_API_DIR" \
  "$BG_TASK_MODELS_DIR" "$PBMS_MODELS_DIR" "$REGISTRY_ADAPTERS_DIR"

install_project "$CELERY_BEAT_DIR" \
  "$BG_TASK_MODELS_DIR" "$PBMS_MODELS_DIR"

install_project "$CELERY_WORKERS_DIR" \
  "$BG_TASK_MODELS_DIR" "$PBMS_MODELS_DIR" "$REGISTRY_ADAPTERS_DIR"

# Disbursement envelope worker talks to G2P Bridge API models.
BRIDGE_MODELS_DIR="${PBMS_PATH%/pbms}/g2p-bridge/core/models"
if [[ -d "$BRIDGE_MODELS_DIR" ]]; then
  (
    cd "$CELERY_WORKERS_DIR"
    # shellcheck disable=SC1091
    source venv/bin/activate
    pip install -e "$BRIDGE_MODELS_DIR"
  )
fi

echo "PBMS background-task dependencies installed."
