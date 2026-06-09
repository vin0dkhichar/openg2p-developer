#!openg2p/openg2p-{{VARIANT}}-staff-portal-api:develop

# {{LABEL}} extension — built from this repo's working tree (copied into local_deps/ by parse_service.py).
./{{EXTENSION_DIR_NAME}}

# Dependencies libs
git://v1.1.6//https://github.com/openg2p/openg2p-fastapi-common#subdirectory=openg2p-fastapi-common
git://v1.1.6//https://github.com/openg2p/openg2p-fastapi-common#subdirectory=openg2p-fastapi-auth

# Core
git://develop//https://github.com/openg2p/openg2p-iam-service#subdirectory=iam-core
git://develop//https://github.com/openg2p/openg2p-registry-gen2-core#subdirectory=openg2p-registry-core
git://develop//https://github.com/openg2p/openg2p-registry-gen2-apis#subdirectory=openg2p-registry-staff-portal-api
