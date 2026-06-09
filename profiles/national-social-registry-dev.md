# National Social Registry development profile

> **Before you start:** complete [Prerequisites](../docs/prerequisites.md) (tools, ports, IAM/Keycloak auth flow).

National Social Registry (NSR) is a Registry Gen2 domain implementation for national social-protection registers.

## Goal

Run the shared Registry Gen2 platform with the `nsr-extension` Python package installed, seeded configuration, and the Gen2 staff portal UI.

## Steps

```bash
cp .env.example .env
make setup
make nsr-setup      # infra + IAM + AWE + migrate + configuration seed

# Optional demo registrants (set LOAD_SAMPLE_DATA=true in .env first, or run manually)
LOAD_SAMPLE_DATA=true make nsr-registry-seed
# LOAD_TEMPLATES=true LOAD_IMAGES=true make nsr-registry-seed

make nsr-registry-run
```

Equivalent manual steps (if you prefer not to use `nsr-setup`):

```bash
make infra-up
make install-registry-extension VARIANT=national-social-registry
make install-registry-ui
make install-iam && make iam-init
make install-awe && make awe-init
make nsr-registry-init
```

## URLs

- Staff API: [http://localhost:8011/docs](http://localhost:8011/docs)
- Staff UI: [http://localhost:3010](http://localhost:3010)
- AWE API: [http://localhost:8030/v1/awe/docs](http://localhost:8030/v1/awe/docs)
- AWE Admin UI (optional): [http://localhost:8031](http://localhost:8031) — policy authoring; login via Keycloak `staff` user with `AWE_ADMIN` role

## Approval workflow (AWE)

Change requests and intake submissions route approvals through **AWE** (Approval Workflow Engine):

```text
Registry Staff API → AWE API (:8030) → approver tasks in Staff UI
AWE → webhook → Registry Staff API /awe/webhooks/decision
```

`make nsr-registry-run` starts AWE alongside IAM and the registry stack when `make install-awe && make awe-init` has been run.

Configure policies in the AWE Admin UI or bind policies in the Registry staff portal under **Configuration → AWE Policy Configuration**.

## Databases

- `nsr_registry_db` — registry data (schema + configuration seed)
- `nsr_master_data_db` — master data

## What `make nsr-setup` does

Same steps as `make farmer-setup`, but for the NSR extension and `nsr_registry_db`.

One command after `make setup` (starts infra automatically):

1. Installs and initialises IAM and AWE
2. Installs the NSR extension and staff portal UI dependencies
3. Installs db-seed Python tools (for optional sample data / MinIO uploads)
4. Migrates schema into `nsr_registry_db`
5. Applies extension `meta_data/*.sql` — register definitions, schemas, tabs, themes, branding

Set `LOAD_SAMPLE_DATA=true` in `.env` before `make nsr-setup` to also load demo registrants in the same run.

## What `make nsr-registry-init` does

1. `python main.py migrate` — creates/updates schema in `nsr_registry_db`
2. Applies extension `meta_data/*.sql` — register definitions, schemas, tabs, themes, registry branding

## Sample data

NSR demo data uses `openg2p-data` CSVs plus JSON seed files from the product repo:

```bash
LOAD_SAMPLE_DATA=true make nsr-registry-seed
```

This runs `national-social-registry/docker/db-seed/load_sample_data.py` against your local Postgres.

Optional MinIO uploads:

```bash
LOAD_SAMPLE_DATA=true LOAD_TEMPLATES=true LOAD_IMAGES=true make nsr-registry-seed
```

Or use the published db-seed container after migrate:

```bash
make nsr-registry-migrate
LOAD_SAMPLE_DATA=true make up-nsr-registry-seed
```

## UI repo

Default UI path: `openg2p-registry-gen2-staff-portal-ui` on port `3010` (override with `NSR_REGISTRY_UI_PATH` in `.env`).

Farmer Registry uses the same UI repo on port `3000` with a separate generated env file, so both variants can run side by side.

## Repos involved


| Repo                                    | Purpose                                    |
| --------------------------------------- | ------------------------------------------ |
| `registry-platform`                     | Shared Gen2 APIs and Celery                |
| `national-social-registry`              | Domain extension + db-seed tooling         |
| `openg2p-iam-service`                   | SSO broker for staff portal login          |
| `awe`                                   | Approval Workflow Engine (CR + intake)     |
| `openg2p-data`                          | Shared demography CSVs for NSR sample load |
| `openg2p-registry-gen2-staff-portal-ui` | Staff portal frontend                      |


## Optional container mode

```bash
make up-nsr-registry
```

Uses images such as `openg2p/openg2p-nsr-registry-staff-portal-api:develop`.

## References

- [https://github.com/OpenG2P/national-social-registry](https://github.com/OpenG2P/national-social-registry)
- [https://docs.openg2p.org/products/registry](https://docs.openg2p.org/products/registry)

