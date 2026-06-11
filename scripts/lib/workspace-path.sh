#!/usr/bin/env bash
# Resolve OPENG2P_WORKSPACE to a normalized absolute directory path.

workspace_root_dir() {
  echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}

workspace_load_env() {
  local root
  root="$(workspace_root_dir)"
  if [[ -f "${root}/.env" ]]; then
    # shellcheck disable=SC1091
    source "${root}/.env"
  fi
}

workspace_default_path() {
  local root
  root="$(workspace_root_dir)"
  echo "${root}/../openg2p-workspace"
}

# Normalize a relative or absolute path to an absolute directory.
# Unlike dirname+basename splitting, this correctly resolves trailing ".." segments.
workspace_resolve() {
  local raw="${1:-$(workspace_default_path)}"
  local root resolved parent

  root="$(workspace_root_dir)"
  workspace_load_env

  if [[ -z "$raw" ]]; then
    raw="$(workspace_default_path)"
  fi

  local path="$raw"
  if [[ "$path" != /* ]]; then
    path="${root}/${path}"
  fi

  mkdir -p "$path"
  resolved="$(cd "$path" && pwd)"
  parent="$(cd "${root}/.." && pwd)"

  if [[ "$resolved" == "$root" ]]; then
    echo "OPENG2P_WORKSPACE must not be the openg2p-developer repo itself (${raw})." >&2
    echo "Use ../openg2p-workspace (default) or another dedicated directory." >&2
    exit 1
  fi

  if [[ "$resolved" == "$parent" ]]; then
    echo "OPENG2P_WORKSPACE resolves to the parent directory (${resolved})." >&2
    echo "Product repos would be cloned alongside openg2p-developer instead of inside a workspace folder." >&2
    echo "Set OPENG2P_WORKSPACE=../openg2p-workspace in .env" >&2
    exit 1
  fi

  echo "$resolved"
}

workspace_open() {
  workspace_resolve "${OPENG2P_WORKSPACE:-../openg2p-workspace}"
}
