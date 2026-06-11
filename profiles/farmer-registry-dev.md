# Farmer Registry development profile

> **Before you start:** complete [Prerequisites](../docs/prerequisites.md) (tools, ports, IAM/Keycloak auth flow).

Farmer Registry is a Registry Gen2 domain implementation for farmers, households, land, crops, and livestock.

## Goal

Run the shared Registry Gen2 platform with the `farmer-extension` Python package installed, seeded configuration, and the Gen2 staff portal UI.

## Steps

```bash
cp .env.example .env
make setup
make farmer-setup   # infra + IAM + AWE + migrate + configuration seed

# Optional demo registrants (set LOAD_SAMPLE_DATA=true in .env first, or run manually)
LOAD_SAMPLE_DATA=true make farmer-registry-seed

make farmer-registry-run
```

Equivalent manual steps (if you prefer not to use `farmer-setup`):

```bash
make infra-up
make install-registry-extension VARIANT=farmer-registry
make install-registry-ui
make install-iam && make iam-init
make install-awe && make awe-init
make farmer-registry-init
```

## URLs

- Staff API: [http://localhost:8001/docs](http://localhost:8001/docs)
- Staff UI: [http://localhost:3000](http://localhost:3000)
- ID Generator: [http://localhost:8040/v1/idgenerator/health](http://localhost:8040/v1/idgenerator/health) (Docker, from `make infra-up`)

## Native stack (`make farmer-registry-run`)

Starts these processes (after `make farmer-setup`):


| Process               | Env file                                         |
| --------------------- | ------------------------------------------------ |
| AWE API               | `generated/awe/awe-api.env`                      |
| Farmer staff API      | `generated/farmer-registry/staff-portal-api.env` |
| Celery worker         | `generated/farmer-registry/celery-workers.env`   |
| Celery beat producers | `generated/farmer-registry/celery-beat.env`      |
| IAM staff API         | `generated/iam/staff-portal-api.env`             |
| Staff UI              | `generated/farmer-registry/staff-portal-ui.env`  |


Beat producers poll async work queues and dispatch tasks to Redis queue `farmer_registry_worker_queue`; the worker consumes that queue. Re-run `make generate` and `make install-registry-extension VARIANT=farmer-registry` after pulling orchestration changes.

## Databases

- `farmer_registry_db` — registry data (schema + configuration seed)
- `farmer_master_data_db` — master data
- `idgenerator` — functional ID pools (ID Generator Docker service on `:8040`)

## What `make farmer-setup` does

One command after `make setup` (starts infra automatically):

1. Installs and initialises IAM and AWE
2. Installs the Farmer Registry extension, **Celery worker + beat**, and staff portal UI dependencies
3. Installs db-seed Python tools (for optional sample data / MinIO uploads)
4. Migrates schema into `farmer_registry_db`
5. Applies extension `meta_data/*.sql` — register definitions, schemas, tabs, themes, branding

Set `LOAD_SAMPLE_DATA=true` in `.env` before `make farmer-setup` to also load demo registrants in the same run.

## What `make farmer-registry-init` does

1. `python main.py migrate` — creates/updates schema in `farmer_registry_db`
2. Applies extension `meta_data/*.sql` — register definitions, schemas, tabs, themes, registry name/logo

## Sample data

Farmer demo rows ship as SQL under `farmer-extension/.../sample_data/`:

```bash
LOAD_SAMPLE_DATA=true make farmer-registry-seed
```

Or use the published db-seed container after migrate:

```bash
make farmer-registry-migrate
LOAD_SAMPLE_DATA=true make up-farmer-registry-seed
```

## UI repo

Default UI path: `openg2p-registry-gen2-staff-portal-ui` (override with `FARMER_REGISTRY_UI_PATH` in `.env`).

Each variant uses its own generated UI env file and port, even when the UI repo is shared.

## Repos involved


| Repo                                    | Purpose                                                |
| --------------------------------------- | ------------------------------------------------------ |
| `registry-platform`                     | Shared Gen2 APIs, Celery worker, Celery beat producers |
| `farmer-registry`                       | Domain extension + db-seed Docker spec                 |
| `openg2p-registry-gen2-staff-portal-ui` | Staff portal frontend                                  |
| `openg2p-iam-service`                   | IAM staff portal API                                   |
| `awe`                                   | Approval Workflow Engine                               |


## Optional container mode

```bash
make up-farmer-registry
```

Uses images such as `openg2p/openg2p-farmer-registry-staff-portal-api:develop`.

## References

- [https://github.com/OpenG2P/farmer-registry](https://github.com/OpenG2P/farmer-registry)
- [https://docs.openg2p.org/products/registry](https://docs.openg2p.org/products/registry)

