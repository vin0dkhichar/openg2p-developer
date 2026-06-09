# {{PIP_NAME}}

Python extension package for **{{LABEL}}** on the OpenG2P Registry Gen2 platform.

Installed into the shared staff portal API and Celery venvs as `openg2p_registry_extensions`.

## Develop

```bash
# From openg2p-developer after make extension-setup NAME={{VARIANT}}
make extension-run NAME={{VARIANT}}
```

Add domain code under `src/{{PYTHON_MODULE}}/register_domain/` and configuration SQL under `src/{{PYTHON_MODULE}}/meta_data/`.
