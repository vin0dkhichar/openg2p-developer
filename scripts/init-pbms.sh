#!/usr/bin/env bash
# Bootstrap pbmsdb with Odoo core modules (first-time native PBMS setup).
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/pbms-odoo.sh"

pbms_odoo_load_env
"${PBMS_DEV_ROOT}/scripts/infra-wait.sh"
"${PBMS_DEV_ROOT}/scripts/generate-config.sh" >/dev/null
pbms_odoo_require_paths
pbms_odoo_install_python_deps

if pbms_odoo_db_initialized; then
  echo "[pbms-init] Database ${PBMS_DB_NAME} is already initialized."
  exit 0
fi

# queue_job is in server_wide_modules; install it during bootstrap.
PBMS_ODOO_INIT_MODULES="${PBMS_ODOO_INIT_MODULES:-base,queue_job}"

echo "[pbms-init] Initializing ${PBMS_DB_NAME} with modules: ${PBMS_ODOO_INIT_MODULES}"
echo "[pbms-init] This may take several minutes on first run ..."

pbms_odoo_run -d "${PBMS_DB_NAME}" -i "${PBMS_ODOO_INIT_MODULES}" --stop-after-init --without-demo=all

echo "[pbms-init] Done. Start Odoo with: make pbms-run"
echo "[pbms-init] Then open http://localhost:${PBMS_HTTP_PORT:-8069} (master password: admin)"
echo "[pbms-init] Install PBMS apps from the Odoo Apps menu, or rerun with:"
echo "[pbms-init]   PBMS_ODOO_INIT_MODULES=base,queue_job,g2p_pbms make pbms-init"
