#!/usr/bin/env bash
# Start PBMS + registry + background tasks + Odoo only.
# SPAR and Bridge are separate: make spar-run && make bridge-run
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/pbms-odoo.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/pbms-bg-tasks.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/bridge.sh"

pbms_odoo_load_env
pbms_bg_tasks_load_env
bridge_load_env

PBMS_WITH_REGISTRY="${PBMS_WITH_REGISTRY:-true}"
PBMS_WITH_BRIDGE="${PBMS_WITH_BRIDGE:-true}"

echo "==> Ensuring infrastructure is up ..."
make -C "$PBMS_DEV_ROOT" infra-ensure

"${PBMS_DEV_ROOT}/scripts/infra-wait.sh"
"${PBMS_DEV_ROOT}/scripts/generate-config.sh" >/dev/null

pbms_odoo_require_paths
pbms_bg_tasks_require_paths

if ! pbms_odoo_db_initialized; then
  echo "Database ${PBMS_DB_NAME} is not initialized yet." >&2
  echo "Run once: make pbms-setup   (or: make pbms-init && make init-pbms-bg-tasks)" >&2
  exit 1
fi

echo "==> Stopping PBMS processes only (SPAR/Bridge left running) ..."
bash "${PBMS_DEV_ROOT}/scripts/free-pbms-ports.sh"

if [[ "${PBMS_WITH_REGISTRY}" == "true" ]]; then
  # shellcheck disable=SC1091
  source "${PBMS_DEV_ROOT}/scripts/lib/registry-variant.sh"
  if registry_variant_validate "${PBMS_REGISTRY_VARIANT}" 2>/dev/null; then
    bash "${PBMS_DEV_ROOT}/scripts/free-variant-ports.sh" "${PBMS_REGISTRY_VARIANT}"
    echo "==> Starting registry (${PBMS_REGISTRY_VARIANT}) ..."
    bash "${PBMS_DEV_ROOT}/scripts/start-registry-variant.sh" "${PBMS_REGISTRY_VARIANT}"
  else
    echo "Registry variant '${PBMS_REGISTRY_VARIANT}' is not available. Set PBMS_WITH_REGISTRY=false or run make clone PROFILE=pbms." >&2
    exit 1
  fi
fi

echo "==> Starting PBMS background tasks ..."
bash "${PBMS_DEV_ROOT}/scripts/start-pbms-bg-tasks.sh"

STAFF_API_URL="$(pbms_bg_tasks_staff_api_url)"
BRIDGE_API_URL="$(bridge_partner_api_url)"
if pbms_odoo_db_initialized; then
  echo "==> Configuring Odoo staff portal API URL (${STAFF_API_URL}) ..."
  pbms_odoo_set_staff_portal_api_url "${STAFF_API_URL}"
  if [[ "${PBMS_WITH_BRIDGE}" == "true" ]]; then
    echo "==> Configuring Odoo G2P Bridge API URL (${BRIDGE_API_URL}) ..."
    pbms_odoo_set_g2p_bridge_api_url "${BRIDGE_API_URL}"
  fi
fi

echo
echo "PBMS running (SPAR/Bridge are separate commands):"
echo "  Odoo             : http://localhost:${PBMS_HTTP_PORT:-8069}"
echo "  Staff Portal API : ${STAFF_API_URL}/docs"
if [[ "${PBMS_WITH_REGISTRY}" == "true" ]]; then
  echo "  Registry variant : ${PBMS_REGISTRY_VARIANT}"
fi
echo
echo "Disbursement pipeline (run in other terminals, in order):"
echo "  make spar-run          # SPAR mapper :8004"
echo "  make bridge-run        # G2P Bridge + Celery"
echo "  make verify-spar       # optional check"
echo "  make verify-bridge     # optional check"
echo
echo "Press Ctrl+C to stop Odoo (background services keep running in this shell)."
echo

echo "Starting PBMS Odoo using ${PBMS_ODOO_CONF}"
pbms_odoo_run "$@"
