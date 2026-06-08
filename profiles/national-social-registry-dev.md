# National Social Registry development profile

National Social Registry (NSR) is a Registry Gen2 domain implementation for national social-protection registers.

## Goal

Run the shared Registry Gen2 platform with the `nsr-extension` Python package installed, seeded configuration, and the Gen2 staff portal UI.

## Steps

```bash
cp .env.example .env
make setup
make infra-up

make install-registry-extension VARIANT=national-social-registry
make install-registry-ui
make nsr-registry-init

# Optional demo registrants, sub-tables, templates, and images
LOAD_SAMPLE_DATA=true make nsr-registry-seed
# LOAD_TEMPLATES=true LOAD_IMAGES=true make nsr-registry-seed

make nsr-registry-run
```

## URLs

- Staff API: http://localhost:8011/docs
- Staff UI: http://localhost:3010

## Databases

- `nsr_registry_db` — registry data (schema + configuration seed)
- `nsr_master_data_db` — master data

## What `nsr-registry-init` does

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

| Repo | Purpose |
|------|---------|
| `registry-platform` | Shared Gen2 APIs and Celery |
| `national-social-registry` | Domain extension + db-seed tooling |
| `openg2p-data` | Shared demography CSVs for NSR sample load |
| `openg2p-registry-gen2-staff-portal-ui` | Staff portal frontend |

## Optional container mode

```bash
make up-nsr-registry
```

Uses images such as `openg2p/openg2p-nsr-registry-staff-portal-api:develop`.

## References

- https://github.com/OpenG2P/national-social-registry
- https://docs.openg2p.org/products/registry
