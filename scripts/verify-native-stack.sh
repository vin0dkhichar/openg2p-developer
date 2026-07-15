#!/usr/bin/env bash
# Verify selected native services. Pass components: pbms registry bridge spar
# Example: bash scripts/verify-native-stack.sh spar
# No args: verify pbms (+ registry if PBMS_WITH_REGISTRY=true)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

PBMS_WITH_REGISTRY="${PBMS_WITH_REGISTRY:-true}"
PBMS_REGISTRY_VARIANT="${PBMS_REGISTRY_VARIANT:-farmer-registry}"
SPAR_MAPPER_API_PORT="${SPAR_MAPPER_API_PORT:-8004}"

REQUESTED=("$@")
if [[ ${#REQUESTED[@]} -eq 0 ]]; then
  REQUESTED=(pbms)
  [[ "${PBMS_WITH_REGISTRY}" == "true" ]] && REQUESTED+=(registry)
fi

want() {
  local name="$1"
  local item
  for item in "${REQUESTED[@]}"; do
    [[ "$item" == "$name" ]] && return 0
  done
  return 1
}

fail=0

check_beat() {
  local label="$1"
  local pattern="$2"
  local count=0
  local attempt

  for attempt in 1 2 3 4 5; do
    count="$(pgrep -cf "$pattern" 2>/dev/null)" || count=0
    if [[ "$count" -ge 1 ]]; then
      break
    fi
    [[ "$attempt" -lt 5 ]] && sleep 2
  done

  if [[ "$count" -gt 1 ]]; then
    echo "FAIL: ${label} — ${count} beat processes (expected 1)" >&2
    fail=1
  elif [[ "$count" -eq 0 ]]; then
    echo "FAIL: ${label} — not running" >&2
    fail=1
  else
    echo "OK:   ${label} — 1 beat"
  fi
}

check_worker() {
  local label="$1"
  local pattern="$2"
  local count=0
  count="$(pgrep -cf "$pattern" 2>/dev/null)" || count=0
  if [[ "$count" -eq 0 ]]; then
    echo "FAIL: ${label} — not running" >&2
    fail=1
  else
    echo "OK:   ${label} — ${count} process(es) (includes Celery pool workers)"
  fi
}

check_spar_mapper() {
  local label="SPAR mapper API"
  local port="${SPAR_MAPPER_API_PORT}"
  local attempt
  local ready=0

  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf "http://localhost:${port}/docs" >/dev/null 2>&1; then
      ready=1
      break
    fi
    [[ "$attempt" -lt 10 ]] && sleep 2
  done

  if [[ "$ready" -eq 1 ]]; then
    echo "OK:   ${label} — responding on port ${port}"
    return 0
  fi

  echo "FAIL: ${label} — not responding on port ${port}" >&2
  fail=1
}

echo "==> Verifying: ${REQUESTED[*]} ..."

if want pbms; then
  check_beat "PBMS Celery beat" "openg2p_bg_task_celery_beat_producers.main.celery_app beat"
  check_worker "PBMS Celery beat worker" "openg2p_bg_task_celery_beat_producers.main.celery_app worker -Q celery"
  check_worker "PBMS Celery worker" "pbms_celery_worker_app.celery_app worker"
fi

if want registry; then
  case "${PBMS_REGISTRY_VARIANT}" in
    farmer-registry)
      check_beat "Registry Celery beat" "openg2p-registry-celery-beat-producers.*celery_app beat"
      check_worker "Registry Celery beat worker" "openg2p-registry-celery-beat-producers.*worker -Q celery"
      check_worker "Registry Celery worker" "openg2p-registry-celery-workers.*farmer_registry_worker_queue"
      ;;
  esac
fi

if want bridge; then
  check_beat "Bridge Celery beat" "g2p-bridge/core/celery-beat-producers.*celery_app beat"
  check_worker "Bridge Celery beat worker" "g2p-bridge/core/celery-beat-producers.*worker -Q celery"
  check_worker "Bridge Celery worker" "g2p-bridge/core/celery-workers.*g2p_bridge_queue"
fi

if want spar; then
  check_spar_mapper
fi

if [[ "$fail" -ne 0 ]]; then
  echo "Verification failed for: ${REQUESTED[*]}" >&2
  exit 1
fi

echo "Verification passed for: ${REQUESTED[*]}."
