#!/usr/bin/env bash
# Ensure IAM staff_portal_applications (and roles) exist for variant Keycloak clients
# such as nsr-registry-staff-portal and farmer-registry-staff-portal.
#
# The IAM package seeds registry-staff-portal (Helm/production naming). Local dev uses
# per-variant client IDs that must match APPLICATION_MNEMONIC in the staff portal UI.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_SUPERUSER="${POSTGRES_SUPERUSER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
FARMER_REGISTRY_STAFF_API_PORT="${FARMER_REGISTRY_STAFF_API_PORT:-8001}"
NSR_REGISTRY_STAFF_API_PORT="${NSR_REGISTRY_STAFF_API_PORT:-8011}"

export PGPASSWORD="${POSTGRES_PASSWORD}"

if ! psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_SUPERUSER}" -d iam_staff -tc \
  "SELECT 1 FROM information_schema.tables WHERE table_name = 'staff_portal_applications'" | grep -q 1; then
  echo "[iam-variants] iam_staff.staff_portal_applications not found; run make iam-init first" >&2
  exit 1
fi

echo "[iam-variants] Ensuring IAM applications for registry variant Keycloak clients ..."

psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_SUPERUSER}" -d iam_staff -v ON_ERROR_STOP=1 <<SQL
SELECT setval(
  pg_get_serial_sequence('staff_portal_applications', 'id'),
  COALESCE((SELECT MAX(id) FROM staff_portal_applications), 1)
);
SELECT setval(
  pg_get_serial_sequence('staff_roles', 'id'),
  COALESCE((SELECT MAX(id) FROM staff_roles), 1)
);
SELECT setval(
  pg_get_serial_sequence('staff_role_permissions', 'id'),
  COALESCE((SELECT MAX(id) FROM staff_role_permissions), 1)
);

WITH base_app AS (
  SELECT *
  FROM staff_portal_applications
  WHERE application_mnemonic = 'registry-staff-portal'
    AND active = true
  LIMIT 1
),
variants(mnemonic, application_url) AS (
  VALUES
    ('nsr-registry-staff-portal', 'http://localhost:${NSR_REGISTRY_STAFF_API_PORT}'),
    ('farmer-registry-staff-portal', 'http://localhost:${FARMER_REGISTRY_STAFF_API_PORT}')
)
INSERT INTO staff_portal_applications (
  application_mnemonic,
  application_description,
  icon_base64,
  width,
  application_url,
  "order",
  created_at,
  updated_at,
  active
)
SELECT
  v.mnemonic,
  b.application_description,
  b.icon_base64,
  b.width,
  v.application_url,
  b."order",
  NOW(),
  NOW(),
  true
FROM variants v
CROSS JOIN base_app b
WHERE NOT EXISTS (
  SELECT 1
  FROM staff_portal_applications existing
  WHERE existing.application_mnemonic = v.mnemonic
);

WITH base_app AS (
  SELECT id
  FROM staff_portal_applications
  WHERE application_mnemonic = 'registry-staff-portal'
    AND active = true
  LIMIT 1
)
INSERT INTO staff_roles (
  role_mnemonic,
  role_description,
  application_id,
  created_at,
  updated_at,
  active
)
SELECT
  base_role.role_mnemonic,
  base_role.role_description,
  variant_app.id,
  NOW(),
  NOW(),
  base_role.active
FROM staff_roles base_role
CROSS JOIN base_app
JOIN staff_portal_applications variant_app
  ON variant_app.application_mnemonic IN (
    'nsr-registry-staff-portal',
    'farmer-registry-staff-portal'
  )
WHERE base_role.application_id = base_app.id
  AND base_role.active = true
  AND NOT EXISTS (
    SELECT 1
    FROM staff_roles existing
    WHERE existing.application_id = variant_app.id
      AND existing.role_mnemonic = base_role.role_mnemonic
  );

WITH base_app AS (
  SELECT id
  FROM staff_portal_applications
  WHERE application_mnemonic = 'registry-staff-portal'
    AND active = true
  LIMIT 1
)
INSERT INTO staff_role_permissions (role_id, permission_id, created_at, updated_at, active)
SELECT
  variant_role.id,
  base_perm.permission_id,
  NOW(),
  NOW(),
  base_perm.active
FROM staff_portal_applications variant_app
JOIN staff_roles variant_role
  ON variant_role.application_id = variant_app.id
  AND variant_role.active = true
JOIN base_app
  ON true
JOIN staff_roles base_role
  ON base_role.application_id = base_app.id
  AND base_role.role_mnemonic = variant_role.role_mnemonic
  AND base_role.active = true
JOIN staff_role_permissions base_perm
  ON base_perm.role_id = base_role.id
  AND base_perm.active = true
WHERE variant_app.application_mnemonic IN (
  'nsr-registry-staff-portal',
  'farmer-registry-staff-portal'
)
AND NOT EXISTS (
  SELECT 1
  FROM staff_role_permissions existing
  WHERE existing.role_id = variant_role.id
    AND existing.permission_id = base_perm.permission_id
);
SQL

echo "[iam-variants] IAM registry variant applications ready."
