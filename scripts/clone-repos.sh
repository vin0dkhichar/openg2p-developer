#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

OPENG2P_WORKSPACE="${OPENG2P_WORKSPACE:-../openg2p-workspace}"
if [[ -d "$ROOT_DIR/$OPENG2P_WORKSPACE" ]]; then
  OPENG2P_WORKSPACE="$(cd "$ROOT_DIR/$OPENG2P_WORKSPACE" && pwd)"
elif [[ -d "$OPENG2P_WORKSPACE" ]]; then
  OPENG2P_WORKSPACE="$(cd "$OPENG2P_WORKSPACE" && pwd)"
else
  OPENG2P_WORKSPACE="$(cd "$ROOT_DIR" && cd "$OPENG2P_WORKSPACE" 2>/dev/null && pwd || echo "${ROOT_DIR}/${OPENG2P_WORKSPACE}")"
fi

clone_repo() {
  local name="$1"
  local url="$2"
  local ref="$3"
  local path="$4"

  local target="${OPENG2P_WORKSPACE}/${path}"
  if [[ -d "${target}/.git" ]]; then
    echo "==> Updating ${name} (${target})"
    git -C "$target" fetch --tags --prune origin
    git -C "$target" checkout "$ref" 2>/dev/null || git -C "$target" checkout -B "$ref" "origin/${ref}"
    git -C "$target" pull --ff-only origin "$ref" 2>/dev/null || true
  else
    echo "==> Cloning ${name} -> ${target}"
    mkdir -p "$(dirname "$target")"
    git clone --branch "$ref" --single-branch "$url" "$target" 2>/dev/null || {
      git clone "$url" "$target"
      git -C "$target" checkout "$ref"
    }
  fi
}

mkdir -p "$OPENG2P_WORKSPACE"

ODOO_REF="${ODOO_REF:-17.0}"
PBMS_REF="${PBMS_REF:-develop}"
SR_REF="${SR_REF:-develop}"
REGISTRY_REF="${REGISTRY_REF:-develop}"
G2P_BRIDGE_REF="${G2P_BRIDGE_REF:-develop}"
SPAR_REF="${SPAR_REF:-develop}"

clone_repo "Odoo 17" "https://github.com/odoo/odoo.git" "$ODOO_REF" "odoo17"
clone_repo "OpenG2P PBMS Odoo" "https://github.com/OpenG2P/openg2p-pbms-odoo.git" "$PBMS_REF" "openg2p-pbms-odoo"
clone_repo "OpenG2P PBMS Community Addons" "https://github.com/OpenG2P/openg2p-pbms-community-addons.git" "17.0-develop" "openg2p-pbms-community-addons"
clone_repo "OpenG2P PBMS Extensions" "https://github.com/OpenG2P/openg2p-pbms-odoo-extensions.git" "$PBMS_REF" "openg2p-pbms-odoo-extensions"
clone_repo "OpenG2P Registry Odoo" "https://github.com/OpenG2P/openg2p-registry.git" "17.0-develop" "openg2p-registry"
clone_repo "OpenG2P Social Registry" "https://github.com/OpenG2P/openg2p-social-registry.git" "$SR_REF" "openg2p-social-registry"
clone_repo "OpenG2P Social Registry Community Addons" "https://github.com/OpenG2P/openg2p-social-registry-community-addons.git" "$SR_REF" "openg2p-social-registry-community-addons"
clone_repo "OpenG2P Odoo Commons" "https://github.com/OpenG2P/openg2p-odoo-commons.git" "$SR_REF" "openg2p-odoo-commons"
clone_repo "Registry Platform" "https://github.com/OpenG2P/registry-platform.git" "$REGISTRY_REF" "registry-platform"
clone_repo "G2P Bridge" "https://github.com/OpenG2P/g2p-bridge.git" "$G2P_BRIDGE_REF" "g2p-bridge"
clone_repo "SPAR" "https://github.com/OpenG2P/openg2p-spar.git" "$SPAR_REF" "openg2p-spar"

echo
echo "All repositories are available under: ${OPENG2P_WORKSPACE}"
echo "Next: make generate && make infra-up"
