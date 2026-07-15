#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/pbms-odoo.sh"

pbms_odoo_load_env

if [[ ! -d "${ODOO_PATH}/.git" ]]; then
  echo "Odoo source missing at ${ODOO_PATH}. Run: make clone PROFILE=pbms" >&2
  exit 1
fi

pbms_odoo_install_python_deps

echo "Odoo environment ready."
echo "Next: make pbms-init && make pbms-run"
