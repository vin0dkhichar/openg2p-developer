#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/pbms-odoo.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/pbms-bg-tasks.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/bridge.sh"
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/spar.sh"

pbms_odoo_load_env
pbms_bg_tasks_load_env
bridge_load_env
spar_load_env

PBMS_WITH_BRIDGE="${PBMS_WITH_BRIDGE:-true}"
PBMS_WITH_SPAR="${PBMS_WITH_SPAR:-true}"

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

bash "${PBMS_DEV_ROOT}/scripts/free-pbms-ports.sh"

if [[ "${PBMS_WITH_SPAR}" == "true" ]]; then
  bash "${PBMS_DEV_ROOT}/scripts/free-bridge-spar-ports.sh"
fi

if [[ "${PBMS_WITH_REGISTRY}" == "true" ]]; then
  # shellcheck disable=SC1091
  source "${PBMS_DEV_ROOT}/scripts/lib/registry-variant.sh"
  if registry_variant_validate "${PBMS_REGISTRY_VARIANT}" 2>/dev/null; then
    echo "==> Starting registry (${PBMS_REGISTRY_VARIANT}) ..."
    bash "${PBMS_DEV_ROOT}/scripts/free-variant-ports.sh" "${PBMS_REGISTRY_VARIANT}"
    bash "${PBMS_DEV_ROOT}/scripts/start-registry-variant.sh" "${PBMS_REGISTRY_VARIANT}"
  else
    echo "Registry variant '${PBMS_REGISTRY_VARIANT}' is not available. Set PBMS_WITH_REGISTRY=false or run make clone PROFILE=pbms." >&2
    exit 1
  fi
fi

if [[ "${PBMS_WITH_SPAR}" == "true" ]]; then
  echo "==> Starting SPAR (mapper + bene portal) ..."
  bash "${PBMS_DEV_ROOT}/scripts/start-spar.sh"
fi

if [[ "${PBMS_WITH_BRIDGE}" == "true" ]]; then
  echo "==> Starting G2P Bridge (partner API + Celery + example bank) ..."
  bash "${PBMS_DEV_ROOT}/scripts/start-bridge.sh"
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
echo "PBMS stack running:"
echo "  Odoo             : http://localhost:${PBMS_HTTP_PORT:-8069}"
echo "  Staff Portal API : ${STAFF_API_URL}/docs"
if [[ "${PBMS_WITH_BRIDGE}" == "true" ]]; then
  echo "  G2P Bridge API   : ${BRIDGE_API_URL}/docs"
  echo "  Example bank API : $(bridge_example_bank_url)/docs"
fi
if [[ "${PBMS_WITH_SPAR}" == "true" ]]; then
  echo "  SPAR mapper API  : $(spar_mapper_api_url)/docs"
  echo "  SPAR bene API    : http://localhost:${SPAR_BENE_API_PORT}/docs"
fi
if [[ "${PBMS_WITH_REGISTRY}" == "true" ]]; then
  echo "  Registry variant : ${PBMS_REGISTRY_VARIANT}"
fi
echo
echo "Press Ctrl+C to stop Odoo (background services keep running in this shell)."
echo

echo "Starting PBMS Odoo using ${PBMS_ODOO_CONF}"
pbms_odoo_run "$@"
