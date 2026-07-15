#!/usr/bin/env bash
# Stop all native OpenG2P dev processes before a clean `make pbms-run`.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

PBMS_REGISTRY_VARIANT="${PBMS_REGISTRY_VARIANT:-farmer-registry}"
PBMS_WITH_REGISTRY="${PBMS_WITH_REGISTRY:-true}"
PBMS_WITH_BRIDGE="${PBMS_WITH_BRIDGE:-true}"
PBMS_WITH_SPAR="${PBMS_WITH_SPAR:-true}"

echo "==> Stopping native stack processes ..."

bash "${ROOT_DIR}/scripts/free-pbms-ports.sh"

if [[ "${PBMS_WITH_SPAR}" == "true" || "${PBMS_WITH_BRIDGE}" == "true" ]]; then
  bash "${ROOT_DIR}/scripts/free-bridge-spar-ports.sh"
fi

if [[ "${PBMS_WITH_REGISTRY}" == "true" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/scripts/lib/registry-variant.sh"
  if registry_variant_validate "${PBMS_REGISTRY_VARIANT}" 2>/dev/null; then
    bash "${ROOT_DIR}/scripts/free-variant-ports.sh" "${PBMS_REGISTRY_VARIANT}"
  fi
fi

# Orphaned background jobs from prior `make pbms-run` (parent shell exited, PPID=systemd).
for pattern in \
  "openg2p_pbms_staff_portal_api.main" \
  "pbms_celery_worker_app.celery_app" \
  "beat_producers.main.celery_app beat" \
  "beat_producers.main.celery_app worker -Q celery" \
  "openg2p-registry-celery-beat-producers" \
  "openg2p-registry-celery-workers" \
  "g2p-bridge/core/celery-beat-producers.*worker -Q celery" \
  "g2p-bridge/core/celery-beat-producers.*celery_app beat" \
  "g2p-bridge/core/celery-workers.*g2p_bridge_queue" \
  "g2p-bridge/core/partner-api" \
  "openg2p-example-bank-api" \
  "spar/core/mapper-partner-api" \
  "spar/core/bene-portal-api" \
  "odoo-bin.*pbms-odoo.conf"; do
  pids="$(pgrep -f "$pattern" 2>/dev/null || true)"
  if [[ -n "$pids" ]]; then
    echo "Stopping orphaned: ${pattern} ..."
    # shellcheck disable=SC2086
    kill $pids 2>/dev/null || true
    sleep 1
    # shellcheck disable=SC2086
    kill -9 $pids 2>/dev/null || true
  fi
done

rm -rf "${ROOT_DIR}/generated/run/"*.pid 2>/dev/null || true

echo "Native stack stopped."
echo "  Docker infra (Postgres, Redis, Keycloak) is still running."
echo "  Celery beat logs should stop within a few seconds."
