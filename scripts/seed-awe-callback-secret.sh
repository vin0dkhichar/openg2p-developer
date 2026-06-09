#!/usr/bin/env bash
# Insert the registry ↔ AWE webhook HMAC secret (idempotent).
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
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
AWE_REGISTRY_CALLBACK_SECRET_ID="${AWE_REGISTRY_CALLBACK_SECRET_ID:-00000000-0000-4000-8000-000000000001}"
AWE_REGISTRY_CALLBACK_HMAC_SECRET="${AWE_REGISTRY_CALLBACK_HMAC_SECRET:-dev-registry-awe-callback-secret}"

if ! PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_SUPERUSER}" -d awe -tc \
  "SELECT to_regclass('public.callback_secret')" | grep -q callback_secret; then
  echo "[awe-seed] callback_secret table not found. Start AWE once to create schema, then re-run: make awe-init" >&2
  exit 1
fi

PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_SUPERUSER}" -d awe -v ON_ERROR_STOP=1 <<SQL
INSERT INTO callback_secret (id, caller_service, secret_hash, status, created_at, updated_at)
VALUES (
  '${AWE_REGISTRY_CALLBACK_SECRET_ID}',
  'registry',
  '${AWE_REGISTRY_CALLBACK_HMAC_SECRET}',
  'active',
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE
  SET secret_hash = EXCLUDED.secret_hash,
      status = 'active',
      updated_at = NOW();
SQL

echo "[awe-seed] Registry callback secret ready (id=${AWE_REGISTRY_CALLBACK_SECRET_ID})"
