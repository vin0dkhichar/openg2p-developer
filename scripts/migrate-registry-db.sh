#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

VARIANT="${VARIANT:-${1:-}}"
registry_variant_validate "$VARIANT"

registry_variant_paths "$VARIANT"
registry_variant_db_settings "$VARIANT"

"${ROOT_DIR}/scripts/infra-wait.sh"
"${ROOT_DIR}/scripts/generate-config.sh" >/dev/null

if [[ ! -d "$API_DIR" ]]; then
  echo "Registry platform not found at ${REGISTRY_ROOT}. Run: make clone" >&2
  exit 1
fi

if [[ ! -d "$EXTENSION_DIR" ]]; then
  echo "Extension not found at ${EXTENSION_DIR}. Run: make clone" >&2
  exit 1
fi

if [[ ! -f "${GENERATED_DIR}/staff-portal-api.env" ]]; then
  echo "Missing generated env files. Run: make generate" >&2
  exit 1
fi

if [[ ! -x "${API_DIR}/venv/bin/python" ]]; then
  echo "API venv not found. Run: make install-registry-extension VARIANT=${VARIANT}" >&2
  exit 1
fi

echo "Migrating ${LABEL} schema into ${REGISTRY_DB_NAME} ..."
(
  cd "$API_DIR"
  set -a
  # shellcheck disable=SC1090
  source "${GENERATED_DIR}/staff-portal-api.env"
  set +a
  # shellcheck disable=SC1091
  source venv/bin/activate
  python main.py migrate
)

echo "Migration complete for ${LABEL}."
