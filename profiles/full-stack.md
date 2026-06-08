# Full stack integration profile

## Goal

Smoke-test multiple OpenG2P subsystems together locally.

## Recommended approach

Use native mode for Odoo/FastAPI services and Docker for infrastructure:

```bash
make setup
make infra-up
make install-odoo
```

Then run each stack in separate terminals:

```bash
make pbms-run
make sr-run
make registry-run
make bridge-run
make spar-run
```

## Container-only shortcut (best effort)

```bash
make up-full
```

This starts infrastructure plus container profiles for PBMS, Social Registry, Registry, and Bridge. Image availability varies by tag; native mode is more reliable for active development.

## Integration checklist

- [ ] Postgres databases created (`make infra-up`)
- [ ] Keycloak clients configured (`keycloak/README.md`)
- [ ] PBMS reachable on :8069
- [ ] Registry staff API reachable on :8001
- [ ] G2P Bridge partner API reachable on :8002
- [ ] SPAR mapper API reachable on :8004
- [ ] PBMS bridge addon configured to local bridge URL

## Reset

```bash
make clean
make setup
make infra-up
```
