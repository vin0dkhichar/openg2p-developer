# OpenG2P Developer Setup

One repo to bootstrap local development for OpenG2P subsystems:

- **PBMS** (Odoo)
- **Farmer Registry** (Registry Gen2 implementation)
- **National Social Registry** (Registry Gen2 implementation)
- **G2P Bridge** (FastAPI + Celery + example bank)
- **SPAR** (mapper + beneficiary portal APIs)

Shared infrastructure runs in Docker. Application services run **natively by default** (better for Odoo/Python/Node iteration). Container profiles are available for onboarding and smoke testing.

## Prerequisites

See **[docs/prerequisites.md](docs/prerequisites.md)** for the full pre-setup guide (hardware, ports, tools, auth flow, and pre-flight checks).

Summary:

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
make setup PROFILE=national-social-registry   # clone only NSR-related repos
make infra-up

# National Social Registry (recommended one-time bootstrap)
make nsr-setup      # IAM, AWE, migrate, configuration seed
make nsr-registry-run

# Or Farmer Registry
make farmer-setup   # IAM, AWE, migrate, configuration seed
make farmer-registry-run
```

Run `make help` for all targets.

## Architecture

```text
openg2p-developer/              <- this repo (orchestration)
../openg2p-workspace/           <- cloned product repos (OPENG2P_WORKSPACE)
generated/                      <- generated odoo conf + .env files (gitignored)
compose/                        <- docker compose profiles
scripts/                        <- clone, generate, run helpers
templates/                      <- config templates
profiles/                       <- curated developer stacks
```

Clone only what you need:

```bash
make clone-profiles                              # list profiles
make setup PROFILE=national-social-registry      # NSR repos only
make setup PROFILE=farmer-registry               # Farmer Registry repos only
make setup PROFILE=registry                      # both registries (default)
make setup PROFILE=pbms                          # Odoo / PBMS only
make setup PROFILE=full                          # everything
```

### Registry Gen2 model

Both **Farmer Registry** and **National Social Registry** are domain implementations on top of the shared Registry Gen2 platform:

```text
registry-platform/              <- shared APIs, Celery, staff portal UI
farmer-registry/farmer-extension/
national-social-registry/nsr-extension/
```

Native development installs the relevant extension into three platform venvs (staff API, Celery worker, Celery beat producers). This step is **included** in `make farmer-setup`, `make nsr-setup`, and `make extension-setup`; run it manually only when reinstalling an extension or working step-by-step:

```bash
make install-registry-extension VARIANT=farmer-registry
make install-registry-extension VARIANT=national-social-registry
make install-registry-extension VARIANT=disability-registry   # custom extension slug
```

### Registry async processing (Celery)

Registry Gen2 uses **two native Celery processes** per variant (started by `make farmer-registry-run`, `make nsr-registry-run`, or `make extension-run`):


| Process                   | Code path                                                         | Role                                                                                                             |
| ------------------------- | ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Celery beat producers** | `registry-platform/celery/openg2p-registry-celery-beat-producers` | Polls DB work queues (functional IDs, dedup, ingest, scores) and enqueues worker tasks on Redis                  |
| **Celery worker**         | `registry-platform/celery/openg2p-registry-celery-workers`        | Executes tasks from the variant worker queue (`farmer_registry_worker_queue`, `nsr_registry_worker_queue`, etc.) |


Generated env files (after `make generate`):

- `generated/<variant>/celery-beat.env` — beat DB + `REGISTRY_CELERY_BEAT_WORKER_QUEUE`
- `generated/<variant>/celery-workers.env` — worker DB, MinIO, ID Generator URL, `REGISTRY_CELERY_WORKERS_WORKER_QUEUE`

The beat and worker queues **must match** (same value in both files). Functional ID assignment also requires the **ID Generator** Docker service (`:8040`, started with `make infra-up`) and matching `id_types` in `config/id-generator/default.yaml`.

### Custom extension products

Bootstrap a new empty extension repo (like FR/NSR) with one command:

```bash
make extension-package NAME=disability-registry   # extension + docker/ + helm/
make extension-setup NAME=disability-registry
make extension-run NAME=disability-registry
```

See [profiles/custom-registry-extension-dev.md](profiles/custom-registry-extension-dev.md).

### Shared infrastructure (Docker)


| Service      | URL / Port                   | Default credentials     |
| ------------ | ---------------------------- | ----------------------- |
| Postgres     | `localhost:5432`             | `postgres` / `postgres` |
| Redis        | `localhost:6379`             | none                    |
| MinIO        | API `:9000`, console `:9001` | `admin` / `secret`      |
| Keycloak     | `http://localhost:8080`      | `admin` / `admin`       |
| ID Generator | `http://localhost:8040`      | none (registry IDs)     |


