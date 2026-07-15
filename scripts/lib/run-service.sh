#!/usr/bin/env bash
# Start a native service in the background with a generated env file.

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

  echo "Starting ${name} from ${dir} ..."
  (
    cd "$dir"
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
    if [[ -n "$venv_python" && -f "${dir}/venv/bin/activate" ]]; then
      # shellcheck disable=SC1091
      source venv/bin/activate
    fi
    if [[ "${1:-}" == "python" && -n "$venv_python" ]]; then
      shift
      exec "$venv_python" "$@"
    else
      exec "$@"
    fi
  ) &
  echo "${name} pid=$!"
}
