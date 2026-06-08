#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_SUPERUSER="${POSTGRES_SUPERUSER:-postgres}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-60}"

echo "Waiting for Postgres at ${POSTGRES_HOST}:${POSTGRES_PORT}..."
for ((i = 1; i <= MAX_ATTEMPTS; i++)); do
  if docker compose -f compose/docker-compose.infra.yml exec -T postgres pg_isready -U "$POSTGRES_SUPERUSER" >/dev/null 2>&1; then
    echo "Postgres is ready."
    exit 0
  fi
  if command -v pg_isready >/dev/null 2>&1 && pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_SUPERUSER" >/dev/null 2>&1; then
    echo "Postgres is ready."
    exit 0
  fi
  sleep 2
done

echo "Timed out waiting for Postgres." >&2
exit 1
