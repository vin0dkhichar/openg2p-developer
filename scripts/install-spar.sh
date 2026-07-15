#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/spar.sh"

spar_load_env
spar_require_paths

FASTAPI_COMMON='git+https://github.com/openg2p/openg2p-fastapi-common@develop#subdirectory=openg2p-fastapi-common'
COMMON_PIP_DEPS=(
  "$FASTAPI_COMMON"
  'git+https://github.com/openg2p/openg2p-fastapi-common@develop#subdirectory=openg2p-fastapi-auth'
  'git+https://github.com/openg2p/openg2p-fastapi-common@develop#subdirectory=openg2p-fastapi-auth-models'
  'git+https://github.com/openg2p/openg2p-fastapi-common@develop#subdirectory=openg2p-fastapi-partner-auth'
  greenlet
  jinja2
  asyncpg
  celery
)

install_project() {
  local project_dir="$1"
  shift
  local -a extras=("$@")

  SKIP_EDITABLE_INSTALL=1 bash "${ROOT_DIR}/scripts/install-python-project.sh" "$project_dir"

  (
    cd "$project_dir"
    # shellcheck disable=SC1091
    source venv/bin/activate
    pip install "${COMMON_PIP_DEPS[@]}"
    local dep
    for dep in "${extras[@]}"; do
      dep="$(cd "$dep" && pwd)"
      pip install -e "$dep" --no-deps
    done
    pip install -e . --no-deps
  )
}

echo "Installing SPAR Python packages ..."

install_project "$MODELS_DIR"
install_project "$MAPPER_CORE_DIR" "$MODELS_DIR"
install_project "$MAPPER_API_DIR" "$MODELS_DIR" "$MAPPER_CORE_DIR"
install_project "$BENE_API_DIR" "$MODELS_DIR" "$MAPPER_CORE_DIR"

echo "SPAR dependencies installed."
