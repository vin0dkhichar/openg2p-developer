#!/usr/bin/env bash
# Shared helpers for native PBMS Odoo (init + run).

pbms_odoo_load_env() {
  PBMS_DEV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  cd "$PBMS_DEV_ROOT"

  if [[ -f .env ]]; then
    # shellcheck disable=SC1091
    source .env
  fi

  OPENG2P_WORKSPACE="${OPENG2P_WORKSPACE:-../openg2p-workspace}"
  OPENG2P_WORKSPACE="$(cd "$PBMS_DEV_ROOT" && cd "$OPENG2P_WORKSPACE" && pwd)"
  ODOO_PATH="${ODOO_PATH:-${OPENG2P_WORKSPACE}/odoo17}"
  PBMS_PATH="${PBMS_PATH:-${OPENG2P_WORKSPACE}/pbms}"
  PBMS_ODOO_CONF="${PBMS_DEV_ROOT}/generated/odoo/pbms-odoo.conf"
  PBMS_DB_NAME="${PBMS_DB_NAME:-pbmsdb}"
  PBMS_DB_USER="${PBMS_DB_USER:-pbmsuser}"
  PBMS_DB_PASSWORD="${PBMS_DB_PASSWORD:-pbmspass}"
  POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
  POSTGRES_PORT="${POSTGRES_PORT:-5432}"
}

pbms_odoo_python_bin() {
  if [[ -x "${ODOO_PATH}/venv/bin/python" ]]; then
    echo "${ODOO_PATH}/venv/bin/python"
  else
    echo "python3"
  fi
}

pbms_odoo_require_paths() {
  if [[ ! -f "${ODOO_PATH}/odoo-bin" ]]; then
    echo "Odoo not found at ${ODOO_PATH}. Run: make clone PROFILE=pbms" >&2
    return 1
  fi
  if [[ ! -d "${PBMS_PATH}/odoo/g2p_pbms" ]]; then
    echo "PBMS Odoo modules not found at ${PBMS_PATH}/odoo. Run: make clone PROFILE=pbms" >&2
    return 1
  fi
  if [[ ! -f "$PBMS_ODOO_CONF" ]]; then
    echo "Missing ${PBMS_ODOO_CONF}. Run: make generate" >&2
    return 1
  fi
}

pbms_odoo_db_initialized() {
  PGPASSWORD="${PBMS_DB_PASSWORD}" psql \
    -h "${POSTGRES_HOST}" \
    -p "${POSTGRES_PORT}" \
    -U "${PBMS_DB_USER}" \
    -d "${PBMS_DB_NAME}" \
    -tc "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'ir_module_module'" \
    | grep -q 1
}

pbms_odoo_ensure_venv() {
  local python_bin="${OPENG2P_PYTHON:-python3}"
  if [[ ! -d "${ODOO_PATH}/venv" ]]; then
    echo "Creating Odoo virtualenv at ${ODOO_PATH}/venv"
    "${python_bin}" -m venv "${ODOO_PATH}/venv"
  fi
}

pbms_odoo_reconcile_python_deps() {
  # PBMS community-addons pin boto3<=1.15.18, which pulls urllib3<1.26 and breaks
  # Odoo 17 on Python 3.11+ (expects urllib3 1.26.5 or 2.0.7). Re-apply Odoo pins,
  # then install a modern boto3 for local dev (S3 storage addons).
  echo "Reconciling Odoo core pins with PBMS addon dependencies ..."
  pip install -r "${ODOO_PATH}/requirements.txt"
  pip install 'boto3>=1.34'
  pip install -r "${ODOO_PATH}/requirements.txt"
}

pbms_odoo_install_python_deps() {
  pbms_odoo_ensure_venv
  # shellcheck disable=SC1091
  source "${ODOO_PATH}/venv/bin/activate"

  echo "Installing Odoo core Python dependencies ..."
  pip install --upgrade pip wheel
  pip install -r "${ODOO_PATH}/requirements.txt"

  # Match PBMS Docker image behaviour: pip install every requirements.txt under
  # each custom addons directory on addons_path (see pbms-odoo.conf.tpl).
  local -a addon_roots=(
    "${PBMS_PATH}/odoo/community-addons"
    "${PBMS_PATH}/odoo"
    "${PBMS_PATH}/odoo/extensions"
    "${OPENG2P_WORKSPACE}/openg2p-odoo-commons"
  )

  local root req
  for root in "${addon_roots[@]}"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r req; do
      echo "Installing addon Python dependencies from ${req} ..."
      pip install -r "$req"
    done < <(find "$root" -name requirements.txt -type f | sort -u)
  done

  pbms_odoo_reconcile_python_deps
}

pbms_odoo_run() {
  local python_bin
  python_bin="$(pbms_odoo_python_bin)"
  exec "${python_bin}" "${ODOO_PATH}/odoo-bin" -c "$PBMS_ODOO_CONF" "$@"
}

pbms_odoo_set_staff_portal_api_url() {
  local url="$1"

  if ! pbms_odoo_db_initialized; then
    return 1
  fi

  PGPASSWORD="${PBMS_DB_PASSWORD}" psql \
    -h "${POSTGRES_HOST}" \
    -p "${POSTGRES_PORT}" \
    -U "${PBMS_DB_USER}" \
    -d "${PBMS_DB_NAME}" \
    -v ON_ERROR_STOP=1 \
    -c "DELETE FROM ir_config_parameter WHERE key = 'g2p_pbms.staff_portal_api_url';" \
    -c "INSERT INTO ir_config_parameter (key, value, create_uid, write_uid, create_date, write_date)
        VALUES ('g2p_pbms.staff_portal_api_url', '${url}', 1, 1, NOW() AT TIME ZONE 'UTC', NOW() AT TIME ZONE 'UTC');"
}

pbms_odoo_set_g2p_bridge_api_url() {
  local url="$1"

  if ! pbms_odoo_db_initialized; then
    return 1
  fi

  PGPASSWORD="${PBMS_DB_PASSWORD}" psql \
    -h "${POSTGRES_HOST}" \
    -p "${POSTGRES_PORT}" \
    -U "${PBMS_DB_USER}" \
    -d "${PBMS_DB_NAME}" \
    -v ON_ERROR_STOP=1 \
    -c "DELETE FROM ir_config_parameter WHERE key = 'g2p_pbms.g2p_bridge_api_url';" \
    -c "INSERT INTO ir_config_parameter (key, value, create_uid, write_uid, create_date, write_date)
        VALUES ('g2p_pbms.g2p_bridge_api_url', '${url}', 1, 1, NOW() AT TIME ZONE 'UTC', NOW() AT TIME ZONE 'UTC');"
}
