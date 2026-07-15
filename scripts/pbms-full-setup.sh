#!/usr/bin/env bash
# One-time bootstrap: PBMS + registry + SPAR + G2P Bridge for end-to-end disbursement.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

export PBMS_WITH_REGISTRY="${PBMS_WITH_REGISTRY:-true}"
export PBMS_WITH_SPAR="${PBMS_WITH_SPAR:-true}"
export PBMS_WITH_BRIDGE="${PBMS_WITH_BRIDGE:-true}"

echo "==> PBMS + registry bootstrap ..."
make pbms-setup

echo "==> Cloning SPAR + G2P Bridge (if missing) ..."
make clone PROFILE=spar
make clone PROFILE=bridge

echo "==> Installing SPAR + Bridge Python deps ..."
make install-spar
make install-bridge

echo "==> Migrating SPAR + Bridge databases ..."
make init-spar
make init-bridge

echo "==> Seeding SPAR ID→bank account links from farmer registry ..."
make seed-spar-farmer-links

echo
echo "Full PBMS + SPAR + Bridge setup complete."
echo "  Start stack: make pbms-run"
echo "  Odoo        : http://localhost:${PBMS_HTTP_PORT:-8069}"
echo "  PBMS API    : http://localhost:${PBMS_STAFF_API_PORT:-8050}/docs"
echo "  Bridge API  : http://localhost:${G2P_BRIDGE_API_PORT:-8002}/docs"
echo "  SPAR mapper : http://localhost:${SPAR_MAPPER_API_PORT:-8004}/docs"
