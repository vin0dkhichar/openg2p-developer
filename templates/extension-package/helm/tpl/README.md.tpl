# {{HELM_CHART_NAME}}

Thin wrapper Helm chart for the **OpenG2P {{LABEL}}**.

This chart depends on the OpenG2P Registry Gen 2 base chart (`openg2p-registry`)
and supplies only {{LABEL}}-specific overrides:

1. Docker image names for the registry components
2. ID Generator `idTypes` starter map (customize in `values.yaml`)

## Installing (from this repo)

```bash
cd helm/{{HELM_CHART_NAME}}
helm dependency update
helm install {{VARIANT}} . \
  --namespace openg2p-{{VARIANT}} \
  --create-namespace
```

## Building images first

From the product repo root:

```bash
chmod +x docker/scripts/build.sh
./docker/scripts/build.sh staff-portal-api/develop.txt
./docker/scripts/build.sh --push all   # requires docker/scripts/.env credentials
```

## Sample data (dev/test)

```bash
helm install {{VARIANT}} . \
  --set openg2p-registry.dbSeed.loadSampleData=true
```

Customize register metadata in `{{EXTENSION_DIR_NAME}}/src/{{PYTHON_MODULE}}/meta_data/` before production installs.
