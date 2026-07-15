#!/usr/bin/env bash
# Resolve a Python interpreter with psycopg2 for apply_seed_sql.py and related tools.

ensure_psycopg2_python() {
  local root="${1:-}"
  if [[ -z "$root" ]]; then
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  fi

  local -a candidates=()

  if [[ -n "${DB_SEED_DIR:-}" && -x "${DB_SEED_DIR}/venv/bin/python" ]]; then
    candidates+=("${DB_SEED_DIR}/venv/bin/python")
  fi

  local workspace="${OPENG2P_WORKSPACE:-${root}/../openg2p-workspace}"
  if [[ "$workspace" != /* ]]; then
    workspace="${root}/${workspace}"
  fi
  workspace="$(cd "$workspace" && pwd)"

  candidates+=(
    "${workspace}/farmer-registry/docker/db-seed/venv/bin/python"
    "${workspace}/national-social-registry/docker/db-seed/venv/bin/python"
    "${root}/.venv-psycopg2/bin/python"
  )

  local py
  for py in "${candidates[@]}"; do
    if [[ -x "$py" ]] && "$py" -c "import psycopg2" >/dev/null 2>&1; then
      echo "$py"
      return 0
    fi
  done

  local venv="${root}/.venv-psycopg2"
  if [[ ! -x "${venv}/bin/python" ]]; then
    echo "[psycopg2] Creating ${venv} ..." >&2
    python3 -m venv "$venv"
  fi

  if ! "${venv}/bin/python" -c "import psycopg2" >/dev/null 2>&1; then
    echo "[psycopg2] Installing psycopg2-binary into ${venv} ..." >&2
    "${venv}/bin/pip" install -q --upgrade pip >&2
    "${venv}/bin/pip" install -q 'psycopg2-binary>=2.9.12' >&2
  fi

  echo "${venv}/bin/python"
}
