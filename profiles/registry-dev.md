# Registry Gen2 development profile

## Goal

Run Registry staff portal API, Celery workers, and UI against local Postgres/Redis/MinIO/Keycloak.

## Steps

```bash
cp .env.example .env
make setup
make infra-up

# Install Python deps (once)
bash scripts/install-python-project.sh ../openg2p-workspace/registry-platform/apis/openg2p-registry-staff-portal-api
bash scripts/install-python-project.sh ../openg2p-workspace/registry-platform/celery/openg2p-registry-celery-workers

# Migrate DB (once)
cd ../openg2p-workspace/registry-platform/apis/openg2p-registry-staff-portal-api
source venv/bin/activate
set -a && source ../../../openg2p-developer/generated/registry/staff-portal-api.env && set +a
python main.py migrate

# UI deps (once)
cd ../ui/staff-portal-ui && npm install

# Run stack
cd ../../../openg2p-developer
make registry-run
```

## URLs

- Staff API: http://localhost:8001/docs
- Staff UI: http://localhost:3000

## Databases

- `registry_db`
- `openg2p_gen2_master_data_db`
- `masterdatadb`

## Optional container mode

```bash
make up-registry
```

Requires published Registry Gen2 images for your selected tag.
