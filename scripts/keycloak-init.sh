#!/usr/bin/env bash
# Idempotently create the OpenG2P local "staff" Keycloak realm, OIDC clients,
# roles, and a default developer user. Safe to re-run on every `make infra-up`.
set -euo pipefail

KEYCLOAK_URL="${KEYCLOAK_URL:-http://keycloak:8080}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-staff}"
IAM_STAFF_PORT="${IAM_STAFF_PORT:-8020}"
FARMER_REGISTRY_UI_PORT="${FARMER_REGISTRY_UI_PORT:-3000}"
NSR_REGISTRY_UI_PORT="${NSR_REGISTRY_UI_PORT:-3010}"
PBMS_HTTP_PORT="${PBMS_HTTP_PORT:-8069}"
G2P_BRIDGE_API_PORT="${G2P_BRIDGE_API_PORT:-8002}"
SPAR_MAPPER_API_PORT="${SPAR_MAPPER_API_PORT:-8004}"
SPAR_BENE_API_PORT="${SPAR_BENE_API_PORT:-8005}"
KEYCLOAK_IAM_CLIENT_SECRET="${KEYCLOAK_IAM_CLIENT_SECRET:-dev-iam-staff-secret}"
KEYCLOAK_AWE_RESOLVER_CLIENT_SECRET="${KEYCLOAK_AWE_RESOLVER_CLIENT_SECRET:-dev-awe-resolver-secret}"
AWE_UI_PORT="${AWE_UI_PORT:-8031}"
KEYCLOAK_DEV_USER="${KEYCLOAK_DEV_USER:-staff}"
KEYCLOAK_DEV_PASSWORD="${KEYCLOAK_DEV_PASSWORD:-staff}"

KCADM="${KCADM:-/opt/keycloak/bin/kcadm.sh}"

wait_for_keycloak() {
  local host="${KEYCLOAK_HOST:-keycloak}"
  local port="${KEYCLOAK_PORT:-8080}"
  local attempt

  for attempt in $(seq 1 60); do
    if (echo >"/dev/tcp/${host}/${port}") >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "Keycloak did not become ready at ${KEYCLOAK_URL}" >&2
  return 1
}

kc_login() {
  "${KCADM}" config credentials \
    --server "${KEYCLOAK_URL}" \
    --realm master \
    --user "${KEYCLOAK_ADMIN}" \
    --password "${KEYCLOAK_ADMIN_PASSWORD}" >/dev/null
}

realm_exists() {
  "${KCADM}" get "realms/${KEYCLOAK_REALM}" >/dev/null 2>&1
}

ensure_realm() {
  if realm_exists; then
    echo "[keycloak-init] Realm '${KEYCLOAK_REALM}' already exists"
    return 0
  fi

  echo "[keycloak-init] Creating realm '${KEYCLOAK_REALM}' ..."
  "${KCADM}" create realms \
    -s "realm=${KEYCLOAK_REALM}" \
    -s enabled=true \
    -s sslRequired=none \
    -s registrationAllowed=false \
    -s loginWithEmailAllowed=true \
    -s duplicateEmailsAllowed=false \
    -s resetPasswordAllowed=true \
    -s editUsernameAllowed=false \
    -s bruteForceProtected=false
}

client_internal_id() {
  local client_id="$1"
  "${KCADM}" get clients -r "${KEYCLOAK_REALM}" -q "clientId=${client_id}" --fields id 2>/dev/null \
    | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -1
}

ensure_client() {
  local client_id="$1"
  shift
  local internal_id
  internal_id="$(client_internal_id "${client_id}" || true)"

  if [[ -z "${internal_id}" ]]; then
    echo "[keycloak-init]   + client ${client_id}"
    "${KCADM}" create clients -r "${KEYCLOAK_REALM}" -s "clientId=${client_id}" "$@"
  else
    echo "[keycloak-init]   ~ client ${client_id}"
    "${KCADM}" update "clients/${internal_id}" -r "${KEYCLOAK_REALM}" "$@"
  fi
}

