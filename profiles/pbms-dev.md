# PBMS development profile

## Goal

Run PBMS Odoo locally with hot reload and debugger support.

## Steps

```bash
cp .env.example .env
make setup
make install-odoo
make infra-up
make pbms-run
```

Open http://localhost:8069

## Optional container mode

```bash
make up-pbms
```

Uses `openg2p/openg2p-pbms-core:1.2.6`.

## G2P Bridge integration

PBMS talks to G2P Bridge through Odoo addons such as `g2p_bridge_configuration` and `g2p_payment_g2p_connect`. For end-to-end disbursement testing, also run the `pbms-bridge-dev` profile.

## Database

- DB: `pbmsdb`
- Odoo DB user: `odoo` / `odoo`
- Postgres role also available: `pbmsuser` / `pbmspass`
