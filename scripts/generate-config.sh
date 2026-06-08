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
ODOO_PATH="${ODOO_PATH:-${OPENG2P_WORKSPACE}/odoo17}"
GENERATED_DIR="${ROOT_DIR}/generated"

POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
MINIO_ENDPOINT="${MINIO_ENDPOINT:-localhost:9000}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-admin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-secret}"
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"

PBMS_HTTP_PORT="${PBMS_HTTP_PORT:-8069}"
SR_HTTP_PORT="${SR_HTTP_PORT:-8070}"
REGISTRY_STAFF_API_PORT="${REGISTRY_STAFF_API_PORT:-8001}"
REGISTRY_UI_PORT="${REGISTRY_UI_PORT:-3000}"
G2P_BRIDGE_API_PORT="${G2P_BRIDGE_API_PORT:-8002}"
G2P_BRIDGE_EXAMPLE_BANK_PORT="${G2P_BRIDGE_EXAMPLE_BANK_PORT:-8003}"
SPAR_MAPPER_API_PORT="${SPAR_MAPPER_API_PORT:-8004}"
SPAR_BENE_API_PORT="${SPAR_BENE_API_PORT:-8005}"

mkdir -p \
  "${GENERATED_DIR}/registry" \
  "${GENERATED_DIR}/bridge" \
  "${GENERATED_DIR}/spar" \
  "${GENERATED_DIR}/odoo"

render() {
  local template="$1"
  local output="$2"
  sed \
    -e "s|{{OPENG2P_WORKSPACE}}|${OPENG2P_WORKSPACE}|g" \
    -e "s|{{ODOO_PATH}}|${ODOO_PATH}|g" \
    -e "s|{{POSTGRES_HOST}}|${POSTGRES_HOST}|g" \
    -e "s|{{POSTGRES_PORT}}|${POSTGRES_PORT}|g" \
    -e "s|{{POSTGRES_PASSWORD}}|${POSTGRES_PASSWORD}|g" \
    -e "s|{{REDIS_HOST}}|${REDIS_HOST}|g" \
    -e "s|{{REDIS_PORT}}|${REDIS_PORT}|g" \
    -e "s|{{MINIO_ENDPOINT}}|${MINIO_ENDPOINT}|g" \
    -e "s|{{MINIO_ROOT_USER}}|${MINIO_ROOT_USER}|g" \
    -e "s|{{MINIO_ROOT_PASSWORD}}|${MINIO_ROOT_PASSWORD}|g" \
    -e "s|{{KEYCLOAK_URL}}|${KEYCLOAK_URL}|g" \
    -e "s|{{PBMS_HTTP_PORT}}|${PBMS_HTTP_PORT}|g" \
    -e "s|{{SR_HTTP_PORT}}|${SR_HTTP_PORT}|g" \
    -e "s|{{REGISTRY_STAFF_API_PORT}}|${REGISTRY_STAFF_API_PORT}|g" \
    -e "s|{{REGISTRY_UI_PORT}}|${REGISTRY_UI_PORT}|g" \
    -e "s|{{G2P_BRIDGE_API_PORT}}|${G2P_BRIDGE_API_PORT}|g" \
    -e "s|{{G2P_BRIDGE_EXAMPLE_BANK_PORT}}|${G2P_BRIDGE_EXAMPLE_BANK_PORT}|g" \
    -e "s|{{SPAR_MAPPER_API_PORT}}|${SPAR_MAPPER_API_PORT}|g" \
    -e "s|{{SPAR_BENE_API_PORT}}|${SPAR_BENE_API_PORT}|g" \
    "$template" > "$output"
  echo "Generated ${output}"
}

for tpl in "${ROOT_DIR}/templates/"*.tpl; do
  base="$(basename "$tpl" .tpl)"
  case "$base" in
    pbms-odoo.conf)
      render "$tpl" "${GENERATED_DIR}/odoo/pbms-odoo.conf"
      ;;
    sr-odoo.conf)
      render "$tpl" "${GENERATED_DIR}/odoo/sr-odoo.conf"
      ;;
    registry-staff-portal-api.env)
      render "$tpl" "${GENERATED_DIR}/registry/staff-portal-api.env"
      ;;
    registry-celery-workers.env)
      render "$tpl" "${GENERATED_DIR}/registry/celery-workers.env"
      ;;
    registry-staff-portal-ui.env)
      render "$tpl" "${GENERATED_DIR}/registry/staff-portal-ui.env"
      ;;
    bridge-partner-api.env)
      render "$tpl" "${GENERATED_DIR}/bridge/partner-api.env"
      ;;
    bridge-celery-worker.env)
      render "$tpl" "${GENERATED_DIR}/bridge/celery-worker.env"
      ;;
    bridge-celery-beat.env)
      render "$tpl" "${GENERATED_DIR}/bridge/celery-beat.env"
      ;;
    bridge-example-bank.env)
      render "$tpl" "${GENERATED_DIR}/bridge/example-bank.env"
      ;;
    spar-mapper-partner-api.env)
      render "$tpl" "${GENERATED_DIR}/spar/mapper-partner-api.env"
      ;;
    spar-bene-portal-api.env)
      render "$tpl" "${GENERATED_DIR}/spar/bene-portal-api.env"
      ;;
  esac
done

echo
echo "Generated configs are in ${GENERATED_DIR}"
