# Keycloak local bootstrap

Keycloak runs via Docker in dev mode:

- Admin console: http://localhost:8080
- Default admin user: `admin`
- Default admin password: `admin`

## What to configure manually

OpenG2P production deployments create OIDC clients through Helm `keycloak-init` subcharts. For local development, create a `staff` realm (or use `master` for quick tests) and add clients used by generated env files:

| Client ID                      | Used by                          |
|--------------------------------|----------------------------------|
| `farmer-registry-staff-portal` | Farmer Registry Gen2 staff portal|
| `nsr-registry-staff-portal`    | National Social Registry portal  |
| `g2p-bridge`                   | G2P Bridge APIs                  |
| `spar-mapper`                  | SPAR mapper partner API          |
| `spar-bene-portal`             | SPAR beneficiary portal API      |
| `openg2p-pbms-local`           | PBMS Odoo OIDC (if enabled)      |

Suggested redirect URIs for local dev:

- `http://localhost:3000/*`
- `http://localhost:3010/*`
- `http://localhost:8069/*`

## Optional realm import

To automate client creation, export a realm from a working dev cluster and place JSON files in `keycloak/realm-export/`, then change the Keycloak service command in `compose/docker-compose.infra.yml` to:

```yaml
command: start-dev --import-realm
volumes:
  - ../keycloak/realm-export:/opt/keycloak/data/import:ro
```

## References

- OpenG2P PBMS Helm values: Keycloak audiences include `openg2p-pbms`, `openg2p-sr`, `openg2p-spar`
- G2P Bridge Helm chart provisions `g2p-bridge` client
- SPAR Helm chart provisions SPAR clients
