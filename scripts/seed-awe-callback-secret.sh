#!/usr/bin/env bash
# Insert the registry ↔ AWE webhook HMAC secret (delete matching row, then insert).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

resolve_path() {
  local path="$1"
  if [[ "$path" != /* ]]; then
    path="${ROOT_DIR}/${path}"
  fi
  local dir part
  dir="$(dirname "$path")"
  part="$(basename "$path")"
  echo "$(cd "$dir" && pwd)/${part}"
}

OPENG2P_WORKSPACE="$(resolve_path "${OPENG2P_WORKSPACE:-../openg2p-workspace}")"

POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_SUPERUSER="${POSTGRES_SUPERUSER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
AWE_REGISTRY_CALLBACK_SECRET_ID="${AWE_REGISTRY_CALLBACK_SECRET_ID:-00000000-0000-4000-8000-000000000001}"
AWE_REGISTRY_CALLBACK_HMAC_SECRET="${AWE_REGISTRY_CALLBACK_HMAC_SECRET:-dev-registry-awe-callback-secret}"
AWE_CALLBACK_CALLER_SERVICE="${AWE_CALLBACK_CALLER_SERVICE:-registry}"

export PGHOST="${POSTGRES_HOST}"
export PGPORT="${POSTGRES_PORT}"
export PGUSER="${POSTGRES_SUPERUSER}"
export PGPASSWORD="${POSTGRES_PASSWORD}"
export PGDATABASE="${AWE_DB_NAME:-awe}"

if ! psql -tc "SELECT to_regclass('public.callback_secret')" | grep -q callback_secret; then
  echo "[awe-seed] callback_secret table not found. Start AWE once to create schema, then re-run: make awe-init" >&2
  exit 1
fi

AWE_CALLBACK_SECRET_ID="$AWE_REGISTRY_CALLBACK_SECRET_ID"
AWE_CALLBACK_HMAC_SECRET="$AWE_REGISTRY_CALLBACK_HMAC_SECRET"
export AWE_CALLBACK_SECRET_ID AWE_CALLBACK_HMAC_SECRET AWE_CALLBACK_CALLER_SERVICE

apply_script="${ROOT_DIR}/scripts/lib/apply_seed_sql.py"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/ensure-psycopg2-python.sh"
python_bin="$(ensure_psycopg2_python "$ROOT_DIR")"

tmp_sql="$(mktemp)"
trap 'rm -f "$tmp_sql"' EXIT
envsubst '${AWE_CALLBACK_HMAC_SECRET} ${AWE_CALLBACK_SECRET_ID} ${AWE_CALLBACK_CALLER_SERVICE}' \
  < "${ROOT_DIR}/scripts/sql/awe-callback-secret.sql.tpl" > "$tmp_sql"

echo "[awe-seed] Applying registry callback secret (delete + insert) ..."
"$python_bin" "$apply_script" "$tmp_sql"
echo "[awe-seed] Registry callback secret ready (id=${AWE_REGISTRY_CALLBACK_SECRET_ID})"
