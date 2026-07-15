# PBMS development profile

## Goal

Run the full PBMS Gen2 stack locally: Odoo UI, background-task engine (staff portal API + Celery), and a social registry for beneficiary data.

PBMS is the consolidated monorepo [OpenG2P/pbms](https://github.com/OpenG2P/pbms) (`develop` branch).

## One-time setup

```bash
cp .env.example .env
make pbms-setup
```

This clones Odoo + PBMS + Farmer Registry, starts infra, installs Python deps, bootstraps registry + Odoo + `bgtaskdb`.

## Run (full stack)

```bash
make pbms-run
```

`make pbms-run` starts, in order:

| Service | Port | Notes |
|---------|------|--------|
| Infrastructure | Postgres, Redis, Keycloak, MinIO | via `make infra-up` |
| Farmer Registry (default) | 8001 / 3000 | Staff API + UI; set `PBMS_REGISTRY_VARIANT=national-social-registry` for NSR |
| PBMS Staff Portal API | 8050 | Odoo calls this for eligibility / entitlement / disbursement |
| PBMS Celery beat + worker | — | Processes bg tasks on Redis queue `bg_task_worker_queue` |
| PBMS Odoo | 8069 | Sets `g2p_pbms.staff_portal_api_url` automatically |

Open http://localhost:8069 (Odoo) and http://localhost:8050/docs (PBMS staff API).

## Repos cloned (`PROFILE=pbms`)

| Path | Repository |
|------|------------|
| `odoo17/` | https://github.com/odoo/odoo.git (`17.0`) |
| `pbms/` | https://github.com/OpenG2P/pbms.git (`develop`) |
| `openg2p-odoo-commons/` | https://github.com/OpenG2P/openg2p-odoo-commons.git |
| `registry-platform/`, `farmer-registry/`, `iam-service/`, `awe/` | Required for beneficiary search against Farmer Registry |

## Configuration (`.env`)

| Variable | Default | Purpose |
|----------|---------|---------|
| `PBMS_REGISTRY_VARIANT` | `farmer-registry` | Registry DB the bg-task engine reads |
| `PBMS_WITH_REGISTRY` | `true` | Set `false` to run Odoo + bg tasks only |
| `PBMS_STAFF_API_PORT` | `8050` | PBMS staff portal API port |
| `PBMS_REDIS_DB` | `1` | Redis DB index for PBMS Celery (registry uses `0`) |
| `USE_EXTERNAL_REDIS` | `true` | Celery requires Redis; use `false` to start Docker Redis |

## Manual steps (if not using `pbms-setup`)

```bash
make setup PROFILE=pbms
make install-odoo
make install-pbms-bg-tasks
make infra-up
make farmer-setup          # or nsr-setup
make pbms-init
make init-pbms-bg-tasks
make pbms-run
```

## Database

- `pbmsdb` — Odoo (owner: `pbmsuser`)
- `bgtaskdb` — background-task state
- `farmer_registry_db` — social registry (default)

## Odoo: Staff Portal API URL (important)

In **Settings → G2P PBMS → Staff Portal API URL**, use the **PBMS background-task API**, not the registry staff API:

| Correct | Wrong |
|---------|-------|
| `http://localhost:8050` | `http://localhost:8001` |

Odoo calls `/summary`, `/search_beneficiaries`, etc. on this URL. Those routes live on the **PBMS staff portal API** (`make pbms-run` port **8050**). That service reads the **registry database directly** (Farmer Registry on `farmer_registry_db`) — you do not point Odoo at the registry REST API on 8001.

`make pbms-run` sets this automatically to `http://localhost:8050`.

## Beneficiary list / search

The beneficiary search UI shows **no rows** until Celery has processed the list:

1. Create a beneficiary list in Odoo and submit eligibility.
2. Confirm PBMS Celery worker logs show `beneficiary_list_worker` completing.
3. Then open the summary / beneficiary search wizard again.

If eligibility has not run yet, search returns an empty list (not a server error).

## G2P Bridge

Disbursement workers call G2P Bridge when configured. For end-to-end payment testing with SPAR, see `pbms-bridge-spar-dev.md` (full stack) or `pbms-bridge-dev.md` (Bridge only).
