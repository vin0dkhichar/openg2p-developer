# Minimal profile: shared infrastructure only

Use this when you are developing one service against shared deps, or using port-forwarded cluster services.

## Start

```bash
make setup
make infra-up
```

## Includes

- Postgres (all OpenG2P databases pre-created)
- Redis
- MinIO (+ default buckets)
- Keycloak (dev mode)

## Next step

Pick a subsystem profile and run the corresponding native command.
