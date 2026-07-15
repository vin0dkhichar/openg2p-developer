#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/spar.sh"

spar_load_env
"${ROOT_DIR}/scripts/infra-wait.sh"
"${ROOT_DIR}/scripts/generate-config.sh" >/dev/null
spar_require_paths

if ! spar_installed; then
  echo "SPAR venvs missing. Run: make install-spar" >&2
  exit 1
fi

for svc in "$MAPPER_API_DIR:$MAPPER_API_ENV:mapper-partner-api" \
  "$BENE_API_DIR:$BENE_API_ENV:bene-portal-api"; do
  IFS=: read -r dir env_file label <<< "$svc"
  echo "[spar-init] Migrating ${SPAR_DB_NAME} via ${label} ..."
  (
    cd "$dir"
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
    # shellcheck disable=SC1091
    source venv/bin/activate
    python main.py migrate
  )
done

echo "[spar-init] Seeding SPAR strategies ..."
PGPASSWORD="${SPAR_DB_PASSWORD}" psql \
  -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${SPAR_DB_USER}" -d "${SPAR_DB_NAME}" \
  -v ON_ERROR_STOP=1 -f "${ROOT_DIR}/scripts/spar-init/01-strategies.sql"

echo "[spar-init] Done."
