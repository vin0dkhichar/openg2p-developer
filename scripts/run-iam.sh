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
IAM_API_DIR="${OPENG2P_WORKSPACE}/iam-service/iam-staff-portal-api"
ENV_FILE="${ROOT_DIR}/generated/iam/staff-portal-api.env"

"${ROOT_DIR}/scripts/infra-wait.sh"
"${ROOT_DIR}/scripts/generate-config.sh" >/dev/null

if [[ ! -d "$IAM_API_DIR" ]]; then
  echo "IAM service not found at ${IAM_API_DIR}. Run: make clone && make install-iam" >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing ${ENV_FILE}. Run: make generate" >&2
  exit 1
fi

echo "Starting IAM staff portal API from ${IAM_API_DIR} ..."
(
  cd "$IAM_API_DIR"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  # shellcheck disable=SC1091
  source venv/bin/activate
  exec python -m iam_staff_portal_api.main run
)
