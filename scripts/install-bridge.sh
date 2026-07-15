#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/bridge.sh"

bridge_load_env
bridge_require_paths

FASTAPI_COMMON='git+https://github.com/openg2p/openg2p-fastapi-common@develop#subdirectory=openg2p-fastapi-common'
COMMON_PIP_DEPS=(
  "$FASTAPI_COMMON"
  'git+https://github.com/openg2p/openg2p-fastapi-common@develop#subdirectory=openg2p-fastapi-auth'
  'git+https://github.com/openg2p/openg2p-fastapi-common@develop#subdirectory=openg2p-fastapi-auth-models'
  'git+https://github.com/openg2p/openg2p-fastapi-common@develop#subdirectory=openg2p-fastapi-partner-auth'
  'openg2p-g2pconnect-common-lib>=1.1.0'
  'openg2p-g2pconnect-mapper-lib>=1.1.0'
  greenlet
  jinja2
  asyncpg
  'celery[redis]'
  httpx
  orjson
  'psycopg2-binary>=2.9.12'
  fastnanoid
  python-magic
  mt-940
  novu-py
  requests
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

echo "Installing G2P Bridge Python packages ..."

install_project "$MODELS_DIR"

for ext in bank-connectors mapper-connectors geo-resolver warehouse-allocator \
  agency-allocator notification-connectors; do
  install_project "${EXTENSIONS_DIR}/${ext}" "$MODELS_DIR"
done

SPAR_MODELS_DIR="${OPENG2P_WORKSPACE}/spar/core/models"
if [[ -d "$SPAR_MODELS_DIR" ]]; then
  install_project "$SPAR_MODELS_DIR"
fi

install_project "$PARTNER_API_DIR" "$MODELS_DIR"

install_project "$CELERY_BEAT_DIR" "$MODELS_DIR" "$BANK_CONNECTORS_DIR"

(
  cd "$CELERY_BEAT_DIR"
  # shellcheck disable=SC1091
  source venv/bin/activate
  pip install -r "${BRIDGE_ROOT}/core/test-requirements.txt" || true
)

CELERY_WORKER_EXTRAS=(
  "$MODELS_DIR"
  "$BANK_CONNECTORS_DIR"
  "$MAPPER_CONNECTORS_DIR"
  "$GEO_RESOLVER_DIR"
  "$WAREHOUSE_ALLOCATOR_DIR"
  "$AGENCY_ALLOCATOR_DIR"
  "$NOTIFICATION_CONNECTORS_DIR"
)
[[ -d "$SPAR_MODELS_DIR" ]] && CELERY_WORKER_EXTRAS+=("$SPAR_MODELS_DIR")

install_project "$CELERY_WORKERS_DIR" "${CELERY_WORKER_EXTRAS[@]}"

(
  cd "$CELERY_WORKERS_DIR"
  # shellcheck disable=SC1091
  source venv/bin/activate
  pip install -r "${BRIDGE_ROOT}/core/test-requirements.txt" || true
)

install_project "$EXAMPLE_BANK_MODELS_DIR"
install_project "$EXAMPLE_BANK_API_DIR" "$EXAMPLE_BANK_MODELS_DIR"

echo "G2P Bridge dependencies installed."
