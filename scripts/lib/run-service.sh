#!/usr/bin/env bash
# Start native background services with at-most-one instance per logical name.
#
# Why this exists: `make pbms-run` and individual start-* scripts used to call
# `( ... ) &` with no tracking. Re-runs stacked Celery beat processes that all
# share one /tmp/celery-beat-*.db schedule file — beats then stop dispatching
# and envelope steps stay PENDING forever.

run_service_state_dir() {
  if [[ -z "${RUN_SERVICE_STATE_DIR:-}" ]]; then
    local root
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    RUN_SERVICE_STATE_DIR="${root}/generated/run"
  fi
  mkdir -p "$RUN_SERVICE_STATE_DIR"
}

# Stop a logical service: pid file from a prior run + optional pgrep patterns.
run_service_stop() {
  local name="$1"
  shift

  run_service_state_dir
  local pidfile="${RUN_SERVICE_STATE_DIR}/${name}.pid"

  if [[ -f "$pidfile" ]]; then
    local pid
    pid="$(tr -d '[:space:]' <"$pidfile")"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "Stopping ${name} (pid ${pid}) ..."
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$pidfile"
  fi

  local pattern pids
  for pattern in "$@"; do
    [[ -n "$pattern" ]] || continue
    pids="$(pgrep -f "$pattern" 2>/dev/null || true)"
    if [[ -z "$pids" ]]; then
      continue
    fi
    echo "Stopping ${name} (pgrep: ${pattern}) ..."
    # shellcheck disable=SC2086
    kill $pids 2>/dev/null || true
    sleep 1
    # shellcheck disable=SC2086
    kill -9 $pids 2>/dev/null || true
  done
}

# Celery beat must be a singleton — multiple beats lock the same schedule db.
run_service_stop_celery_beats() {
  local schedule_token="$1"
  [[ -n "$schedule_token" ]] || return 0

  local pattern pids f
  for pattern in "$schedule_token" "celery -A .* beat.*${schedule_token}"; do
    pids="$(pgrep -f "$pattern" 2>/dev/null || true)"
    if [[ -n "$pids" ]]; then
      echo "Stopping Celery beat(s) matching: ${pattern} ..."
      # shellcheck disable=SC2086
      kill $pids 2>/dev/null || true
      sleep 1
      # shellcheck disable=SC2086
      kill -9 $pids 2>/dev/null || true
    fi
  done

  shopt -s nullglob
  for f in /tmp/celery-beat-*"${schedule_token}"*.db; do
    echo "Removing stale beat schedule ${f} ..."
    rm -f "$f"
  done
  shopt -u nullglob
}

run_service_assert_single() {
  local name="$1"
  local pattern="$2"
  local max="${3:-1}"

  local count=0
  count="$(pgrep -cf "$pattern" 2>/dev/null)" || count=0
  if [[ "$count" -gt "$max" ]]; then
    echo "ERROR: ${count} processes match '${pattern}' (expected at most ${max})." >&2
    echo "  Run: bash scripts/free-native-stack.sh" >&2
    return 1
  fi
  return 0
}

run_service() {
  local name="$1"
  local dir="$2"
  local env_file="$3"
  shift 3

  if [[ ! -d "$dir" ]]; then
    echo "Skipping ${name}: directory not found (${dir})" >&2
    return 0
  fi

  local venv_python=""
  if [[ -x "${dir}/venv/bin/python" ]]; then
    venv_python="${dir}/venv/bin/python"
  elif [[ "$*" == *python* ]] || [[ "$*" == *celery* ]] || [[ "$*" == *uvicorn* ]]; then
    echo "Skipping ${name}: Python venv missing in ${dir}." >&2
    return 0
  fi

  run_service_state_dir
  run_service_stop "$name"

  local log_file="${RUN_SERVICE_STATE_DIR}/${name}.log"
  local launcher="${RUN_SERVICE_STATE_DIR}/${name}.sh"
  local -a cmd=("$@")

  echo "Starting ${name} from ${dir} ..."
  {
    printf '#!/usr/bin/env bash\nset -euo pipefail\ncd %q\nset -a\nsource %q\nset +a\n' "$dir" "$env_file"
    if [[ -n "$venv_python" && -f "${dir}/venv/bin/activate" ]]; then
      printf 'source %q\n' "${dir}/venv/bin/activate"
    fi
    if [[ "${cmd[0]:-}" == "python" && -n "$venv_python" ]]; then
      printf 'exec %q' "$venv_python"
      local arg
      for arg in "${cmd[@]:1}"; do
        printf ' %q' "$arg"
      done
      printf '\n'
    else
      printf 'exec'
      local arg
      for arg in "${cmd[@]}"; do
        printf ' %q' "$arg"
      done
      printf '\n'
    fi
  } >"$launcher"
  chmod +x "$launcher"

  # setsid: new session so SIGHUP from make/script exit cannot kill the service.
  if command -v setsid >/dev/null 2>&1; then
    setsid "$launcher" >>"$log_file" 2>&1 &
  else
    nohup "$launcher" >>"$log_file" 2>&1 &
  fi
  RUN_SERVICE_LAST_PID=$!
  disown -h "$RUN_SERVICE_LAST_PID" 2>/dev/null || true
  echo "${RUN_SERVICE_LAST_PID}" >"${RUN_SERVICE_STATE_DIR}/${name}.pid"
  echo "${name} pid=${RUN_SERVICE_LAST_PID} log=${log_file}"
}

# Track the process actually listening on the service port (not a wrapper parent).
run_service_record_port() {
  local name="$1"
  local port="$2"
  local attempt pid

  run_service_state_dir
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if command -v lsof >/dev/null 2>&1; then
      pid="$(lsof -tiTCP:"${port}" -sTCP:LISTEN 2>/dev/null | head -1 || true)"
    else
      pid=""
    fi
    if [[ -n "$pid" ]]; then
      echo "${pid}" >"${RUN_SERVICE_STATE_DIR}/${name}.pid"
      echo "${name} listening pid=${pid} port=${port}"
      return 0
    fi
    sleep 1
  done

  echo "WARN: ${name} not listening on port ${port} yet." >&2
  return 1
}

# Fail fast when a background service exits immediately (common with import errors).
run_service_verify() {
  local name="$1"
  local pid="${2:-${RUN_SERVICE_LAST_PID:-}}"
  local wait_sec="${3:-2}"

  if [[ -z "$pid" ]]; then
    echo "Cannot verify ${name}: no pid." >&2
    return 1
  fi

  sleep "$wait_sec"
  if kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  run_service_state_dir
  rm -f "${RUN_SERVICE_STATE_DIR}/${name}.pid"

  echo "ERROR: ${name} (pid ${pid}) exited right after start." >&2
  echo "  Re-run the command in the foreground to see the traceback." >&2
  return 1
}
