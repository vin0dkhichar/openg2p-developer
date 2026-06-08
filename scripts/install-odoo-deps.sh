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

if [[ ! -d "${ODOO_PATH}/.git" ]]; then
  echo "Odoo source missing at ${ODOO_PATH}. Run: make clone" >&2
  exit 1
fi

if [[ ! -d "${ODOO_PATH}/venv" ]]; then
  echo "Creating Odoo virtualenv at ${ODOO_PATH}/venv"
  python3 -m venv "${ODOO_PATH}/venv"
fi

# shellcheck disable=SC1091
source "${ODOO_PATH}/venv/bin/activate"

echo "Installing Odoo Python dependencies (first run may take several minutes)..."
pip install --upgrade pip wheel
pip install -r "${ODOO_PATH}/requirements.txt"

echo "Odoo environment ready."
echo "Run PBMS with: make pbms-run"
