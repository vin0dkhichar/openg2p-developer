# Prerequisites for OpenG2P Local Developer Environment

Read this document **before** cloning repos or running `make setup`. It describes what must be installed, which ports must be free, and how to verify your machine is ready for the [OpenG2P developer setup](https://github.com/shibu-narayanan/openg2p-developer).

---

## Who this is for

Developers who want to run OpenG2P subsystems locally using the hybrid model in this repo:

- **Docker** for shared infrastructure (Postgres, Redis, MinIO, Keycloak)
- **Native processes** for application code (Python APIs, Celery, Next.js UI, Odoo)

Typical stacks include **National Social Registry (NSR)**, **Farmer Registry**, **PBMS**, **G2P Bridge**, and **SPAR**.

---

## Quick readiness checklist

Before starting setup, confirm all of the following:

- Docker Desktop (or Docker Engine + Compose v2) is installed and running
- Git, Make, Python 3.11–3.13 (3.14 works for most services; db-seed needs psycopg2-binary ≥2.9.12), and Node.js 18+ are available on your `PATH`
- Default ports listed below are free (or you plan to override them in `.env`)
- You have ~20 GB free disk space for clones, Docker volumes, and Python/Node dependencies
- You can reach GitHub (or your internal mirrors) to clone OpenG2P repositories
- You understand that registry staff UI login uses **three local services** (UI, IAM, Keycloak), not Keycloak alone
- For registry **change request / intake approvals**, AWE runs on port **8030** (Python **3.11+** required for AWE)

---

## Hardware


| Resource | Minimum    | Recommended                                  |
| -------- | ---------- | -------------------------------------------- |
| CPU      | 4 cores    | 8+ cores (Apple Silicon and Intel both work) |
| RAM      | 8 GB       | 16 GB+                                       |
| Disk     | 15 GB free | 30 GB+ free                                  |


Docker Desktop should be allocated at least **4 GB RAM** if you run the full infrastructure stack alongside native apps.

---

## Operating system


| OS      | Supported | Notes                                                                       |
| ------- | --------- | --------------------------------------------------------------------------- |
| macOS   | Yes       | Most tested. Keycloak and ID Generator run as `linux/amd64` under Rosetta on Apple Silicon. |
| Linux   | Yes       | Use Docker Engine + Compose plugin.                                         |
| Windows | Partial   | Use WSL2 with Docker Desktop integration; run all commands inside WSL.      |


---

## Required software

Install these tools before running any setup commands.


| Tool        | Version                            | Purpose                                      | Verify                   |
| ----------- | ---------------------------------- | -------------------------------------------- | ------------------------ |
| **Git**     | 2.30+                              | Clone orchestration and product repos        | `git --version`          |
| **Docker**  | 24+ with Compose v2                | Postgres, Redis, MinIO, Keycloak             | `docker compose version` |
| **Make**    | Any recent GNU/BSD Make            | Run setup targets                            | `make --version`         |
| **Python**  | 3.10+ (3.11+ for SPAR and **AWE**) | Registry, Bridge, SPAR, IAM, AWE, Odoo venvs | `python3 --version`      |
| **Node.js** | 18+ (20 LTS recommended)           | Registry Gen2 staff portal UI                | `node --version`         |
| **npm**     | 9+ (bundled with Node)             | UI dependencies                              | `npm --version`          |


### macOS optional packages

Useful for Odoo/Postgres tooling:

```bash
brew install libpq openssl
```

### Python notes

- Each subsystem creates its own virtual environment under the product repo (for example `registry-platform/apis/.../venv`).
- Do **not** rely on a single global Python env for all services.
- On macOS, prefer Homebrew Python or pyenv if system Python is older than 3.10.

### Node.js notes

- The staff portal UI uses **Next.js**. Use Node 18 or 20 LTS.
- The UI reads generated env from `.env.local` (copied automatically when you run `make *-registry-run`).

---

## Port availability

The default `.env.example` binds services to the ports below. **Each port must be free** on your machine, or you must change the value in `.env` and run `make generate`.

### Shared infrastructure (Docker)


| Service       | Default port | URL                     |
| ------------- | ------------ | ----------------------- |
| Postgres      | **5433**     | `localhost:5433`        |
| Redis         | 6379         | `localhost:6379`        |
| MinIO API     | 9000         | `http://localhost:9000` |
| MinIO console | 9001         | `http://localhost:9001` |
| Keycloak      | 8080         | `http://localhost:8080` |


> **Note:** Postgres defaults to **5433** (not 5432) to avoid conflicting with a locally installed PostgreSQL instance.

### Application services (native, typical NSR stack)


| Service                   | Default port | URL                                           |
| ------------------------- | ------------ | --------------------------------------------- |
| IAM Staff Portal API      | 8020         | `http://localhost:8020`                       |
| AWE API                   | 8030         | `http://localhost:8030/v1/awe/docs`           |
| AWE Admin UI              | 8031         | `http://localhost:8031`                       |
| ID Generator              | 8040         | `http://localhost:8040/v1/idgenerator/health` |
| NSR staff API             | 8011         | `http://localhost:8011/docs`                  |
| NSR staff UI              | 3010         | `http://localhost:3010`                       |
| Farmer Registry staff API | 8001         | `http://localhost:8001/docs`                  |
| Farmer Registry staff UI  | 3000         | `http://localhost:3000`                       |
| PBMS (Odoo)               | 8069         | `http://localhost:8069`                       |


### Check ports before setup

```bash
for p in 5433 6379 8080 8020 8030 8040 8011 3010; do
  if lsof -i tcp:$p >/dev/null 2>&1; then
    echo "IN USE: $p"
  else
    echo "free:   $p"
  fi
done
```

If a port is in use, either stop the conflicting process or override the port in `.env` and regenerate configs:

```bash
cp .env.example .env
# edit .env
make generate
```

---

## Network and access


| Requirement        | Details                                                              |
| ------------------ | -------------------------------------------------------------------- |
| GitHub access      | Required to clone OpenG2P repos listed in `versions.yaml`            |
| Docker image pulls | `postgres:16`, `redis:7`, `minio/minio`, `quay.io/keycloak/keycloak` |
| npm registry       | Required for staff portal UI install                                 |
| PyPI               | Required for Python dependency installs                              |


If you work behind a corporate proxy, configure Docker, Git, npm, and pip **before** running `make setup`.

---

## Workspace layout

By default, this repo expects a sibling workspace directory for product code:

```text
your-workspace/
├── openg2p-developer/          ← this orchestration repo
└── openg2p-workspace/          ← cloned product repos (default)
    ├── registry-platform/
    │   └── ui/staff-portal-ui/
    ├── iam-service/
    ├── farmer-registry/
    ├── national-social-registry/
    ├── g2p-bridge/
    ├── spar/
    ├── awe/
    └── ...
```

Set the workspace path in `.env`:

```bash
OPENG2P_WORKSPACE=../openg2p-workspace
```

Use an absolute path if you keep repos elsewhere.

---

## Environment file (`.env`)

Create your local config before infrastructure or app startup:

```bash
cp .env.example .env
```

Review at minimum:


| Variable                               | Why it matters                                |
| -------------------------------------- | --------------------------------------------- |
| `POSTGRES_PORT`                        | Avoid conflict with local Postgres            |
| `OPENG2P_WORKSPACE`                    | Where `make clone` puts product repos         |
| `KEYCLOAK_IAM_CLIENT_SECRET`           | Must match Keycloak client `iam-staff-portal` |
| `IAM_STAFF_PORT`                       | IAM API port used by staff UI SSO             |
| `NSR_REGISTRY_*` / `FARMER_REGISTRY_*` | API and UI ports per variant                  |


Generated runtime configs land in `generated/` (gitignored). After any `.env` change, run:

```bash
make generate
```

---

## Authentication prerequisites (Registry Gen2 / NSR)

Staff portal login is **not** a direct UI → Keycloak integration. Understand this before debugging auth issues.

```text
Browser → Staff UI (:3010)
       → UI /api/login
       → IAM API (:8020) /auth/start_authentication_transaction
       → Keycloak (:8080) login page
       → IAM API (:8020) /auth/callback
       → redirect back to Staff UI (:3010)
```

Implications:

1. **All three ports must be reachable in the browser** as `localhost` (or consistently renamed everywhere — UI env, Keycloak clients, IAM callback URL).
2. **IAM and Redis must be running** before UI login works. Redis stores short-lived OAuth state (5-minute TTL).
3. **Do not refresh** the IAM callback URL (`/auth/callback`). If login fails, go back to the UI and start again.
4. Default credentials:
  - Keycloak admin console: `admin` / `admin`
  - Staff realm dev user: `staff` / `staff`

See [keycloak/README.md](../keycloak/README.md) for realm and client details.

---

## AWE prerequisites (Registry CR + intake approvals)

Registry Gen2 routes change request and intake approvals through **AWE** (Approval Workflow Engine):

```text
Registry Staff API (:8011 or :8001)
  → AWE API (:8030)  POST /v1/awe/requests
  ← AWE webhook      POST /awe/webhooks/decision (signed HMAC)
Staff UI → Registry /awe/* proxy → AWE task inbox
```

Requirements:

1. **Python 3.11+** for the AWE service (`make install-awe`)
2. **Port 8030** free for AWE API (8031 optional for AWE Admin UI)
3. **`awe` database** on shared Postgres (created by `postgres-init` or `make awe-init`)
4. **`make awe-init`** seeds the registry webhook callback secret shared with the registry API env
5. Registry staff API env must have `REGISTRY_STAFF_PORTAL_API_AWE_ENABLED=true` (set automatically by `make generate`)

`make nsr-registry-run` / `make farmer-registry-run` start AWE when `make install-awe && make awe-init` has completed.

---

## Pre-flight verification

Run these commands after installing prerequisites and **before** `make setup`:

```bash
# 1. Core tools
git --version
docker compose version
python3 --version
node --version
make --version

# 2. Docker daemon
docker info >/dev/null && echo "Docker OK"

# 3. Clone orchestration repo (if not already)
git clone https://github.com/shibu-narayanan/openg2p-developer.git
cd openg2p-developer
cp .env.example .env

# 4. Port check (adjust list for your profile)
for p in 5433 6379 8080 8020 8030 8040 8011 3010; do
  lsof -i tcp:$p >/dev/null 2>&1 && echo "busy $p" || echo "ok   $p"
done
```

---

## Common blockers (resolve before setup)


| Symptom                                                   | Likely cause                                                                                           | Fix                                                                                                                                                                                                                                     |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Postgres fails to bind                                    | Local Postgres on 5432/5433                                                                            | Set `POSTGRES_PORT=5433` (or another free port) in `.env`, then `make generate`                                                                                                                                                         |
| Keycloak crashes on Apple Silicon                         | Architecture mismatch                                                                                  | Already handled via `platform: linux/amd64` in compose (Keycloak and ID Generator); ensure Docker Desktop is up to date                                                                                                                 |
| UI login returns 500 on `/api/login`                      | UI started without generated env                                                                       | Use `make nsr-registry-run` (copies env to `.env.local`) or source `generated/.../staff-portal-ui.env` before `npm run dev`                                                                                                             |
| Callback error `Login Provider Id not received`           | Expired OAuth state, or callback page refreshed                                                        | Restart login from UI; complete within 5 minutes; do not refresh `/auth/callback`                                                                                                                                                       |
| `AWE-ERR-008` / `AWE_BEARER_TOKEN_REQUIRED` on task stats | Registry API auth disabled in local dev (by design)                                                    | Expected with default `REGISTRY_AUTH_ENABLED=false`; other dashboard stats still work. Enable only if you accept stricter auth: set `REGISTRY_AUTH_ENABLED=true` in `.env`, run `make generate`, restart API                            |
| Dashboard or paging reload loop / repeated login          | Stale registry API still running with old env (often `AUTH_ENABLED=true` from a prior `make generate`) | Run `make generate` then `make nsr-registry-run` — it now stops old processes on ports 8011/8020/8030/3010 before restart. Confirm `generated/.../staff-portal-api.env` has `AUTH_ENABLED="false"`                                      |
| `make infra-up` ignores `.env` ports                      | Old Makefile behaviour                                                                                 | Ensure you are on a recent `main` branch where `infra-up` sources `.env` before compose                                                                                                                                                 |
| ID Generator times out on setup/run                       | Container not started, or Postgres volume predates `idgenerator` DB                                    | Run `make infra-up`; if Postgres already existed, create DB manually: `docker compose -f compose/docker-compose.infra.yml exec postgres psql -U postgres -c 'CREATE DATABASE idgenerator;'` then restart id-generator                   |
| Functional IDs never assigned / queue stays PENDING       | Celery beat not running, worker on wrong queue, or missing ID type in config                           | Run `make generate` then `make install-registry-extension VARIANT=...` and restart `make *-registry-run`. Confirm beat + worker logs; check `grep WORKER_QUEUE generated/<variant>/celery-*.env` and `config/id-generator/default.yaml` |
| Celery beat "not ready" on registry run                   | Beat venv not installed                                                                                | `make install-registry-extension VARIANT=national-social-registry` (installs worker + beat venvs) then `make generate`                                                                                                                  |
| `psycopg2-binary` build fails on Python 3.14 during setup | Product `db-seed/requirements.txt` pins `psycopg2-binary==2.9.9` (no cp314 wheel)                      | Pull latest `openg2p-developer` `main` (install script upgrades to `psycopg2-binary>=2.9.12`), remove `docker/db-seed/venv`, re-run `make nsr-setup`. Or set `OPENG2P_PYTHON=python3.13` in `.env`.                                    |


---

## Optional components


| Component             | When needed                                                    |
| --------------------- | -------------------------------------------------------------- |
| `openg2p-data` clone  | NSR sample data seed (`LOAD_SAMPLE_DATA=true`)                 |
| kubectl               | Port-forwarding to a shared dev cluster instead of local infra |
| pgAdmin / psql client | Inspecting seeded databases                                    |
| 16 GB+ RAM            | Running PBMS (Odoo) + Registry + infra together                |


---

## Subsystem-specific extras

### National Social Registry (NSR)

- Repos: `registry-platform` (includes `ui/staff-portal-ui`), `national-social-registry`, `iam-service`, **`awe`**
- Databases created on first infra start: `nsr_registry_db`, `nsr_master_data_db`, `iam_staff`, `awe`, `idgenerator`
- ID Generator (Docker): `http://localhost:8040` — required for functional ID assignment on registers with `functional_id_generation_required=true` (NSR Individual/Household)
- Celery: `make nsr-registry-run` starts **beat producers** + **worker** (native). Env: `generated/national-social-registry/celery-beat.env` and `celery-workers.env`; queue `nsr_registry_worker_queue`
- One-time bootstrap: **`make nsr-setup`** (install IAM/AWE/extension including Celery venvs, migrate schema, seed configuration SQL)
- Optional demo data: `LOAD_SAMPLE_DATA=true make nsr-registry-seed` (needs `openg2p-data` clone from `make setup`)

### Custom Registry Gen2 extension

Bootstrap and develop a new domain extension (same platform model as Farmer Registry / NSR):

```bash
make extension-package NAME=disability-registry
make extension-setup NAME=disability-registry
make extension-run NAME=disability-registry
```

See [profiles/custom-registry-extension-dev.md](../profiles/custom-registry-extension-dev.md).

### Farmer Registry

- Repos: `registry-platform` (includes `ui/staff-portal-ui`), `farmer-registry`, `iam-service`, **`awe`**
- Databases created on first infra start: `farmer_registry_db`, `farmer_master_data_db`, `iam_staff`, `awe`, `idgenerator`
- ID Generator (Docker): `http://localhost:8040` — wired into Celery workers when functional IDs are enabled on a register
- Celery: `make farmer-registry-run` starts **beat producers** + **worker** (native). Env: `generated/farmer-registry/celery-beat.env` and `celery-workers.env`; queue `farmer_registry_worker_queue`
- One-time bootstrap: **`make farmer-setup`** (install IAM/AWE/extension including Celery venvs, migrate schema, seed configuration SQL)
- Optional demo data: `LOAD_SAMPLE_DATA=true make farmer-registry-seed`

### PBMS (Odoo + background tasks)

- Monorepo: [OpenG2P/pbms](https://github.com/OpenG2P/pbms) — Odoo under `pbms/odoo/`, bg tasks under `pbms/core/` and `pbms/apis/`
- **Full stack:** `make pbms-setup` then `make pbms-run` starts Farmer Registry (default), PBMS staff portal API (port 8050), Celery beat/worker, and Odoo (8069)
- Databases: `pbmsdb`, `bgtaskdb`, plus registry DB (`farmer_registry_db` by default)
- Redis is required for Celery — set `USE_EXTERNAL_REDIS=false` to start Docker Redis, or run a local Redis on `REDIS_HOST:REDIS_PORT`
- Clone with `make clone PROFILE=pbms` (includes Farmer Registry repos for beneficiary search)
- See [profiles/pbms-dev.md](../profiles/pbms-dev.md)

---

## What to do next

When the checklist above passes:

1. `make setup` — clone product repos and generate configs (`PROFILE=national-social-registry` for NSR-only, `PROFILE=registry` default)
2. `make farmer-setup` or `make nsr-setup` — start infra, install services, migrate, and seed configuration for your registry variant
3. Follow the profile for your subsystem, for example [profiles/national-social-registry-dev.md](../profiles/national-social-registry-dev.md) or [profiles/farmer-registry-dev.md](../profiles/farmer-registry-dev.md)

For a minimal infra-only smoke test:

```bash
make setup
make infra-up
curl -s http://localhost:8080/realms/staff/.well-known/openid-configuration | head
```

---

## References

- [README.md](../README.md) — commands and architecture overview
- [keycloak/README.md](../keycloak/README.md) — SSO clients and login flow
- [profiles/](../profiles/) — curated stacks per subsystem
- [OpenG2P documentation](https://docs.openg2p.org/)

