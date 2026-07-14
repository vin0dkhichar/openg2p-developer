[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "{{PIP_NAME}}"
description = "OpenG2P Registry {{LABEL}} Extension"
readme = "README.md"
requires-python = ">=3.10"
license = { text = "MPL-2.0" }

authors = [
  { name = "OpenG2P", email = "info@openg2p.org" },
]

classifiers = [
  "Programming Language :: Python :: 3",
  "License :: OSI Approved :: Mozilla Public License 2.0 (MPL 2.0)",
  "Operating System :: OS Independent",
]

dependencies = [
  "openg2p-fastapi-common >=1.1.7",
  "openg2p-g2pconnect-common-lib >=1.1.0",
]

dynamic = ["version"]

[project.urls]
Homepage = "https://openg2p.org"
Documentation = "https://docs.openg2p.org/"
Repository = "https://github.com/OpenG2P/openg2p-registry-extension"

[tool.hatch.version]
path = "src/{{PYTHON_MODULE}}/__init__.py"

[tool.hatch.build.targets.wheel.sources]
"src/{{PYTHON_MODULE}}" = "openg2p_registry_extensions"
