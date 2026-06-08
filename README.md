# OpenG2P Developer Setup

One repo to bootstrap local development for OpenG2P subsystems:

- **PBMS** (Odoo)
- **Farmer Registry** (Registry Gen2 implementation)
- **National Social Registry** (Registry Gen2 implementation)
- **G2P Bridge** (FastAPI + Celery + example bank)
- **SPAR** (mapper + beneficiary portal APIs)

Shared infrastructure runs in Docker. Application services run **natively by default** (better for Odoo/Python/Node iteration). Container profiles are available for onboarding and smoke testing.

## Prerequisites

- Docker Desktop (or Docker Engine + Compose v2)
- Git
- Python 3.10+ (3.11+ recommended for SPAR)
- Node.js 18+ (Registry staff portal UI)
- Make

Optional but recommended on macOS:

```bash
brew install libpq openssl
```

## Quick start

```bash
git clone https://github.com/shibu-narayanan/openg2p-developer.git
cd openg2p-developer

cp .env.example .env
make setup          # clone repos + generate configs
make infra-up       # postgres, redis, minio, keycloak
make install-odoo   # first-time Odoo dependency install

make farmer-registry-run   # Farmer Registry on http://localhost:8001
# or
make nsr-registry-run      # National Social Registry on http://localhost:8011
make pbms-run              # PBMS on http://localhost:8069
```

Run `make help` for all targets.

## Architecture

```text
openg2p-developer/              <- this repo (orchestration)
../openg2p-workspace/           <- cloned product repos (default)
generated/                      <- generated odoo conf + .env files (gitignored)
compose/                        <- docker compose profiles
scripts/                        <- clone, generate, run helpers
templates/                      <- config templates
profiles/                       <- curated developer stacks
```

### Registry Gen2 model

Both **Farmer Registry** and **National Social Registry** are domain implementations on top of the shared Registry Gen2 platform:

```text
registry-platform/              <- shared APIs, Celery, staff portal UI
farmer-registry/farmer-extension/
national-social-registry/nsr-extension/
```

Native development installs the relevant extension into the platform API/Celery venvs:

```bash
make install-registry-extension VARIANT=farmer-registry
make install-registry-extension VARIANT=national-social-registry
```

### Shared infrastructure (Docker)

| Service   | URL / Port                         | Default credentials   |
|-----------|------------------------------------|-----------------------|
| Postgres  | `localhost:5432`                   | `postgres` / `postgres` |
| Redis     | `localhost:6379`                   | none                  |
| MinIO     | API `:9000`, console `:9001`     | `admin` / `secret`    |
| Keycloak  | `http://localhost:8080`            | `admin` / `admin`     |

### Application ports (native mode defaults)

| Service                              | Port |
|--------------------------------------|------|
| PBMS Odoo                            | 8069 |
| Farmer Registry staff API            | 8001 |
| Farmer Registry staff UI             | 3000 |
| National Social Registry staff API   | 8011 |
| National Social Registry staff UI    | 3010 |
| G2P Bridge partner API               | 8002 |
| G2P Bridge example bank              | 8003 |
| SPAR mapper API                      | 8004 |
| SPAR bene portal API                 | 8005 |

Override ports in `.env`, then run `make generate`.

## Commands

```bash
make help

# Bootstrap
make setup
make clone
make generate
make install-odoo
make install-registry-extension VARIANT=farmer-registry
make install-registry-extension VARIANT=national-social-registry

# Infrastructure
make infra-up
make infra-down
make status
make logs
make clean          # removes docker volumes

# Native development (recommended)
make pbms-run
make farmer-registry-run
make nsr-registry-run
make bridge-run
make spar-run

# Container profiles (optional)
make up-pbms
make up-farmer-registry
make up-nsr-registry
make up-bridge
make up-spar
make up-full
```

## Profiles

See `profiles/` for curated stacks:

- `minimal.md` — infrastructure only
- `pbms-dev.md` — PBMS development
- `farmer-registry-dev.md` — Farmer Registry Gen2
- `national-social-registry-dev.md` — National Social Registry Gen2
- `pbms-bridge-dev.md` — PBMS + G2P Bridge integration
- `spar-dev.md` — SPAR development
- `full-stack.md` — full integration smoke test

## First-time service setup

### PBMS (Odoo)

```bash
make setup
make install-odoo
make infra-up
make pbms-run
```

Default Odoo master password: `admin`

### Farmer Registry or National Social Registry

```bash
make clone
make install-registry-extension VARIANT=farmer-registry
# or VARIANT=national-social-registry

# Migrate once
cd ../openg2p-workspace/registry-platform/apis/openg2p-registry-staff-portal-api
source venv/bin/activate
set -a && source ../../../openg2p-developer/generated/farmer-registry/staff-portal-api.env && set +a
python main.py migrate

cd ../../ui/staff-portal-ui && npm install
cd ../../../openg2p-developer
make farmer-registry-run
```

Use `generated/national-social-registry/` and `make nsr-registry-run` for NSR.

### G2P Bridge

```bash
bash scripts/install-python-project.sh ../openg2p-workspace/g2p-bridge/core/partner-api
bash scripts/install-python-project.sh ../openg2p-workspace/g2p-bridge/core/celery-workers
bash scripts/install-python-project.sh ../openg2p-workspace/g2p-bridge/example-bank/openg2p-example-bank-api
make bridge-run
```

Migrate each API before first run (`python main.py migrate`).

### SPAR

See `profiles/spar-dev.md`.

## Keycloak (local)

Keycloak starts in dev mode at `http://localhost:8080`.

Suggested local clients:

- `farmer-registry-staff-portal`
- `nsr-registry-staff-portal`
- `g2p-bridge`
- `spar-mapper`
- `spar-bene-portal`
- `openg2p-pbms-local`

See `keycloak/README.md`.

## Version pinning

Repo and image pins live in `versions.yaml`. Override branch/tag refs in `.env`:

```bash
PBMS_REF=develop
REGISTRY_REF=develop
FARMER_REGISTRY_REF=develop
NSR_REF=develop
G2P_BRIDGE_REF=develop
SPAR_REF=develop
ODOO_REF=17.0
```

## Hybrid cluster development

If you have a shared dev Kubernetes environment, port-forward Postgres/MinIO/Keycloak instead of running local infra:

```bash
kubectl port-forward svc/commons-postgresql 5432:5432 -n dev
kubectl port-forward svc/minio 9000:9000 -n dev
kubectl port-forward svc/keycloak 8080:8080 -n dev
```

Update `.env` host/port values, then `make generate`.

## Troubleshooting

**Postgres port already in use**

Change `POSTGRES_PORT` in `.env` (e.g. `5433`) and run `make generate`.

**Odoo addons not found**

Ensure `make clone` completed and `OPENG2P_WORKSPACE` in `.env` points to the directory containing `odoo17`, `openg2p-pbms-odoo`, etc.

**Registry extension not loaded**

Run `make install-registry-extension VARIANT=farmer-registry` (or `national-social-registry`) before starting the stack.

**Reset databases**

```bash
make clean
make infra-up
```

## Contributing

PRs welcome. When adding a subsystem:

1. Add repo entry to `versions.yaml`
2. Add Postgres init SQL if a new DB is required
3. Add env templates under `templates/`
4. Add `scripts/run-*.sh` and Makefile targets
5. Document a profile under `profiles/`

## License

Apache-2.0 (same spirit as OpenG2P ecosystem; adjust if needed)
