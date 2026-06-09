apiVersion: v2
name: {{HELM_CHART_NAME}}
description: |
  OpenG2P {{LABEL}} — thin wrapper chart on top of the OpenG2P Registry
  Gen 2 base chart. Supplies {{LABEL}}-branded Docker images and
  extension-specific ID-generator configuration; all infrastructure,
  templates and defaults come from the base chart.
type: application

version: 0.0.0-develop
appVersion: "develop"

keywords:
  - openg2p
  - {{VARIANT}}
  - registry

home: https://openg2p.org
icon: https://openg2p.github.io/openg2p-helm/openg2p-logo.png
sources:
  - https://github.com/OpenG2P/{{PRODUCT_REPO}}
maintainers:
  - name: OpenG2P
    email: info@openg2p.org

dependencies:
  - name: openg2p-registry
    version: 0.0.0-develop
    repository: https://openg2p.github.io/openg2p-helm

annotations:
  catalog.cattle.io/display-name: "OpenG2P {{LABEL}}"
  catalog.cattle.io/release-name: {{HELM_CHART_NAME}}
  catalog.cattle.io/certified: partner
  catalog.cattle.io/kube-version: ">=1.23.0-0"
  openg2p.org/add-to-rancher: ""
