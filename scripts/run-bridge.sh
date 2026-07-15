#!/usr/bin/env bash
# Start G2P Bridge only. SPAR must already be running (make spar-run).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/bridge.sh"
bridge_load_env

if [[ "${BRIDGE_REQUIRE_SPAR:-true}" == "true" ]]; then
  if ! curl -sf "$(bridge_spar_mapper_url)/docs" >/dev/null 2>&1; then
    echo "ERROR: SPAR mapper API is not running on port ${SPAR_MAPPER_API_PORT}." >&2
    echo "  FA resolution requires SPAR. In another terminal run first:" >&2
    echo "    make spar-run" >&2
    echo "    make verify-spar" >&2
    echo "  Then run: make bridge-run" >&2
    echo "  (Set BRIDGE_REQUIRE_SPAR=false to start Bridge without SPAR.)" >&2
    exit 1
  fi
fi

bash "${ROOT_DIR}/scripts/start-bridge.sh"

echo
echo "G2P Bridge running."
echo "  Verify : make verify-bridge"
