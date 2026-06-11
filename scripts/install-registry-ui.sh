#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/registry-variant.sh"

registry_variant_load_env
OPENG2P_WORKSPACE="$(registry_variant_resolve_path "$ROOT_DIR" "${OPENG2P_WORKSPACE:-../openg2p-workspace}")"

UI_DIRS=(
  "${FARMER_REGISTRY_UI_PATH:-${OPENG2P_WORKSPACE}/openg2p-registry-gen2-staff-portal-ui}"
  "${NSR_REGISTRY_UI_PATH:-${OPENG2P_WORKSPACE}/openg2p-registry-gen2-staff-portal-ui}"
  "${OPENG2P_WORKSPACE}/registry-platform/ui/staff-portal-ui"
)

installed=()

for ui_path in "${UI_DIRS[@]}"; do
  if [[ "$ui_path" != /* ]]; then
    ui_path="$(registry_variant_resolve_path "$ROOT_DIR" "$ui_path")"
  fi

  if [[ ! -d "$ui_path" || ! -f "${ui_path}/package.json" ]]; then
    continue
  fi

  duplicated=0
  if [[ ${#installed[@]} -gt 0 ]]; then
    for prev in "${installed[@]}"; do
      if [[ "$prev" == "$ui_path" ]]; then
        duplicated=1
        break
      fi
    done
  fi
  if [[ "$duplicated" -eq 1 ]]; then
    continue
  fi
  installed+=("$ui_path")

  echo "Installing staff portal UI dependencies in ${ui_path} ..."
  (
    cd "$ui_path"
    npm install
  )
done

if [[ ${#installed[@]} -eq 0 ]]; then
  echo "No staff portal UI repo found. Run: make clone" >&2
  exit 1
fi

echo "Staff portal UI dependencies installed."
