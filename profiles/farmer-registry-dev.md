# Farmer Registry development profile

Farmer Registry is a Registry Gen2 domain implementation for farmers, households, land, crops, and livestock.

## Goal

Run the shared Registry Gen2 platform with the `farmer-extension` Python package installed, seeded configuration, and the Gen2 staff portal UI.

## Steps

```bash
cp .env.example .env
make setup
make infra-up

make install-registry-extension VARIANT=farmer-registry
make install-registry-ui
make farmer-registry-init

# Optional demo registrants and supporting rows
LOAD_SAMPLE_DATA=true make farmer-registry-seed

make farmer-registry-run
```

## URLs

- Staff API: http://localhost:8001/docs
- Staff UI: http://localhost:3000

## Databases

- `farmer_registry_db` — registry data (schema + configuration seed)
- `farmer_master_data_db` — master data

## What `farmer-registry-init` does

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

| Repo | Purpose |
|------|---------|
| `registry-platform` | Shared Gen2 APIs and Celery |
| `farmer-registry` | Domain extension + db-seed Docker spec |
| `openg2p-registry-gen2-staff-portal-ui` | Staff portal frontend |

## Optional container mode

```bash
make up-farmer-registry
```

Uses images such as `openg2p/openg2p-farmer-registry-staff-portal-api:develop`.

## References

- https://github.com/OpenG2P/farmer-registry
- https://docs.openg2p.org/products/registry
