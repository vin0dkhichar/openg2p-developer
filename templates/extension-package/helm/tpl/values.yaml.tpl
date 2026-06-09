# ---------------------------------------------------------------------------
# {{HELM_CHART_NAME}} — values.yaml
#
# Only {{LABEL}}-specific overrides live here. Everything else is inherited
# from the base chart `openg2p-registry` (see Chart.yaml → dependencies).
# ---------------------------------------------------------------------------

openg2p-registry:

  global:
    registryVariant: '{{VARIANT}}'

  staffPortalApi:
    image:
      repository: openg2p/openg2p-{{VARIANT}}-staff-portal-api
      tag: "develop"
      pullPolicy: Always

  partnerApi:
    image:
      repository: openg2p/openg2p-{{VARIANT}}-partner-api
      tag: "develop"
      pullPolicy: Always

  staffPortalUi:
    image:
      repository: openg2p/openg2p-{{VARIANT}}-staff-portal-ui
      tag: "develop"
      pullPolicy: Always

  celeryBeatProducer:
    image:
      repository: openg2p/openg2p-{{VARIANT}}-celery
      tag: "develop"
      pullPolicy: Always

  celeryWorker:
    image:
      repository: openg2p/openg2p-{{VARIANT}}-celery
      tag: "develop"
      pullPolicy: Always

  dbSeed:
    image:
      repository: openg2p/openg2p-{{VARIANT}}-db-seed
      tag: "develop"
      pullPolicy: Always

  idgenerator:
    idGenerator:
      appConfig:
        idTypes:
          {{VARIANT_TOKEN}}:
            idLength: 12
