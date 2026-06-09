# {{LABEL}}

Product repository for the **{{LABEL}}** Registry Gen2 domain extension.

## Layout

```text
{{PRODUCT_REPO}}/
├── .openg2p-extension.yaml    # Developer Setup manifest (ports, DB names, Keycloak client)
├── docker/                    # Image build specs (staff API, celery, UI, partner API, db-seed)
├── helm/{{HELM_CHART_NAME}}/  # Wrapper chart on openg2p-registry base
└── {{EXTENSION_DIR_NAME}}/
    └── src/{{PYTHON_MODULE}}/
        ├── app.py             # Initializer + migrate hooks
        ├── config.py
        ├── register_domain/   # Models, services, schemas (add as you build)
        └── meta_data/         # Configuration seed SQL for staff portal
```

## Local development (Developer Setup)

From the [openg2p-developer](https://github.com/shibu-narayanan/openg2p-developer) repo:

```bash
make setup
make extension-package NAME={{VARIANT}}   # if not already bootstrapped
make extension-setup NAME={{VARIANT}}     # IAM, AWE, migrate, configuration seed
make extension-run NAME={{VARIANT}}
```

Staff UI: http://localhost:{{UI_PORT}} — login `staff` / `staff`

## Docker images

Build container images from the product repo (mirrors Farmer Registry / NSR layout):

```bash
chmod +x docker/scripts/build.sh
./docker/scripts/build.sh                              # all services
./docker/scripts/build.sh staff-portal-api/develop.txt # single service
```

See `docker/scripts/README.md` for push and multi-arch options.

## Kubernetes (Helm)

```bash
cd helm/{{HELM_CHART_NAME}}
helm dependency update
helm install {{VARIANT}} . --namespace openg2p-{{VARIANT}} --create-namespace
```

## Next steps

1. Add register definitions and UI metadata under `meta_data/` (copy from `farmer-extension` or `nsr-extension` as a starting point).
2. Add SQLAlchemy models and domain services under `register_domain/`.
3. Register migrations in `app.py` → `migrate_database()`.
4. Re-run `make extension-setup NAME={{VARIANT}}` after schema changes, or `make extension-migrate NAME={{VARIANT}}`.

## References

- [OpenG2P Registry documentation](https://docs.openg2p.org/products/registry)
- [Registry Gen2 platform](https://github.com/OpenG2P/registry-platform)
