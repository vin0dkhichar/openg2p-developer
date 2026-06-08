# Farmer Registry development profile

Farmer Registry is a Registry Gen2 domain implementation for farmers, households, land, crops, and livestock.

## Goal

Run the shared Registry Gen2 platform with the `farmer-extension` Python package installed.

## Steps

```bash
cp .env.example .env
make setup
make infra-up

make install-registry-extension VARIANT=farmer-registry

# Migrate DB (once)
cd ../openg2p-workspace/registry-platform/apis/openg2p-registry-staff-portal-api
source venv/bin/activate
set -a && source ../../../openg2p-developer/generated/farmer-registry/staff-portal-api.env && set +a
python main.py migrate

# UI deps (once)
cd ../../ui/staff-portal-ui && npm install

cd ../../../openg2p-developer
make farmer-registry-run
```

## URLs

- Staff API: http://localhost:8001/docs
- Staff UI: http://localhost:3000

## Databases

- `farmer_registry_db`
- `farmer_master_data_db`

## Repos involved

| Repo | Purpose |
|------|---------|
| `registry-platform` | Shared Gen2 APIs, Celery, UI |
| `farmer-registry` | Domain extension (`farmer-extension/`) |

## Optional container mode

```bash
make up-farmer-registry
```

Uses images such as `openg2p/openg2p-farmer-registry-staff-portal-api:develop`.

## References

- https://github.com/OpenG2P/farmer-registry
- https://docs.openg2p.org/products/registry
