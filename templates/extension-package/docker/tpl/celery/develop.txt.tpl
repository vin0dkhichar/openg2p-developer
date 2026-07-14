#!openg2p/openg2p-{{VARIANT}}-celery:develop

# Dependencies
git://v1.1.7//https://github.com/openg2p/openg2p-fastapi-common#subdirectory=openg2p-fastapi-common
git://v1.1.7//https://github.com/openg2p/openg2p-fastapi-common#subdirectory=openg2p-fastapi-auth
git://develop//https://github.com/openg2p/registry-platform#subdirectory=core/openg2p-registry-core

# Celery components
git://develop//https://github.com/openg2p/registry-platform#subdirectory=celery/openg2p-registry-celery-beat-producers
git://develop//https://github.com/openg2p/registry-platform#subdirectory=celery/openg2p-registry-celery-workers

# Domain specific
git://develop//https://github.com/openg2p/iam-service#subdirectory=iam-core

# {{LABEL}} extension — built from this repo's working tree (copied into local_deps/ by parse_service.py).
./{{EXTENSION_DIR_NAME}}
