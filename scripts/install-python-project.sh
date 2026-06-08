#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

OPENG2P_WORKSPACE="${OPENG2P_WORKSPACE:-../openg2p-workspace}"
OPENG2P_WORKSPACE="$(cd "$ROOT_DIR" && cd "$OPENG2P_WORKSPACE" && pwd)"
PROJECT_DIR="$1"
VENV_NAME="${2:-venv}"

if [[ -z "${PROJECT_DIR}" ]]; then
  echo "Usage: $0 <project-dir> [venv-name]" >&2
  exit 1
fi

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Project directory not found: ${PROJECT_DIR}" >&2
  exit 1
fi

cd "$PROJECT_DIR"

if [[ ! -d "$VENV_NAME" ]]; then
  python3 -m venv "$VENV_NAME"
fi

# shellcheck disable=SC1091
source "${VENV_NAME}/bin/activate"
pip install --upgrade pip wheel

if [[ -f test-requirements.txt ]]; then
  pip install -r test-requirements.txt
fi

if [[ -f requirements.txt ]]; then
  pip install -r requirements.txt
fi

if [[ -f pyproject.toml ]]; then
  pip install -e .
fi

echo "Python environment ready in ${PROJECT_DIR}/${VENV_NAME}"
