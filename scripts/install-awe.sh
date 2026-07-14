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

install_awe_editable() {
  local pyproject="${AWE_DIR}/pyproject.toml"
  local backup=""
  if [[ -f "$pyproject" ]] && grep -qE '^version[[:space:]]*=[[:space:]]*"develop"[[:space:]]*$' "$pyproject"; then
    # Upstream AWE uses version = "develop" (not PEP 440). Patch temporarily for pip install -e .
    backup="${pyproject}.openg2p-dev.bak"
    cp "$pyproject" "$backup"
    sed -i 's/^version = "develop"/version = "0.0.0.dev0"/' "$pyproject"
  fi

  (
    cd "$AWE_DIR"
    # shellcheck disable=SC1091
    source venv/bin/activate
    pip install --upgrade pip wheel
    pip install -e .
  )

  if [[ -n "$backup" && -f "$backup" ]]; then
    mv -f "$backup" "$pyproject"
  fi
}

install_awe_editable

if [[ -d "${AWE_DIR}/ui" ]] && command -v npm >/dev/null 2>&1; then
  echo "Installing AWE admin UI dependencies ..."
  (
    cd "${AWE_DIR}/ui"
    if [[ -f package-lock.json ]]; then
      npm ci
    else
      npm install
    fi
  )
  bash "${ROOT_DIR}/scripts/generate-config.sh" >/dev/null
  AWE_API_PORT="${AWE_API_PORT:-8030}" AWE_UI_PORT="${AWE_UI_PORT:-8031}" \
    bash "${ROOT_DIR}/scripts/lib/ensure-awe-ui-vite-config.sh" "${AWE_DIR}/ui"
  bash "${ROOT_DIR}/scripts/lib/ensure-awe-ui-config.sh" "${AWE_DIR}/ui"
else
  echo "Skipping AWE admin UI install (ui/ missing or npm not on PATH)."
fi

echo "Installed Approval Workflow Engine (AWE) in ${AWE_DIR}/venv"