ensure_client_role() {
  local client_id="$1"
  local role_name="$2"
  local client_uuid
  client_uuid="$(client_internal_id "${client_id}")"
  [[ -n "${client_uuid}" ]] || return 0

  if "${KCADM}" get "clients/${client_uuid}/roles/${role_name}" -r "${KEYCLOAK_REALM}" >/dev/null 2>&1; then
    return 0
  fi

  echo "[keycloak-init]   + client role ${client_id}/${role_name}"
  "${KCADM}" create "clients/${client_uuid}/roles" -r "${KEYCLOAK_REALM}" -s "name=${role_name}" >/dev/null 2>&1 || true
}

assign_client_role() {
  local username="$1"
  local client_id="$2"
  local role_name="$3"

  if ! "${KCADM}" get users -r "${KEYCLOAK_REALM}" -q "username=${username}" --fields id >/dev/null 2>&1; then
    return 0
  fi

  "${KCADM}" add-roles \
    -r "${KEYCLOAK_REALM}" \
    --uusername "${username}" \
    --cclientid "${client_id}" \
    --rolename "${role_name}" >/dev/null 2>&1 || true
}

assign_realm_management_role() {
  local service_account_username="$1"
  local role_name="$2"

  "${KCADM}" add-roles \
    -r "${KEYCLOAK_REALM}" \
    --uusername "${service_account_username}" \
    --cclientid realm-management \
    --rolename "${role_name}" >/dev/null 2>&1 || true
}

ensure_dev_user() {
  local user_id
  user_id="$("${KCADM}" get users -r "${KEYCLOAK_REALM}" -q "username=${KEYCLOAK_DEV_USER}" --fields id 2>/dev/null \
    | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -1)"

  if [[ -z "${user_id}" ]]; then
    echo "[keycloak-init] Creating dev user '${KEYCLOAK_DEV_USER}' (password: ${KEYCLOAK_DEV_PASSWORD})"
    "${KCADM}" create users -r "${KEYCLOAK_REALM}" \
      -s "username=${KEYCLOAK_DEV_USER}" \
      -s enabled=true \
      -s email="${KEYCLOAK_DEV_USER}@localhost" \
      -s emailVerified=true \
      -s firstName=Local \
      -s lastName=Developer
  fi

  echo "[keycloak-init] Ensuring dev user '${KEYCLOAK_DEV_USER}' password"
  "${KCADM}" set-password -r "${KEYCLOAK_REALM}" \
    --username "${KEYCLOAK_DEV_USER}" \
    --new-password "${KEYCLOAK_DEV_PASSWORD}" \
    --temporary=false

  for role in \
    "Operations Administrator" \
    "Technical Administrator" \
    "Data Supervisor"; do
    assign_client_role "${KEYCLOAK_DEV_USER}" "nsr-registry-staff-portal" "${role}"
    assign_client_role "${KEYCLOAK_DEV_USER}" "farmer-registry-staff-portal" "${role}"
  done

  assign_client_role "${KEYCLOAK_DEV_USER}" "awe-admin-portal" "AWE_ADMIN"
}

ensure_awe_clients() {
  ensure_client "awe-admin-portal" \
    -s enabled=true \
    -s publicClient=true \
    -s standardFlowEnabled=true \
    -s directAccessGrantsEnabled=true \
    -s 'redirectUris=["http://localhost:'"${AWE_UI_PORT}"'/*"]' \
    -s 'webOrigins=["http://localhost:'"${AWE_UI_PORT}"'"]'

  ensure_client_role "awe-admin-portal" "AWE_ADMIN"
  ensure_client_role "awe-admin-portal" "AWE_VIEWER"

  ensure_client "awe-admin-resolver" \
    -s enabled=true \
    -s publicClient=false \
    -s secret="${KEYCLOAK_AWE_RESOLVER_CLIENT_SECRET}" \
    -s serviceAccountsEnabled=true \
    -s standardFlowEnabled=false \
    -s directAccessGrantsEnabled=false

  for role in view-users view-clients query-groups; do
    assign_realm_management_role "service-account-awe-admin-resolver" "${role}"
  done
}

