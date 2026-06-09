# Keycloak local bootstrap

Keycloak runs via Docker in dev mode:

- Admin console: http://localhost:8080
- Default admin user: `admin`
- Default admin password: `admin`

## Automated staff realm (no manual steps)

`make infra-up` provisions everything required for local SSO:

1. **Keycloak** starts with `--import-realm` using `keycloak/realm-export/staff-realm.json` (fresh volumes).
2. **`keycloak-init` container** runs `scripts/keycloak-init.sh` idempotently to ensure:
   - Realm: `staff`
   - OIDC clients (see table below)
   - Client roles used by registry staff portals
   - Dev user: `staff` / `staff` (override via `.env`)

Verify:

```bash
curl -s http://localhost:8080/realms/staff/.well-known/openid-configuration | head
```

## OIDC clients created automatically

| Client ID | Used by | Notes |
|-----------|---------|-------|
| `iam-staff-portal` | IAM Staff Portal API | Confidential; callback `http://localhost:8020/auth/callback` |
| `farmer-registry-staff-portal` | Farmer Registry Gen2 staff portal | Public; redirect `http://localhost:3000/*` |
| `nsr-registry-staff-portal` | National Social Registry portal | Public; redirect `http://localhost:3010/*` |
| `g2p-bridge` | G2P Bridge APIs | Confidential service account |
| `spar-mapper` | SPAR mapper partner API | Confidential service account |
| `spar-bene-portal` | SPAR beneficiary portal API | Public |
| `openg2p-pbms-local` | PBMS Odoo OIDC (if enabled) | Public; redirect `http://localhost:8069/*` |
| `awe-admin-portal` | AWE policy admin SPA | Public; redirect `http://localhost:8031/*`; roles `AWE_ADMIN`, `AWE_VIEWER` |
| `awe-admin-resolver` | AWE → Keycloak approver lookup | Confidential service account; secret `dev-awe-resolver-secret` |

Default IAM client secret: `dev-iam-staff-secret` (`KEYCLOAK_IAM_CLIENT_SECRET` in `.env`).

## AWE (Approval Workflow Engine)

Registry change requests and intake submissions use AWE for multi-stage approvals.

```text
Registry Staff API → AWE (:8030) → approver tasks (Staff UI /awe/* proxy)
AWE → signed webhook → Registry Staff API /awe/webhooks/decision
```

One-time AWE setup after infra:

```bash
make install-awe
make awe-init      # creates schema + registry callback secret in awe DB
make generate      # enables REGISTRY_STAFF_PORTAL_API_AWE_* in registry env
```

`make nsr-registry-run` (and `make farmer-registry-run`) start AWE automatically when installed.

The dev user `staff` is granted `AWE_ADMIN` on `awe-admin-portal` for policy authoring in the AWE Admin UI at http://localhost:8031.

## Registry UI login flow

The staff portal UI authenticates through the **IAM Staff Portal API**, not Keycloak directly:

```
UI (:3010) → IAM (:8020)/auth/start_authentication_transaction → Keycloak staff realm → IAM callback → UI
```

One-time IAM setup after infra:

```bash
make install-iam
make iam-init
make generate   # sets IAM_URL=http://localhost:8020 in staff portal UI env
```

Then run a registry stack (`make nsr-registry-run`), open the UI, and sign in as `staff` / `staff`.

## Reset Keycloak state

If realm/clients are stale, reset Docker volumes:

```bash
make clean      # destructive: removes postgres/keycloak/minio volumes
make infra-up
make iam-init   # if postgres was recreated
```

## References

- OpenG2P PBMS Helm values: Keycloak audiences include `openg2p-pbms`, `openg2p-spar`
- G2P Bridge Helm chart provisions `g2p-bridge` client
- SPAR Helm chart provisions SPAR clients
- NSR Helm chart provisions `registry-staff-portal` client roles in the `staff` realm
