#!/usr/bin/env bash
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
IAM_API_DIR="${OPENG2P_WORKSPACE}/openg2p-iam-service/iam-staff-portal-api"
GENERATED_DIR="${ROOT_DIR}/generated/iam"
ENV_FILE="${GENERATED_DIR}/staff-portal-api.env"

"${ROOT_DIR}/scripts/infra-wait.sh"
"${ROOT_DIR}/scripts/generate-config.sh" >/dev/null

if [[ ! -d "$IAM_API_DIR" ]]; then
  echo "IAM service not found at ${IAM_API_DIR}. Run: make clone" >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing ${ENV_FILE}. Run: make generate" >&2
  exit 1
fi

if [[ ! -d "${IAM_API_DIR}/venv" ]]; then
  echo "IAM venv missing. Run: make install-iam" >&2
  exit 1
fi

POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_SUPERUSER="${POSTGRES_SUPERUSER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"

if ! PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_SUPERUSER}" -d postgres -tc \
  "SELECT 1 FROM pg_database WHERE datname = 'iam_staff'" | grep -q 1; then
  echo "Creating database iam_staff ..."
  PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_SUPERUSER}" -d postgres \
    -c "CREATE DATABASE iam_staff OWNER postgres"
fi

echo "============================================="
echo " Initializing IAM Staff Portal API"
echo "============================================="

(
  cd "$IAM_API_DIR"
  # shellcheck disable=SC1091
  source venv/bin/activate
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  python -m iam_staff_portal_api.main migrate
)

"${ROOT_DIR}/scripts/iam-ensure-registry-variant-applications.sh"

echo "IAM staff portal API initialized."
