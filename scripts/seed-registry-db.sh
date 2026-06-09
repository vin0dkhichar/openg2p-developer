#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

VARIANT="${VARIANT:-${1:-}}"
registry_variant_validate "$VARIANT"

registry_variant_paths "$VARIANT"
registry_variant_db_settings "$VARIANT"
registry_variant_export_psql

LOAD_SAMPLE_DATA="${LOAD_SAMPLE_DATA:-false}"
LOAD_IMAGES="${LOAD_IMAGES:-false}"
LOAD_TEMPLATES="${LOAD_TEMPLATES:-false}"

if [[ ! -d "$EXTENSION_DIR" ]]; then
  echo "Extension not found at ${EXTENSION_DIR}. Run: make clone" >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "psql is required for registry seeding. Install PostgreSQL client tools." >&2
  exit 1
fi

echo "============================================="
echo " Seeding ${LABEL}"
echo " Database   : ${REGISTRY_DB_NAME}@${PGHOST}:${PGPORT}"
echo " Sample data: ${LOAD_SAMPLE_DATA}"
echo "============================================="

registry_variant_run_sql_tree "$META_DATA_DIR" "configuration SQL"

case "$VARIANT" in
  farmer-registry)
    if [[ "$LOAD_SAMPLE_DATA" == "true" ]]; then
      registry_variant_run_sql_tree "$SAMPLE_DATA_DIR" "sample data SQL"
    else
      echo "[seed] Skipping farmer sample data (LOAD_SAMPLE_DATA=${LOAD_SAMPLE_DATA})."
    fi
    ;;
  national-social-registry)
    if [[ "$LOAD_SAMPLE_DATA" == "true" || "$LOAD_TEMPLATES" == "true" || "$LOAD_IMAGES" == "true" ]]; then
      if [[ ! -x "${DB_SEED_DIR}/venv/bin/python" ]]; then
        echo "[seed] Installing db-seed Python dependencies ..."
        VARIANT=national-social-registry bash "${ROOT_DIR}/scripts/install-registry-db-seed.sh"
      fi
    fi

    if [[ "$LOAD_SAMPLE_DATA" == "true" ]]; then
      OPENG2P_DATA_DIR="${OPENG2P_DATA_DIR:-${OPENG2P_WORKSPACE}/openg2p-data}"
      NSR_SEED_DATA_DIR="${NSR_SEED_DATA_DIR:-${DB_SEED_DIR}/seed-data}"
      LOAD_SCRIPT="${DB_SEED_DIR}/load_sample_data.py"

      if [[ ! -d "$OPENG2P_DATA_DIR" ]]; then
        echo "openg2p-data not found at ${OPENG2P_DATA_DIR}. Run: make clone" >&2
        exit 1
      fi
      if [[ ! -f "$LOAD_SCRIPT" ]]; then
        echo "NSR sample loader not found at ${LOAD_SCRIPT}. Run: make clone" >&2
        exit 1
      fi

      echo "[seed] Loading NSR sample data via ${LOAD_SCRIPT} ..."
      (
        cd "$DB_SEED_DIR"
        # shellcheck disable=SC1091
        source "${API_DIR}/venv/bin/activate"
        export OPENG2P_DATA_DIR NSR_SEED_DATA_DIR
        registry_variant_export_psql
        python3 load_sample_data.py
      )
    else
      echo "[seed] Skipping NSR sample data (LOAD_SAMPLE_DATA=${LOAD_SAMPLE_DATA})."
    fi

    if [[ "$LOAD_TEMPLATES" == "true" && -f "${DB_SEED_DIR}/upload_templates.py" ]]; then
      echo "[seed] Uploading NSR templates to MinIO ..."
      (
        cd "$DB_SEED_DIR"
        # shellcheck disable=SC1091
        source venv/bin/activate
        export MINIO_ENDPOINT="${MINIO_ENDPOINT:-localhost:9000}"
        export MINIO_ACCESS_KEY="${MINIO_ROOT_USER:-admin}"
        export MINIO_SECRET_KEY="${MINIO_ROOT_PASSWORD:-secret}"
        export MINIO_SECURE="${MINIO_SECURE:-false}"
        export TEMPLATE_BUCKET_NAME="${REGISTRY_TEMPLATE_BUCKET:-templates}"
        python3 upload_templates.py
      )
    fi

    if [[ "$LOAD_IMAGES" == "true" && -f "${DB_SEED_DIR}/upload_images.py" ]]; then
      echo "[seed] Uploading NSR profile images to MinIO ..."
      (
        cd "$DB_SEED_DIR"
        # shellcheck disable=SC1091
        source venv/bin/activate
        export OPENG2P_DATA_DIR="${OPENG2P_DATA_DIR:-${OPENG2P_WORKSPACE}/openg2p-data}"
        export MINIO_ENDPOINT="${MINIO_ENDPOINT:-localhost:9000}"
        export MINIO_ACCESS_KEY="${MINIO_ROOT_USER:-admin}"
        export MINIO_SECRET_KEY="${MINIO_ROOT_PASSWORD:-secret}"
        export MINIO_SECURE="${MINIO_SECURE:-false}"
        export IMAGE_BUCKET_NAME="${REGISTRY_IMAGE_BUCKET:-registrant-photos}"
        python3 upload_images.py
      )
    fi
    ;;
esac

echo "[seed] Done for ${LABEL}."
