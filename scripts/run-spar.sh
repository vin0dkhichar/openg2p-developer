#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash "${ROOT_DIR}/scripts/free-bridge-spar-ports.sh"
bash "${ROOT_DIR}/scripts/start-spar.sh"

echo
echo "SPAR stack running."
wait
