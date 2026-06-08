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

if [[ ! -d "$EXTENSION_DIR" ]]; then
  echo "Missing extension at ${EXTENSION_DIR}. Run: make clone" >&2
  exit 1
fi

(
  cd "$API_DIR"
  # shellcheck disable=SC1091
  source venv/bin/activate
  pip install -e "$EXTENSION_DIR"
)

(
  cd "$CELERY_DIR"
  # shellcheck disable=SC1091
  source venv/bin/activate
  pip install -e "$EXTENSION_DIR"
)

echo "Installed ${VARIANT} extension into registry-platform API and Celery venvs."
