# OpenG2P Developer Setup

One repo to bootstrap local development for OpenG2P subsystems:

- **PBMS** (Odoo)
- **Social Registry** (Odoo)
- **Registry Gen2** (FastAPI + Celery + UI)
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
# Edit OPENG2P_WORKSPACE if you want repos cloned elsewhere

make setup          # clone product repos + generate configs
make infra-up       # postgres, redis, minio, keycloak
make install-odoo   # first-time Odoo dependency install

make pbms-run       # PBMS Odoo on http://localhost:8069
```

## Architecture

```text
openg2p-developer/          <- this repo (orchestration)
../openg2p-workspace/       <- cloned product repos (default)
generated/                  <- generated odoo conf + .env files (gitignored)
compose/                    <- docker compose profiles
scripts/                    <- clone, generate, run helpers
templates/                  <- config templates
```

### Shared infrastructure (Docker)

| Service   | URL / Port                         | Default credentials   |
|-----------|------------------------------------|-----------------------|
| Postgres  | `localhost:5432`                   | `postgres` / `postgres` |
| Redis     | `localhost:6379`                   | none                  |
| MinIO     | API `:9000`, console `:9001`     | `admin` / `secret`    |
| Keycloak  | `http://localhost:8080`            | `admin` / `admin`     |

Postgres is initialized with separate databases for PBMS, Social Registry, Registry Gen2, G2P Bridge, and SPAR.

### Application ports (native mode defaults)

| Service                 | Port |
|-------------------------|------|
| PBMS Odoo               | 8069 |
| Social Registry Odoo    | 8070 |
| Registry staff API      | 8001 |
| Registry staff UI       | 3000 |
| G2P Bridge partner API  | 8002 |
| G2P Bridge example bank | 8003 |
| SPAR mapper API         | 8004 |
| SPAR bene portal API    | 8005 |

Override ports in `.env`, then run `make generate`.

## Commands

```bash
make help

# Bootstrap
make setup
make clone
make generate
make install-odoo

# Infrastructure
make infra-up
make infra-down
make status
make logs
make clean          # removes docker volumes

# Native development (recommended)
make pbms-run
make sr-run
make registry-run
make bridge-run
make spar-run

# Container profiles (optional)
make up-pbms
make up-social-registry
make up-registry
make up-bridge
make up-spar
make up-full
```

## Profiles

See `profiles/` for curated stacks:

- `minimal.md` — infrastructure only
- `pbms-dev.md` — PBMS development
- `registry-dev.md` — Registry Gen2 development
- `pbms-bridge-dev.md` — PBMS + G2P Bridge integration
- `spar-dev.md` — SPAR development
- `full-stack.md` — full integration smoke test

## First-time service setup

### PBMS / Social Registry (Odoo)

```bash
make setup
make install-odoo
make infra-up
make pbms-run
# or
make sr-run
```

Default Odoo master password: `admin`

### Registry Gen2

Install Python deps in each project:

```bash
make clone
bash scripts/install-python-project.sh ../openg2p-workspace/registry-platform/apis/openg2p-registry-staff-portal-api
bash scripts/install-python-project.sh ../openg2p-workspace/registry-platform/celery/openg2p-registry-celery-workers
```

Run migrations (once per API project):

```bash
cd ../openg2p-workspace/registry-platform/apis/openg2p-registry-staff-portal-api
source venv/bin/activate
set -a && source ../../../openg2p-developer/generated/registry/staff-portal-api.env && set +a
python main.py migrate
```

UI:

```bash
cd ../openg2p-workspace/registry-platform/ui/staff-portal-ui
npm install
make registry-run
```

### G2P Bridge

```bash
bash scripts/install-python-project.sh ../openg2p-workspace/g2p-bridge/core/partner-api
bash scripts/install-python-project.sh ../openg2p-workspace/g2p-bridge/core/celery-workers
bash scripts/install-python-project.sh ../openg2p-workspace/g2p-bridge/example-bank/openg2p-example-bank-api
make bridge-run
```

Migrate each API before first run (`python main.py migrate`).

### SPAR

```bash
cd ../openg2p-workspace/openg2p-spar/core/mapper-partner-api
virtualenv venv --python=python3
source venv/bin/activate
pip install -r ../test-requirements.txt
pip install greenlet
pip install -e ../models -e ../mapper-core -e .
python main.py migrate
make spar-run
```

## Keycloak (local)

Keycloak starts in dev mode at `http://localhost:8080`.

Create realm/clients matching your subsystem (typical local clients):

- `registry-staff-portal`
- `g2p-bridge`
- `spar-mapper`
- `spar-bene-portal`
- `openg2p-pbms-local`

Production Helm charts provision these automatically via `keycloak-init`. For local dev, create them manually in the admin console or import a realm export.

See `keycloak/README.md`.

## Version pinning

Repo and image pins live in `versions.yaml`. Override branch/tag refs in `.env`:

```bash
PBMS_REF=develop
REGISTRY_REF=develop
G2P_BRIDGE_REF=develop
SPAR_REF=develop
ODOO_REF=17.0
```

## Hybrid cluster development

If you have a shared dev Kubernetes environment, port-forward Postgres/MinIO/Keycloak instead of running local infra:

```bash
# Example
kubectl port-forward svc/commons-postgresql 5432:5432 -n dev
kubectl port-forward svc/minio 9000:9000 -n dev
kubectl port-forward svc/keycloak 8080:8080 -n dev
```

Update `.env` host/port values, then `make generate`.

## Troubleshooting

**Postgres port already in use**

Change `POSTGRES_PORT` in `.env` (e.g. `5433`) and run `make generate`.

**Odoo addons not found**

Ensure `make clone` completed and `OPENG2P_WORKSPACE` in `.env` points to the directory containing `odoo17`, `openg2p-pbms`, etc.

**Registry/Bridge container profile fails to pull images**

Some Registry Gen2 images may not be published for all tags. Use native mode (`make registry-run`) or build images locally from product repos.

**Reset databases**

```bash
make clean    # removes docker volumes including Postgres data
make infra-up # re-runs init scripts
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
