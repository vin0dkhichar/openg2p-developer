#!/usr/bin/env bash
# Shared helpers for Registry Gen2 domain variants.

registry_variant_root() {
  echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}

registry_variant_load_env() {
  local root
  root="$(registry_variant_root)"
  if [[ -f "${root}/.env" ]]; then
    # shellcheck disable=SC1091
    source "${root}/.env"
  fi
}

registry_variant_resolve_path() {
  local root="$1"
  local path="$2"
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/workspace-path.sh"
  if [[ "$path" != /* ]]; then
    path="${root}/${path}"
  fi
  workspace_resolve "$path"
}

registry_variant_is_custom() {
  local variant="$1"
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/extension-manifest.sh"
  extension_manifest_is_builtin_variant "$variant" && return 1
  extension_manifest_exists "$variant"
}

registry_variant_validate() {
  local variant="$1"
  if [[ "$variant" == "farmer-registry" || "$variant" == "national-social-registry" ]]; then
    return 0
  fi
  # shellcheck disable=SC1091
  source "$(dirname "${BASH_SOURCE[0]}")/extension-manifest.sh"
  if extension_manifest_exists "$variant"; then
    return 0
  fi
  echo "Unknown VARIANT '${variant}'." >&2
  echo "Built-in: farmer-registry, national-social-registry" >&2
  echo "Custom: bootstrap with make extension-package NAME=${variant}" >&2
  return 1
}

registry_variant_paths() {
  local variant="$1"
  local root
  root="$(registry_variant_root)"
  registry_variant_load_env

  OPENG2P_WORKSPACE="$(registry_variant_resolve_path "$root" "${OPENG2P_WORKSPACE:-../openg2p-workspace}")"
  REGISTRY_ROOT="${OPENG2P_WORKSPACE}/registry-platform"
  GENERATED_DIR="${root}/generated/${variant}"

  API_DIR="${REGISTRY_ROOT}/apis/openg2p-registry-staff-portal-api"
  CELERY_DIR="${REGISTRY_ROOT}/celery/openg2p-registry-celery-workers"
  CELERY_BEAT_DIR="${REGISTRY_ROOT}/celery/openg2p-registry-celery-beat-producers"
  DEFAULT_UI_DIR="${OPENG2P_WORKSPACE}/openg2p-registry-gen2-staff-portal-ui"
  FALLBACK_UI_DIR="${REGISTRY_ROOT}/ui/staff-portal-ui"

  case "$variant" in
    farmer-registry)
      PRODUCT_REPO="${OPENG2P_WORKSPACE}/farmer-registry"
      EXTENSION_DIR="${PRODUCT_REPO}/farmer-extension"
      DB_SEED_DIR="${PRODUCT_REPO}/docker/db-seed"
      UI_DIR="${FARMER_REGISTRY_UI_PATH:-$DEFAULT_UI_DIR}"
      LABEL="Farmer Registry"
      ;;
    national-social-registry)
      PRODUCT_REPO="${OPENG2P_WORKSPACE}/national-social-registry"
      EXTENSION_DIR="${PRODUCT_REPO}/nsr-extension"
      DB_SEED_DIR="${PRODUCT_REPO}/docker/db-seed"
      UI_DIR="${NSR_REGISTRY_UI_PATH:-$DEFAULT_UI_DIR}"
      LABEL="National Social Registry"
      ;;
    *)
      # shellcheck disable=SC1091
      source "$(dirname "${BASH_SOURCE[0]}")/extension-manifest.sh"
      extension_manifest_load "$variant"
      PRODUCT_REPO="${EXTENSION_PRODUCT_REPO_PATH}"
      DB_SEED_DIR="${PRODUCT_REPO}/docker/db-seed"
      UI_DIR="${DEFAULT_UI_DIR}"
      LABEL="${EXTENSION_LABEL}"
      ;;
  esac

  if [[ "$UI_DIR" != /* ]]; then
    UI_DIR="$(registry_variant_resolve_path "$root" "$UI_DIR")"
  fi

  if [[ ! -d "$UI_DIR" && -d "$FALLBACK_UI_DIR" ]]; then
    UI_DIR="$FALLBACK_UI_DIR"
  fi

  META_DATA_DIR="$(find "${EXTENSION_DIR}/src" -type d -name meta_data 2>/dev/null | head -1 || true)"
  SAMPLE_DATA_DIR="$(find "${EXTENSION_DIR}/src" -type d -name sample_data 2>/dev/null | head -1 || true)"
}

registry_variant_db_settings() {
  local variant="$1"
  case "$variant" in
    farmer-registry)
      REGISTRY_DB_NAME="${FARMER_REGISTRY_DB:-farmer_registry_db}"
      ;;
    national-social-registry)
      REGISTRY_DB_NAME="${NSR_REGISTRY_DB:-nsr_registry_db}"
      ;;
    *)
      # shellcheck disable=SC1091
      source "$(dirname "${BASH_SOURCE[0]}")/extension-manifest.sh"
      extension_manifest_load "$variant"
      REGISTRY_DB_NAME="${EXTENSION_REGISTRY_DB}"
      ;;
  esac

  POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
  POSTGRES_PORT="${POSTGRES_PORT:-5432}"
  POSTGRES_SUPERUSER="${POSTGRES_SUPERUSER:-postgres}"
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
}

registry_variant_export_psql() {
  export PGHOST="${POSTGRES_HOST}"
  export PGPORT="${POSTGRES_PORT}"
  export PGUSER="${POSTGRES_SUPERUSER}"
  export PGPASSWORD="${POSTGRES_PASSWORD}"
  export PGDATABASE="${REGISTRY_DB_NAME}"
}

registry_variant_run_sql_tree() {
  local dir="$1"
  local label="$2"

  if [[ ! -d "$dir" ]]; then
    echo "[seed] No ${label} directory at ${dir}, skipping."
    return 0
  fi

  local sql_files
  sql_files="$(find "$dir" -name '*.sql' -type f | sort)"
  if [[ -z "$sql_files" ]]; then
    echo "[seed] No SQL files in ${dir}, skipping."
    return 0
  fi

  echo "[seed] Applying ${label} from ${dir} ..."
  while IFS= read -r sql_file; do
    echo "[seed]   -> ${sql_file#${dir}/}"
    psql -v ON_ERROR_STOP=0 -f "$sql_file"
  done <<< "$sql_files"
}
