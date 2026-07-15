#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

VARIANT="${VARIANT:-farmer-registry}"
registry_variant_paths "$VARIANT"
registry_variant_db_settings "$VARIANT"
registry_variant_open_data_dir() {
  local root
  root="$(registry_variant_root)"
  registry_variant_resolve_path "$root" "${OPENG2P_DATA_DIR:-${OPENG2P_WORKSPACE}/openg2p-data}"
}
export OPENG2P_WORKSPACE
export OPENG2P_DATA_DIR="$(registry_variant_open_data_dir)"
export FARMER_SEED_DATA_DIR="${ROOT_DIR}/generated/farmer-registry/seed-data-remapped"
export MASTER_DATA_DB_NAME="${MASTER_DATA_DB_NAME:-farmer_master_data_db}"
registry_variant_export_psql
registry_variant_ensure_db_seed_venv

(
  # shellcheck disable=SC1091
  source "${DB_SEED_DIR}/venv/bin/activate"
  python3 "${ROOT_DIR}/scripts/validate-farmer-registry-seed.py"
)
