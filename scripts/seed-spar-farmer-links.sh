#!/usr/bin/env bash
# Seed SPAR id_fa_mappings from farmer registry internal_record_id values.
# PBMS/Bridge beneficiary_id = registry internal_record_id (UUID).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/spar.sh"

spar_load_env

LIMIT="${SPAR_SEED_LIMIT:-500}"
BANK_CODE="${SPAR_EXAMPLE_BANK_CODE}"
BRANCH_CODE="${SPAR_EXAMPLE_BRANCH_CODE}"
REGISTRY_DB="${SPAR_REGISTRY_DB_NAME}"

if ! spar_db_migrated; then
  echo "SPAR database not migrated. Run: make init-spar" >&2
  exit 1
fi

echo "[spar-seed] Linking up to ${LIMIT} farmer registry IDs to example bank accounts in SPAR ..."

TMP_SQL="$(mktemp)"
trap 'rm -f "$TMP_SQL"' EXIT

{
  echo "BEGIN;"
  PGPASSWORD="${POSTGRES_PASSWORD}" psql \
    -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U postgres -d "${REGISTRY_DB}" \
    -At -F $'\t' \
    -c "SELECT internal_record_id, functional_record_id, COALESCE(first_name,''), COALESCE(last_name,'')
        FROM g2p_register_farmers
        ORDER BY internal_record_id
        LIMIT ${LIMIT};" \
  | while IFS=$'\t' read -r internal_id functional_id first_name last_name; do
      [[ -z "$internal_id" ]] && continue
      account_number="${functional_id//-/}"
      fa_value="account_number:${account_number}.branch_code:${BRANCH_CODE}.bank_code:${BANK_CODE}.mobile_number:.email_address:.fa_type:BANK_ACCOUNT"
      name="$(echo "${first_name} ${last_name}" | sed "s/'/''/g")"
      printf "INSERT INTO id_fa_mappings (id_value, fa_value, name, additional_info, active, created_at, updated_at)
VALUES ('%s', '%s', '%s', '[{\"strategy_id\": 5}]'::json, true, NOW(), NOW())
ON CONFLICT (id_value) DO UPDATE SET fa_value = EXCLUDED.fa_value, name = EXCLUDED.name, active = true, updated_at = NOW();\n" \
        "$internal_id" "$fa_value" "$name"
    done
  echo "COMMIT;"
} > "$TMP_SQL"

PGPASSWORD="${SPAR_DB_PASSWORD}" psql \
  -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${SPAR_DB_USER}" -d "${SPAR_DB_NAME}" \
  -v ON_ERROR_STOP=1 -f "$TMP_SQL"

LINKED="$(PGPASSWORD="${SPAR_DB_PASSWORD}" psql \
  -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${SPAR_DB_USER}" -d "${SPAR_DB_NAME}" \
  -tc "SELECT COUNT(*) FROM id_fa_mappings WHERE active = true;")"

echo "[spar-seed] SPAR now has ${LINKED} active ID→FA mappings."
