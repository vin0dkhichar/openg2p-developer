# Full stack integration profile

## Goal

Smoke-test multiple OpenG2P subsystems together locally.

## Recommended approach

Use native mode for Odoo/FastAPI services and Docker for infrastructure:

```bash
make setup
make infra-up
make install-odoo
make farmer-setup
make nsr-setup
```

Then run each stack in separate terminals:

```bash
make pbms-run
make farmer-registry-run
make nsr-registry-run
make bridge-run
make spar-run
```

## Container-only shortcut (best effort)

```bash
make up-full
```

This starts infrastructure plus container profiles for PBMS, Farmer Registry, NSR, Bridge, and SPAR. Image availability varies by tag; native mode is more reliable for active development.

## Integration checklist

- [ ] Postgres databases created (`make infra-up`)
- [ ] Keycloak clients configured (`keycloak/README.md`)
- [ ] ID Generator healthy on :8040 (`curl http://localhost:8040/v1/idgenerator/health`)
- [ ] PBMS reachable on :8069
- [ ] Farmer Registry staff API reachable on :8001
- [ ] NSR staff API reachable on :8011
- [ ] Registry Celery beat + worker running (native `make *-registry-run`, or check logs for `functional_id_allocation_beat_producer`)
- [ ] G2P Bridge partner API reachable on :8002
- [ ] SPAR mapper API reachable on :8004
- [ ] PBMS bridge addon configured to local bridge URL

## Reset

```bash
make clean
make setup
make infra-up
```
