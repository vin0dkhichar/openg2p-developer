#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example"
fi

# shellcheck disable=SC1091
source .env

LOAD_SAMPLE_DATA="${LOAD_SAMPLE_DATA:-false}"
LOAD_TEMPLATES="${LOAD_TEMPLATES:-false}"
LOAD_IMAGES="${LOAD_IMAGES:-false}"

echo "============================================="
echo " NSR one-time setup"
echo " Sample data: ${LOAD_SAMPLE_DATA}"
echo "============================================="

bash "${ROOT_DIR}/scripts/generate-config.sh" >/dev/null

bash "${ROOT_DIR}/scripts/install-iam.sh"
bash "${ROOT_DIR}/scripts/init-iam.sh"
bash "${ROOT_DIR}/scripts/install-awe.sh"
bash "${ROOT_DIR}/scripts/init-awe.sh"

VARIANT=national-social-registry bash "${ROOT_DIR}/scripts/install-registry-extension.sh"
bash "${ROOT_DIR}/scripts/install-registry-ui.sh"
VARIANT=national-social-registry bash "${ROOT_DIR}/scripts/install-registry-db-seed.sh"

echo
echo "[nsr-setup] Migrating schema and seeding NSR configuration ..."
VARIANT=national-social-registry bash "${ROOT_DIR}/scripts/migrate-registry-db.sh"
VARIANT=national-social-registry \
  LOAD_SAMPLE_DATA="$LOAD_SAMPLE_DATA" \
  LOAD_TEMPLATES="$LOAD_TEMPLATES" \
  LOAD_IMAGES="$LOAD_IMAGES" \
  bash "${ROOT_DIR}/scripts/seed-registry-db.sh" national-social-registry

echo
echo "NSR setup complete."
echo "  make nsr-registry-run"
echo "  Staff UI: http://localhost:${NSR_REGISTRY_UI_PORT:-3010} (staff / staff)"
if [[ "$LOAD_SAMPLE_DATA" != "true" ]]; then
  echo
  echo "Optional demo registrants and sub-tables:"
  echo "  LOAD_SAMPLE_DATA=true make nsr-registry-seed"
fi
