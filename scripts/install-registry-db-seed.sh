#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

VARIANT="${VARIANT:-national-social-registry}"
registry_variant_validate "$VARIANT"
registry_variant_paths "$VARIANT"

if [[ ! -d "$DB_SEED_DIR" ]]; then
  echo "db-seed directory not found at ${DB_SEED_DIR}. Run: make clone" >&2
  exit 1
fi

if [[ ! -f "${DB_SEED_DIR}/requirements.txt" ]]; then
  echo "No requirements.txt in ${DB_SEED_DIR}; nothing to install." >&2
  exit 0
fi

bash "${ROOT_DIR}/scripts/install-python-project.sh" "$DB_SEED_DIR"
echo "db-seed Python environment ready for ${LABEL}."
