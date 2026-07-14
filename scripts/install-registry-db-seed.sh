#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

VARIANT="${VARIANT:-${1:-national-social-registry}}"
registry_variant_validate "$VARIANT"
registry_variant_paths "$VARIANT"

if [[ ! -d "$DB_SEED_DIR" ]]; then
  echo "No db-seed directory at ${DB_SEED_DIR}; skipping (optional for custom extensions)." >&2
  exit 0
fi

if [[ ! -f "${DB_SEED_DIR}/requirements.txt" ]]; then
  echo "No requirements.txt in ${DB_SEED_DIR}; nothing to install." >&2
  exit 0
fi

bash "${ROOT_DIR}/scripts/install-python-project.sh" "$DB_SEED_DIR"

(
  # shellcheck disable=SC1091
  source "${DB_SEED_DIR}/venv/bin/activate"
  # Product Docker images install psycopg2 via apk; local dev needs a wheel.
  pip install 'psycopg2-binary>=2.9.12'
)

echo "db-seed Python environment ready for ${LABEL}."