echo "[keycloak-init] Waiting for Keycloak at ${KEYCLOAK_URL} ..."
wait_for_keycloak
kc_login
ensure_realm

echo "[keycloak-init] Ensuring OIDC clients in realm '${KEYCLOAK_REALM}' ..."

# IAM Staff Portal API — confidential client used for the browser SSO code flow.
ensure_client "iam-staff-portal" \
  -s enabled=true \
  -s publicClient=false \
  -s secret="${KEYCLOAK_IAM_CLIENT_SECRET}" \
  -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=true \
  -s serviceAccountsEnabled=false \
  -s 'redirectUris=["http://localhost:'"${IAM_STAFF_PORT}"'/auth/callback"]' \
  -s 'webOrigins=["+"]'

ensure_client "nsr-registry-staff-portal" \
  -s enabled=true \
  -s publicClient=true \
  -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=true \
  -s 'redirectUris=["http://localhost:'"${NSR_REGISTRY_UI_PORT}"'/*"]' \
  -s 'webOrigins=["http://localhost:'"${NSR_REGISTRY_UI_PORT}"'"]'

ensure_client "farmer-registry-staff-portal" \
  -s enabled=true \
  -s publicClient=true \
  -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=true \
  -s 'redirectUris=["http://localhost:'"${FARMER_REGISTRY_UI_PORT}"'/*"]' \
  -s 'webOrigins=["http://localhost:'"${FARMER_REGISTRY_UI_PORT}"'"]'

ensure_client "g2p-bridge" \
  -s enabled=true \
  -s publicClient=false \
  -s secret=dev-g2p-bridge-secret \
  -s serviceAccountsEnabled=true \
  -s standardFlowEnabled=false \
  -s directAccessGrantsEnabled=true \
  -s 'redirectUris=["http://localhost:'"${G2P_BRIDGE_API_PORT}"'/*"]' \
  -s 'webOrigins=["+"]'

ensure_client "spar-mapper" \
  -s enabled=true \
  -s publicClient=false \
  -s secret=dev-spar-mapper-secret \
  -s serviceAccountsEnabled=true \
  -s standardFlowEnabled=false \
  -s directAccessGrantsEnabled=true \
  -s 'redirectUris=["http://localhost:'"${SPAR_MAPPER_API_PORT}"'/*"]' \
  -s 'webOrigins=["+"]'

ensure_client "spar-bene-portal" \
  -s enabled=true \
  -s publicClient=true \
  -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=true \
  -s 'redirectUris=["http://localhost:'"${SPAR_BENE_API_PORT}"'/*"]' \
  -s 'webOrigins=["+"]'

ensure_client "openg2p-pbms-local" \
  -s enabled=true \
  -s publicClient=true \
  -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=true \
  -s 'redirectUris=["http://localhost:'"${PBMS_HTTP_PORT}"'/*"]' \
  -s 'webOrigins=["http://localhost:'"${PBMS_HTTP_PORT}"'"]'

ensure_awe_clients

for role in \
  "Operations Administrator" \
  "Technical Administrator" \
  "Data Supervisor" \
  "Intake Officer" \
  "Data Editor"; do
  ensure_client_role "nsr-registry-staff-portal" "${role}"
  ensure_client_role "farmer-registry-staff-portal" "${role}"
done

ensure_dev_user

echo "[keycloak-init] Done. Realm: ${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}"
echo "[keycloak-init] Dev login: ${KEYCLOAK_DEV_USER} / ${KEYCLOAK_DEV_PASSWORD}"
