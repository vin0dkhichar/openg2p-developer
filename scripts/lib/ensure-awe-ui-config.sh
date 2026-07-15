#!/usr/bin/env bash
# Copy generated Keycloak runtime config into the AWE admin UI public/ tree.
set -euo pipefail

ui_dir="${1:?UI directory required}"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
generated="${root_dir}/generated/awe/admin-ui.config.json"
dest="${ui_dir}/public/config.json"

if [[ ! -f "$generated" ]]; then
  echo "[awe-ui] Missing ${generated}. Run: make generate" >&2
  exit 1
fi

mkdir -p "$(dirname "$dest")"
cp "$generated" "$dest"
echo "[awe-ui] Wrote ${dest} (Keycloak login via awe-admin-portal; dev user: staff/staff)"
