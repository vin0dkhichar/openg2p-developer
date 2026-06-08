# Minimal profile: shared infrastructure only

Use this when you are developing one service against shared deps, or using port-forwarded cluster services.

## Start

```bash
make setup
make infra-up
```

## Includes

- Postgres (PBMS, Farmer Registry, NSR, Bridge, SPAR databases pre-created)
- Redis
- MinIO (+ default buckets)
- Keycloak (dev mode)

## Next step

Pick a subsystem profile:

- `profiles/pbms-dev.md`
- `profiles/farmer-registry-dev.md`
- `profiles/national-social-registry-dev.md`
- `profiles/pbms-bridge-dev.md`
- `profiles/spar-dev.md`
