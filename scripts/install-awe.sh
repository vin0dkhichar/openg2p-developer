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

if [[ ! -d "$AWE_DIR" ]]; then
  echo "AWE repo not found at ${AWE_DIR}. Run: make clone" >&2
  exit 1
fi

if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)'; then
  echo "AWE requires Python 3.11+. Found: $(python3 --version)" >&2
  exit 1
fi

if [[ ! -d "${AWE_DIR}/venv" ]]; then
  python3 -m venv "${AWE_DIR}/venv"
fi

(
  cd "$AWE_DIR"
  # shellcheck disable=SC1091
  source venv/bin/activate
  pip install --upgrade pip wheel
  pip install -e .
)

echo "Installed Approval Workflow Engine (AWE) in ${AWE_DIR}/venv"
