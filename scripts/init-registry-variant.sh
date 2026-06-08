#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VARIANT="${VARIANT:-${1:-}}"

"${ROOT_DIR}/scripts/migrate-registry-db.sh" "$VARIANT"
"${ROOT_DIR}/scripts/seed-registry-db.sh" "$VARIANT"

echo
echo "Registry variant ${VARIANT} is initialized (schema migrated + configuration seeded)."
echo "Optional demo data:"
echo "  LOAD_SAMPLE_DATA=true VARIANT=${VARIANT} make seed-registry"
