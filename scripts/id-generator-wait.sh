#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

ID_GENERATOR_PORT="${ID_GENERATOR_PORT:-8040}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-60}"
HEALTH_URL="http://localhost:${ID_GENERATOR_PORT}/v1/idgenerator/health"

echo "Waiting for ID Generator at ${HEALTH_URL} ..."
for ((i = 1; i <= MAX_ATTEMPTS; i++)); do
  if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
    echo "ID Generator is ready."
    exit 0
  fi
  sleep 2
done

echo "Timed out waiting for ID Generator." >&2
echo "Start it with: make infra-up" >&2
echo "Health check: curl ${HEALTH_URL}" >&2
exit 1
