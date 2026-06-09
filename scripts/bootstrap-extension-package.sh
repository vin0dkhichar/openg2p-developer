#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/extension-manifest.sh"

NAME="${1:-${NAME:-}}"
REPO_URL="${2:-${REPO_URL:-}}"
RUN_SETUP="${SETUP:-${RUN_SETUP:-0}}"
TEMPLATE_DIR="${ROOT_DIR}/templates/extension-package"

usage() {
  cat <<EOF
Bootstrap an empty Registry Gen2 extension product repo.

Usage:
  make extension-package NAME=disability-registry [REPO_URL=https://github.com/you/disability-registry.git] [SETUP=1]

Or interactively:
  make extension-package

Options:
  NAME       Kebab-case slug (e.g. disability-registry)
  REPO_URL   Optional git URL — clone into workspace instead of creating locally
  SETUP=1    Run full extension-setup after scaffolding (requires make setup + infra)
EOF
}

if [[ -z "$NAME" ]]; then
  if [[ -t 0 ]]; then
    echo "Bootstrap a new Registry Gen2 extension product repo."
    echo
    read -rp "Extension slug (e.g. disability-registry): " NAME
    read -rp "Git repo URL (optional, leave empty to create locally): " REPO_URL
    read -rp "Run full setup now? [y/N]: " setup_answer
    if [[ "$setup_answer" =~ ^[Yy]$ ]]; then
      RUN_SETUP=1
    fi
  else
    usage >&2
    exit 1
  fi
fi

extension_manifest_slug_validate "$NAME"
extension_manifest_derive_names "$NAME"

workspace="$(extension_manifest_workspace)"
extension_manifest_next_ports "$workspace"

PRODUCT_PATH="${workspace}/${DERIVED_PRODUCT_REPO}"
EXTENSION_PATH="${PRODUCT_PATH}/${DERIVED_EXTENSION_DIR}"
SRC_PATH="${EXTENSION_PATH}/src/${DERIVED_PYTHON_MODULE}"
CONFIGURATION_ID="$(uuidgen 2>/dev/null | tr '[:upper:]' '[:lower:]' || python3 -c 'import uuid; print(uuid.uuid4())')"

if [[ -f "${PRODUCT_PATH}/.openg2p-extension.yaml" || -d "$EXTENSION_PATH" ]]; then
  echo "Extension product already exists at ${PRODUCT_PATH}" >&2
  exit 1
fi

if [[ -n "$REPO_URL" ]]; then
  if [[ -d "$PRODUCT_PATH" ]]; then
    echo "Path already exists: ${PRODUCT_PATH}" >&2
    exit 1
  fi
  echo "==> Cloning ${REPO_URL} -> ${PRODUCT_PATH}"
  git clone "$REPO_URL" "$PRODUCT_PATH"
  if [[ ! -d "$PRODUCT_PATH/.git" ]]; then
    echo "Clone did not produce a git repo at ${PRODUCT_PATH}" >&2
    exit 1
  fi
else
  mkdir -p "$PRODUCT_PATH"
  if command -v git >/dev/null 2>&1; then
    git -C "$PRODUCT_PATH" init -q
  fi
fi

render_placeholders() {
  local template="$1"
  local output="$2"
  extension_manifest_render_template "$template" "$output" \
    "{{VARIANT}}" "$DERIVED_VARIANT" \
    "{{LABEL}}" "$DERIVED_LABEL" \
    "{{PRODUCT_REPO}}" "$DERIVED_PRODUCT_REPO" \
    "{{EXTENSION_DIR_NAME}}" "$DERIVED_EXTENSION_DIR" \
    "{{PYTHON_MODULE}}" "$DERIVED_PYTHON_MODULE" \
    "{{PIP_NAME}}" "$DERIVED_PIP_NAME" \
    "{{VARIANT_TOKEN}}" "$DERIVED_VARIANT_TOKEN" \
    "{{REGISTRY_DB}}" "$DERIVED_REGISTRY_DB" \
    "{{MASTER_DATA_DB}}" "$DERIVED_MASTER_DATA_DB" \
    "{{STAFF_API_PORT}}" "$DERIVED_STAFF_API_PORT" \
    "{{UI_PORT}}" "$DERIVED_UI_PORT" \
    "{{WORKER_QUEUE}}" "$DERIVED_WORKER_QUEUE" \
    "{{KEYCLOAK_CLIENT_ID}}" "$DERIVED_KEYCLOAK_CLIENT_ID" \
    "{{UI_APP_MNEMONIC}}" "$DERIVED_UI_APP_MNEMONIC" \
    "{{HELM_CHART_NAME}}" "$DERIVED_HELM_CHART_NAME" \
    "{{CONFIGURATION_ID}}" "$CONFIGURATION_ID"
}

scaffold_docker_and_helm() {
  local static="${TEMPLATE_DIR}/docker/static"
  local tpl="${TEMPLATE_DIR}/docker/tpl"
  local docker="${PRODUCT_PATH}/docker"
  local helm_dir="${PRODUCT_PATH}/helm/${DERIVED_HELM_CHART_NAME}"

  echo "==> Scaffolding docker/ and helm/${DERIVED_HELM_CHART_NAME}/"
  mkdir -p "$docker"
  cp -R "${static}/." "$docker/"

  render_placeholders "${tpl}/staff-portal-api/develop.txt.tpl" "${docker}/staff-portal-api/develop.txt"
  render_placeholders "${tpl}/celery/develop.txt.tpl" "${docker}/celery/develop.txt"
  render_placeholders "${tpl}/partner-api/develop.txt.tpl" "${docker}/partner-api/develop.txt"
  render_placeholders "${tpl}/staff-portal-ui/develop.txt.tpl" "${docker}/staff-portal-ui/develop.txt"
  render_placeholders "${tpl}/db-seed/Dockerfile.tpl" "${docker}/db-seed/Dockerfile"
  render_placeholders "${tpl}/scripts/build.sh.tpl" "${docker}/scripts/build.sh"
  render_placeholders "${tpl}/scripts/README.md.tpl" "${docker}/scripts/README.md"

  mkdir -p "$helm_dir"
  render_placeholders "${TEMPLATE_DIR}/helm/tpl/Chart.yaml.tpl" "${helm_dir}/Chart.yaml"
  render_placeholders "${TEMPLATE_DIR}/helm/tpl/values.yaml.tpl" "${helm_dir}/values.yaml"
  render_placeholders "${TEMPLATE_DIR}/helm/tpl/questions.yaml.tpl" "${helm_dir}/questions.yaml"
  render_placeholders "${TEMPLATE_DIR}/helm/tpl/README.md.tpl" "${helm_dir}/README.md"

  chmod +x "${docker}/scripts/build.sh" "${docker}/db-seed/entrypoint.sh"
}

echo "==> Scaffolding ${DERIVED_LABEL} at ${PRODUCT_PATH}"

render_placeholders "${TEMPLATE_DIR}/.openg2p-extension.yaml.tpl" "${PRODUCT_PATH}/.openg2p-extension.yaml"
render_placeholders "${TEMPLATE_DIR}/product-README.md.tpl" "${PRODUCT_PATH}/README.md"
render_placeholders "${TEMPLATE_DIR}/pyproject.toml.tpl" "${EXTENSION_PATH}/pyproject.toml"
render_placeholders "${TEMPLATE_DIR}/extension-README.md.tpl" "${EXTENSION_PATH}/README.md"
render_placeholders "${TEMPLATE_DIR}/src/__init__.py.tpl" "${SRC_PATH}/__init__.py"
render_placeholders "${TEMPLATE_DIR}/src/app.py.tpl" "${SRC_PATH}/app.py"
render_placeholders "${TEMPLATE_DIR}/src/config.py.tpl" "${SRC_PATH}/config.py"
mkdir -p "${SRC_PATH}/register_domain/factory" \
  "${SRC_PATH}/register_domain/models" \
  "${SRC_PATH}/register_domain/schemas" \
  "${SRC_PATH}/register_domain/services" \
  "${SRC_PATH}/meta_data/registry-configurations"
cp "${TEMPLATE_DIR}/src/register_domain/factory/g2p_register_domain_factory.py" \
  "${SRC_PATH}/register_domain/factory/g2p_register_domain_factory.py"
touch "${SRC_PATH}/register_domain/__init__.py" \
  "${SRC_PATH}/register_domain/factory/__init__.py" \
  "${SRC_PATH}/register_domain/models/__init__.py" \
  "${SRC_PATH}/register_domain/schemas/__init__.py" \
  "${SRC_PATH}/register_domain/services/__init__.py"
render_placeholders "${TEMPLATE_DIR}/meta_data/registry-configurations/g2p_registry_configuration.sql.tpl" \
  "${SRC_PATH}/meta_data/registry-configurations/g2p_registry_configuration.sql"
render_placeholders "${TEMPLATE_DIR}/meta_data/README.md.tpl" "${SRC_PATH}/meta_data/README.md"

scaffold_docker_and_helm

echo "==> Generating Developer Setup configs"
bash "${ROOT_DIR}/scripts/generate-config.sh" >/dev/null

if bash "${ROOT_DIR}/scripts/postgres-ensure-extension-databases.sh" "$DERIVED_VARIANT" 2>/dev/null; then
  :
else
  echo "[bootstrap] Postgres not ready — run 'make infra-up' before extension-setup."
fi

echo
echo "Extension package bootstrapped: ${DERIVED_LABEL}"
echo "  Product repo : ${PRODUCT_PATH}"
echo "  Extension    : ${EXTENSION_PATH}"
echo "  Manifest     : ${PRODUCT_PATH}/.openg2p-extension.yaml"
echo "  API port     : ${DERIVED_STAFF_API_PORT}"
echo "  UI port      : ${DERIVED_UI_PORT}"
echo "  Docker       : ${PRODUCT_PATH}/docker/"
echo "  Helm chart   : ${PRODUCT_PATH}/helm/${DERIVED_HELM_CHART_NAME}/"
echo
echo "Next:"
echo "  make setup                    # clone registry-platform, IAM, AWE, UI (if not done)"
echo "  make extension-setup NAME=${DERIVED_VARIANT}"
echo "  make extension-run NAME=${DERIVED_VARIANT}"
echo
echo "Container images: ./docker/scripts/build.sh"
echo "Kubernetes:       cd helm/${DERIVED_HELM_CHART_NAME} && helm dependency update"
echo
echo "Copy meta_data/ from farmer-extension or nsr-extension, then re-run extension-setup."

if [[ "$RUN_SETUP" == "1" || "$RUN_SETUP" == "true" ]]; then
  echo
  echo "==> Running extension-setup ..."
  bash "${ROOT_DIR}/scripts/registry-setup.sh" "$DERIVED_VARIANT"
fi
