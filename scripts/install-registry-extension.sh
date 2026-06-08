#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VARIANT="${VARIANT:-${1:-farmer-registry}}"
if [[ "$VARIANT" != "farmer-registry" && "$VARIANT" != "national-social-registry" ]]; then
  echo "VARIANT must be farmer-registry or national-social-registry" >&2
  exit 1
fi

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

resolve_path() {
  local path="$1"
  if [[ "$path" != /* ]]; then
    path="${ROOT_DIR}/${path}"
  fi
  local dir part
  dir="$(dirname "$path")"
  part="$(basename "$path")"
  echo "$(cd "$dir" && pwd)/${part}"
}

OPENG2P_WORKSPACE="$(resolve_path "${OPENG2P_WORKSPACE:-../openg2p-workspace}")"
REGISTRY_ROOT="${OPENG2P_WORKSPACE}/registry-platform"
CORE_DIR="${REGISTRY_ROOT}/core/openg2p-registry-core"
IAM_CORE_DIR="${OPENG2P_WORKSPACE}/openg2p-iam-service/iam-core"
API_DIR="${REGISTRY_ROOT}/apis/openg2p-registry-staff-portal-api"
CELERY_DIR="${REGISTRY_ROOT}/celery/openg2p-registry-celery-workers"

case "$VARIANT" in
  farmer-registry)
    EXTENSION_DIR="${OPENG2P_WORKSPACE}/farmer-registry/farmer-extension"
    ;;
  national-social-registry)
    EXTENSION_DIR="${OPENG2P_WORKSPACE}/national-social-registry/nsr-extension"
    ;;
esac

for project_dir in "$API_DIR" "$CELERY_DIR"; do
  if [[ ! -d "$project_dir" ]]; then
    echo "Missing ${project_dir}. Run: make clone" >&2
    exit 1
  fi
  bash "${ROOT_DIR}/scripts/install-python-project.sh" "$project_dir"
done

for dep_dir in "$CORE_DIR" "$IAM_CORE_DIR" "$EXTENSION_DIR"; do
  if [[ ! -d "$dep_dir" ]]; then
    echo "Missing ${dep_dir}. Run: make clone" >&2
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
