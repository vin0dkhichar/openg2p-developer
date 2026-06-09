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
AWE_DIR="${OPENG2P_WORKSPACE}/awe"
ENV_FILE="${ROOT_DIR}/generated/awe/awe-api.env"

"${ROOT_DIR}/scripts/infra-wait.sh"
"${ROOT_DIR}/scripts/generate-config.sh" >/dev/null

if [[ ! -d "$AWE_DIR" ]]; then
  echo "AWE repo not found at ${AWE_DIR}. Run: make clone && make install-awe" >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing ${ENV_FILE}. Run: make generate" >&2
  exit 1
fi

if [[ ! -d "${AWE_DIR}/venv" ]]; then
  echo "AWE venv missing. Run: make install-awe" >&2
  exit 1
fi

echo "Starting AWE API from ${AWE_DIR} on port ${AWE_API_PORT:-8030} ..."
(
  cd "$AWE_DIR"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
  # shellcheck disable=SC1091
  source venv/bin/activate
  exec uvicorn awe.main:app \
    --host "${UVICORN_HOST:-0.0.0.0}" \
    --port "${UVICORN_PORT:-8030}" \
    --log-level info
)
