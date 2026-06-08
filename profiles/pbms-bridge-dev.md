# PBMS + G2P Bridge integration profile

## Goal

Test disbursement flows from PBMS through G2P Bridge to the example bank simulator.

## Steps

Terminal 1 — infrastructure:

```bash
make setup
make infra-up
```

Terminal 2 — G2P Bridge:

```bash
make bridge-run
```

Terminal 3 — PBMS:

```bash
make install-odoo
make pbms-run
```

## URLs

- PBMS: http://localhost:8069
- G2P Bridge partner API: http://localhost:8002/docs
- Example bank API: http://localhost:8003/docs

## Notes

- Configure PBMS payment manager / bridge settings to point at `http://localhost:8002`
- Example bank simulates sponsoring bank responses for local testing
- Create Keycloak client `g2p-bridge` if auth is enforced

## Optional container mode

```bash
make up-bridge
make up-pbms
```
