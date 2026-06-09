#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

VARIANT="${VARIANT:-${1:-farmer-registry}}"
registry_variant_validate "$VARIANT"
registry_variant_paths "$VARIANT"

REGISTRY_ROOT="${OPENG2P_WORKSPACE}/registry-platform"
CORE_DIR="${REGISTRY_ROOT}/core/openg2p-registry-core"
IAM_CORE_DIR="${OPENG2P_WORKSPACE}/openg2p-iam-service/iam-core"
API_DIR="${REGISTRY_ROOT}/apis/openg2p-registry-staff-portal-api"
CELERY_DIR="${REGISTRY_ROOT}/celery/openg2p-registry-celery-workers"

for project_dir in "$API_DIR" "$CELERY_DIR"; do
  if [[ ! -d "$project_dir" ]]; then
    echo "Missing ${project_dir}. Run: make clone" >&2
    exit 1
  fi
  bash "${ROOT_DIR}/scripts/install-python-project.sh" "$project_dir"
done

for dep_dir in "$CORE_DIR" "$IAM_CORE_DIR" "$EXTENSION_DIR"; do
  if [[ ! -d "$dep_dir" ]]; then
    echo "Missing ${dep_dir}. Run: make clone or make extension-package NAME=${VARIANT}" >&2
    exit 1
  fi
done

install_into_venv() {
  local project_dir="$1"
  (
    cd "$project_dir"
    # shellcheck disable=SC1091
    source venv/bin/activate
    pip install "$CORE_DIR" "$IAM_CORE_DIR" "$EXTENSION_DIR" greenlet openg2p-fastapi-auth
  )
}

install_into_venv "$API_DIR"
install_into_venv "$CELERY_DIR"

echo "Installed registry core, IAM core, and ${VARIANT} extension into API and Celery venvs."