### Application ports (native mode defaults)


| Service                            | Port |
| ---------------------------------- | ---- |
| PBMS Odoo                          | 8069 |
| Farmer Registry staff API          | 8001 |
| Farmer Registry staff UI           | 3000 |
| National Social Registry staff API | 8011 |
| National Social Registry staff UI  | 3010 |
| AWE API                            | 8030 |
| AWE Admin UI                       | 8031 |
| ID Generator                       | 8040 |
| G2P Bridge partner API             | 8002 |
| G2P Bridge example bank            | 8003 |
| SPAR mapper API                    | 8004 |
| SPAR bene portal API               | 8005 |


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
make install-registry-ui
make farmer-setup           # one-time Farmer Registry bootstrap (migrate + configuration seed)
make nsr-setup              # one-time NSR bootstrap (migrate + configuration seed)
make farmer-registry-init
make nsr-registry-init

# Infrastructure
make infra-up
make infra-down
make status
make logs
make clean          # removes docker volumes

# Native development (recommended)
make pbms-run
make farmer-registry-init
make farmer-registry-run
make nsr-registry-init
make nsr-registry-run
make bridge-run
make spar-run

# Registry seed helpers
make farmer-registry-migrate
make farmer-registry-seed
LOAD_SAMPLE_DATA=true make farmer-registry-seed
make nsr-registry-migrate
make nsr-registry-seed
LOAD_SAMPLE_DATA=true LOAD_TEMPLATES=true make nsr-registry-seed

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
- `custom-registry-extension-dev.md` — bootstrap a new empty Registry Gen2 extension product
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

Both variants use the same bootstrap model: IAM, AWE, extension install, migrate, and configuration seed.

**Farmer Registry:**

```bash
make setup
make farmer-setup
make farmer-registry-run
```

**National Social Registry:**

```bash
make setup
make nsr-setup
make nsr-registry-run
```

`make infra-up` automatically creates the Keycloak `staff` realm, OIDC clients, and dev user `staff` / `staff`. See `keycloak/README.md`.

Optional demo data:

```bash
LOAD_SAMPLE_DATA=true make farmer-registry-seed
LOAD_SAMPLE_DATA=true make nsr-registry-seed   # needs openg2p-data clone
```

Manual steps (if you prefer not to use `farmer-setup` / `nsr-setup`):

```bash
make infra-up
make install-registry-extension VARIANT=farmer-registry   # or national-social-registry
make install-registry-ui
make install-iam && make iam-init
make install-awe && make awe-init
make farmer-registry-init   # or make nsr-registry-init
make farmer-registry-run    # or make nsr-registry-run
```

Staff portal UI login: [http://localhost:3010](http://localhost:3010) (NSR) or [http://localhost:3000](http://localhost:3000) (Farmer) using `staff` / `staff`.

Each variant uses its own database, generated env files, API/UI ports, and extension seed SQL. The staff portal UI repo is shared by default (`openg2p-registry-gen2-staff-portal-ui`), but each variant gets a separate `.env` and port so Farmer Registry and NSR can run together.

Seed steps:


| Step                  | Farmer Registry                                   | National Social Registry                       |
| --------------------- | ------------------------------------------------- | ---------------------------------------------- |
| One-time bootstrap    | `make farmer-setup`                               | `make nsr-setup`                               |
| Schema                | `make farmer-registry-migrate`                    | `make nsr-registry-migrate`                    |
| Configuration SQL     | `make farmer-registry-seed`                       | `make nsr-registry-seed`                       |
| Sample data           | `LOAD_SAMPLE_DATA=true make farmer-registry-seed` | `LOAD_SAMPLE_DATA=true make nsr-registry-seed` |
| Migrate + config only | `make farmer-registry-init`                       | `make nsr-registry-init`                       |


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