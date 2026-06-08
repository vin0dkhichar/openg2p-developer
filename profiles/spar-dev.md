# SPAR development profile

## Goal

Run SPAR mapper partner API and beneficiary portal API locally.

## Steps

```bash
cp .env.example .env
make setup
make infra-up

cd ../openg2p-workspace/openg2p-spar/core/mapper-partner-api
virtualenv venv --python=python3
source venv/bin/activate
pip install -r ../test-requirements.txt
pip install greenlet
pip install -e ../models -e ../mapper-core -e .

set -a && source ../../../openg2p-developer/generated/spar/mapper-partner-api.env && set +a
python main.py migrate

cd ../../../openg2p-developer
make spar-run
```

Repeat dependency install/migrate for `core/bene-portal-api` if needed.

## URLs

- Mapper API: http://localhost:8004/docs
- Bene portal API: http://localhost:8005/docs

## Database

- DB: `spardb`
- User: `sparuser` / `password`

## Optional container mode

SPAR containers are not enabled by default. Use native mode above, or add Docker builds from `openg2p-spar/docker/` after cloning.
