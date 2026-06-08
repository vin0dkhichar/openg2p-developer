# National Social Registry development profile

National Social Registry (NSR) is a Registry Gen2 domain implementation for national social-protection registers.

## Goal

Run the shared Registry Gen2 platform with the `nsr-extension` Python package installed.

## Steps

```bash
cp .env.example .env
make setup
make infra-up

make install-registry-extension VARIANT=national-social-registry

# Migrate DB (once)
cd ../openg2p-workspace/registry-platform/apis/openg2p-registry-staff-portal-api
source venv/bin/activate
set -a && source ../../../openg2p-developer/generated/national-social-registry/staff-portal-api.env && set +a
python main.py migrate

# UI deps (once)
cd ../../ui/staff-portal-ui && npm install

cd ../../../openg2p-developer
make nsr-registry-run
```

## URLs

- Staff API: http://localhost:8011/docs
- Staff UI: http://localhost:3010

## Databases

- `nsr_registry_db`
- `nsr_master_data_db`

## Repos involved

| Repo | Purpose |
|------|---------|
| `registry-platform` | Shared Gen2 APIs, Celery, UI |
| `national-social-registry` | Domain extension (`nsr-extension/`) |

## Optional container mode

```bash
make up-nsr-registry
```

Uses images such as `openg2p/openg2p-nsr-registry-staff-portal-api:develop`.

## References

- https://github.com/OpenG2P/national-social-registry
- https://docs.openg2p.org/products/registry
