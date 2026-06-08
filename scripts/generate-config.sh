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
FARMER_REGISTRY_STAFF_API_PORT="${FARMER_REGISTRY_STAFF_API_PORT:-8001}"
FARMER_REGISTRY_UI_PORT="${FARMER_REGISTRY_UI_PORT:-3000}"
NSR_REGISTRY_STAFF_API_PORT="${NSR_REGISTRY_STAFF_API_PORT:-8011}"
NSR_REGISTRY_UI_PORT="${NSR_REGISTRY_UI_PORT:-3010}"
G2P_BRIDGE_API_PORT="${G2P_BRIDGE_API_PORT:-8002}"
G2P_BRIDGE_EXAMPLE_BANK_PORT="${G2P_BRIDGE_EXAMPLE_BANK_PORT:-8003}"
SPAR_MAPPER_API_PORT="${SPAR_MAPPER_API_PORT:-8004}"
SPAR_BENE_API_PORT="${SPAR_BENE_API_PORT:-8005}"

mkdir -p \
  "${GENERATED_DIR}/farmer-registry" \
  "${GENERATED_DIR}/national-social-registry" \
  "${GENERATED_DIR}/bridge" \
  "${GENERATED_DIR}/spar" \
  "${GENERATED_DIR}/odoo"

render() {
  local template="$1"
  local output="$2"
  shift 2
  local content
  content="$(cat "$template")"
  while [[ $# -gt 0 ]]; do
    local key="$1"
    local value="$2"
    content="${content//${key}/${value}}"
    shift 2
  done
  printf '%s\n' "$content" > "$output"
  echo "Generated ${output}"
}

render_registry_variant() {
  local variant_dir="$1"
  local db_name="$2"
  local master_db_name="$3"
  local staff_api_port="$4"
  local ui_port="$5"
  local worker_queue="$6"
  local keycloak_client_id="$7"
  local ui_app_mnemonic="$8"
  local auth_enabled="${9:-false}"

  local common=(
    "{{OPENG2P_WORKSPACE}}" "${OPENG2P_WORKSPACE}"
    "{{ODOO_PATH}}" "${ODOO_PATH}"
    "{{POSTGRES_HOST}}" "${POSTGRES_HOST}"
    "{{POSTGRES_PORT}}" "${POSTGRES_PORT}"
    "{{POSTGRES_PASSWORD}}" "${POSTGRES_PASSWORD}"
    "{{REDIS_HOST}}" "${REDIS_HOST}"
    "{{REDIS_PORT}}" "${REDIS_PORT}"
    "{{MINIO_ENDPOINT}}" "${MINIO_ENDPOINT}"
    "{{MINIO_ROOT_USER}}" "${MINIO_ROOT_USER}"
    "{{MINIO_ROOT_PASSWORD}}" "${MINIO_ROOT_PASSWORD}"
    "{{KEYCLOAK_URL}}" "${KEYCLOAK_URL}"
    "{{REGISTRY_DB_NAME}}" "${db_name}"
    "{{REGISTRY_MASTER_DATA_DB_NAME}}" "${master_db_name}"
    "{{REGISTRY_STAFF_API_PORT}}" "${staff_api_port}"
    "{{REGISTRY_UI_PORT}}" "${ui_port}"
    "{{REGISTRY_WORKER_QUEUE}}" "${worker_queue}"
    "{{REGISTRY_KEYCLOAK_CLIENT_ID}}" "${keycloak_client_id}"
    "{{REGISTRY_UI_APP_MNEMONIC}}" "${ui_app_mnemonic}"
    "{{REGISTRY_AUTH_ENABLED}}" "${auth_enabled}"
  )

  render "${ROOT_DIR}/templates/registry-staff-portal-api.env.tpl" \
    "${GENERATED_DIR}/${variant_dir}/staff-portal-api.env" \
    "${common[@]}"

  render "${ROOT_DIR}/templates/registry-celery-workers.env.tpl" \
    "${GENERATED_DIR}/${variant_dir}/celery-workers.env" \
    "${common[@]}"

  render "${ROOT_DIR}/templates/registry-staff-portal-ui.env.tpl" \
    "${GENERATED_DIR}/${variant_dir}/staff-portal-ui.env" \
    "${common[@]}"
}

render "${ROOT_DIR}/templates/pbms-odoo.conf.tpl" "${GENERATED_DIR}/odoo/pbms-odoo.conf" \
  "{{OPENG2P_WORKSPACE}}" "${OPENG2P_WORKSPACE}" \
  "{{ODOO_PATH}}" "${ODOO_PATH}" \
  "{{POSTGRES_HOST}}" "${POSTGRES_HOST}" \
  "{{POSTGRES_PORT}}" "${POSTGRES_PORT}" \
  "{{PBMS_HTTP_PORT}}" "${PBMS_HTTP_PORT}"

render_registry_variant \
  "farmer-registry" \
  "farmer_registry_db" \
  "farmer_master_data_db" \
  "${FARMER_REGISTRY_STAFF_API_PORT}" \
  "${FARMER_REGISTRY_UI_PORT}" \
  "farmer_registry_worker_queue" \
  "farmer-registry-staff-portal" \
  "farmer-registry-staff-portal" \
  "false"

render_registry_variant \
  "national-social-registry" \
  "nsr_registry_db" \
  "nsr_master_data_db" \
  "${NSR_REGISTRY_STAFF_API_PORT}" \
  "${NSR_REGISTRY_UI_PORT}" \
  "nsr_registry_worker_queue" \
  "nsr-registry-staff-portal" \
  "nsr-registry-staff-portal" \
  "false"

for tpl in "${ROOT_DIR}"/templates/bridge-*.env.tpl "${ROOT_DIR}"/templates/spar-*.env.tpl; do
  [[ -f "$tpl" ]] || continue
  base="$(basename "$tpl" .tpl)"
  case "$base" in
    bridge-partner-api.env)
      out="${GENERATED_DIR}/bridge/partner-api.env"
      ;;
    bridge-celery-worker.env)
      out="${GENERATED_DIR}/bridge/celery-worker.env"
      ;;
    bridge-celery-beat.env)
      out="${GENERATED_DIR}/bridge/celery-beat.env"
      ;;
    bridge-example-bank.env)
      out="${GENERATED_DIR}/bridge/example-bank.env"
      ;;
    spar-mapper-partner-api.env)
      out="${GENERATED_DIR}/spar/mapper-partner-api.env"
      ;;
    spar-bene-portal-api.env)
      out="${GENERATED_DIR}/spar/bene-portal-api.env"
      ;;
    *)
      continue
      ;;
  esac
  render "${tpl}" "$out" \
    "{{POSTGRES_HOST}}" "${POSTGRES_HOST}" \
    "{{POSTGRES_PORT}}" "${POSTGRES_PORT}" \
    "{{POSTGRES_PASSWORD}}" "${POSTGRES_PASSWORD}" \
    "{{REDIS_HOST}}" "${REDIS_HOST}" \
    "{{REDIS_PORT}}" "${REDIS_PORT}" \
    "{{KEYCLOAK_URL}}" "${KEYCLOAK_URL}" \
    "{{G2P_BRIDGE_API_PORT}}" "${G2P_BRIDGE_API_PORT}" \
    "{{G2P_BRIDGE_EXAMPLE_BANK_PORT}}" "${G2P_BRIDGE_EXAMPLE_BANK_PORT}" \
    "{{SPAR_MAPPER_API_PORT}}" "${SPAR_MAPPER_API_PORT}" \
    "{{SPAR_BENE_API_PORT}}" "${SPAR_BENE_API_PORT}"
done

echo
echo "Generated configs are in ${GENERATED_DIR}"
