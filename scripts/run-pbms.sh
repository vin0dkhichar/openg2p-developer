#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

OPENG2P_WORKSPACE="${OPENG2P_WORKSPACE:-../openg2p-workspace}"
OPENG2P_WORKSPACE="$(cd "$ROOT_DIR" && cd "$OPENG2P_WORKSPACE" && pwd)"
ODOO_PATH="${ODOO_PATH:-${OPENG2P_WORKSPACE}/odoo17}"
CONF="${ROOT_DIR}/generated/odoo/pbms-odoo.conf"

"${ROOT_DIR}/scripts/infra-wait.sh"

if [[ ! -f "$CONF" ]]; then
  echo "Missing ${CONF}. Run: make generate" >&2
  exit 1
fi

if [[ ! -f "${ODOO_PATH}/odoo-bin" ]]; then
  echo "Odoo not found at ${ODOO_PATH}. Run: make clone" >&2
  exit 1
fi

if [[ -x "${ODOO_PATH}/venv/bin/python" ]]; then
  PYTHON="${ODOO_PATH}/venv/bin/python"
else
  PYTHON="python3"
fi

echo "Starting PBMS Odoo using ${CONF}"
exec "${PYTHON}" "${ODOO_PATH}/odoo-bin" -c "$CONF" "$@"
