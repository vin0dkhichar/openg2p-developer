# Custom Registry Gen2 extension development

Use this profile when building a **new** domain registry (like Farmer Registry or NSR) from an empty extension scaffold.

## Prerequisites

Complete [Prerequisites](../docs/prerequisites.md), then:

```bash
cp .env.example .env
make setup
make infra-up
```

## Bootstrap a new extension product

One command (non-interactive):

```bash
make extension-package NAME=disability-registry
```

Interactive (prompts for slug and optional git URL):

```bash
make extension-package
```

Clone an empty GitHub repo instead of creating locally:

```bash
make extension-package NAME=disability-registry REPO_URL=https://github.com/you/disability-registry.git
```

Scaffold + full IAM/AWE/migrate/seed in one go:

```bash
make extension-package NAME=disability-registry SETUP=1
```

## What gets created

Under `../openg2p-workspace/disability-registry/` (example):

```text
disability-registry/
├── .openg2p-extension.yaml
├── README.md
├── docker/                         # staff API, celery, UI, partner API, db-seed
│   ├── staff-portal-api/
│   ├── celery/
│   ├── partner-api/
│   ├── staff-portal-ui/
│   ├── db-seed/
│   ├── scripts/build.sh            # local image build (same model as FR/NSR)
│   └── local_deps/
├── helm/openg2p-disability-registry/   # wrapper on openg2p-registry base chart
└── disability-extension/
    └── src/openg2p_registry_disability_extension/
        ├── app.py
        ├── register_domain/
        └── meta_data/
```

Naming rules (from `disability-registry`):

| Item | Example |
|------|---------|
| Extension folder | `disability-extension` |
| Python module | `openg2p_registry_disability_extension` |
| Postgres DBs | `disability_registry_db`, `disability_master_data_db` |
| Docker images | `openg2p/openg2p-disability-registry-staff-portal-api:develop`, etc. |
| Helm chart | `helm/openg2p-disability-registry/` |
| Keycloak client | `disability-registry-staff-portal` |
| Default ports | API `8041`, UI `3020` (auto-increment if taken) |

## Local native development

```bash
make extension-setup NAME=disability-registry   # once: IAM, AWE, migrate, seed
make extension-run NAME=disability-registry
```

Staff UI uses the shared `openg2p-registry-gen2-staff-portal-ui` repo with a generated env file on your extension's UI port.

Login: `staff` / `staff` (after Keycloak init — re-run `make infra-up` if you added the extension after infra was first started).

## Docker images

From the product repo root:

```bash
chmod +x docker/scripts/build.sh
./docker/scripts/build.sh                              # all services
./docker/scripts/build.sh staff-portal-api/develop.txt # one service
PUSH=1 ./docker/scripts/build.sh --push staff-portal-api/develop.txt
```

Copy `docker/scripts/.env.example` to `docker/scripts/.env` for Docker Hub credentials when pushing.

The build copies `./disability-extension` into `docker/local_deps/` and produces images such as:

- `openg2p/openg2p-disability-registry-staff-portal-api:develop`
- `openg2p/openg2p-disability-registry-celery:develop`
- `openg2p/openg2p-disability-registry-db-seed:develop`

## Kubernetes (Helm)

```bash
cd ../openg2p-workspace/disability-registry/helm/openg2p-disability-registry
helm dependency update
helm install disability-registry . \
  --namespace openg2p-disability-registry \
  --create-namespace
```

Customize `values.yaml` for image tags, DB seed sample data, and ID generator `idTypes`.

## Develop the extension

1. Copy `meta_data/` from `farmer-extension` or `nsr-extension` as a starting point.
2. Add SQLAlchemy models under `register_domain/models/`.
3. Register `create_migrate()` calls in `app.py`.
4. Re-run `make extension-migrate NAME=...` and `make extension-seed NAME=...`.

Optional sample registrant SQL: add `sample_data/` and run `LOAD_SAMPLE_DATA=true make extension-seed NAME=...`.

## Makefile reference

| Target | Purpose |
|--------|---------|
| `make extension-package NAME=...` | Scaffold product repo + extension + docker + helm |
| `make extension-setup NAME=...` | Full one-time bootstrap (like `nsr-setup`) |
| `make extension-run NAME=...` | Start AWE, IAM, API, Celery, UI |
| `make extension-migrate NAME=...` | Schema only |
| `make extension-seed NAME=...` | Configuration SQL (+ optional sample data) |
| `make extension-init NAME=...` | migrate + seed |

## References

- [Registry Gen2 platform](https://github.com/OpenG2P/registry-platform)
- [Farmer Registry extension](https://github.com/OpenG2P/farmer-registry)
- [National Social Registry extension](https://github.com/OpenG2P/national-social-registry)
