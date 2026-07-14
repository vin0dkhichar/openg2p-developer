#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

VARIANT="${VARIANT:-farmer-registry}"
registry_variant_paths "$VARIANT"
registry_variant_db_settings "$VARIANT"
registry_variant_export_psql
registry_variant_ensure_db_seed_venv

(
  # shellcheck disable=SC1091
  source "${DB_SEED_DIR}/venv/bin/activate"
  python3 "${ROOT_DIR}/scripts/fix-farmer-registry-seeded-enums.py"
)
