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
IAM_ROOT="${OPENG2P_WORKSPACE}/openg2p-iam-service"
IAM_API_DIR="${IAM_ROOT}/iam-staff-portal-api"
IAM_CORE_DIR="${IAM_ROOT}/iam-core"

for dir in "$IAM_API_DIR" "$IAM_CORE_DIR"; do
  if [[ ! -d "$dir" ]]; then
    echo "Missing ${dir}. Run: make clone" >&2
    exit 1
  fi
done

if [[ ! -d "${IAM_API_DIR}/venv" ]]; then
  python3 -m venv "${IAM_API_DIR}/venv"
fi

(
  cd "$IAM_API_DIR"
  # shellcheck disable=SC1091
  source venv/bin/activate
  pip install --upgrade pip wheel
  if [[ -f requirements.txt ]]; then
    pip install -r requirements.txt
  fi
  pip install "$IAM_CORE_DIR" greenlet openg2p-fastapi-auth
  pip install "$IAM_API_DIR"
)

echo "Installed IAM staff portal API and iam-core."
