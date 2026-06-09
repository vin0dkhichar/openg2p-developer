categories:
  - Social Protection
  - OpenG2P

labels:
  io.cattle.field/appName: OpenG2P {{LABEL}}

questions:

  - variable: openg2p-registry.global.registryHostname
    description: |
      Base hostname under which all {{LABEL}} services are exposed.
      Default (auto-computed): "<release-name>.<namespace>.openg2p.org".
    type: string
    label: Registry Hostname
    group: General

  - variable: openg2p-registry.global.postgresqlHost
    description: PostgreSQL server host (cluster-internal service name)
    type: string
    label: PostgreSQL Server Host
    group: General

  - variable: openg2p-registry.global.keycloakBaseUrl
    description: Keycloak Base URL used by all components for OIDC
    type: string
    label: Keycloak Base URL
    group: General

  - variable: openg2p-registry.staffPortalApi.enabled
    description: Install Staff Portal API
    type: boolean
    label: Staff Portal API
    group: General

  - variable: openg2p-registry.staffPortalUi.enabled
    description: Install Staff Portal UI
    type: boolean
    label: Staff Portal UI
    group: General

  - variable: openg2p-registry.partnerApi.enabled
    description: Install Partner API
    type: boolean
    label: Partner API
    group: General

  - variable: openg2p-registry.dbSeed.enabled
    description: Run DB seed Job (register definitions, schemas, tabs, registry config)
    type: boolean
    label: Enable DB Seed
    group: DB Seed

  - variable: openg2p-registry.dbSeed.loadSampleData
    description: Also insert demo registrant rows from extension sample_data/ (dev/test only)
    type: boolean
    label: Load Sample Data
    group: DB Seed

  - variable: openg2p-registry.staffPortalApi.image.repository
    description: Docker image repository for Staff Portal API
    type: string
    label: Staff Portal API Image Repository
    group: Images

  - variable: openg2p-registry.staffPortalApi.image.tag
    description: Docker image tag for Staff Portal API
    type: string
    label: Staff Portal API Image Tag
    group: Images

  - variable: openg2p-registry.dbSeed.image.repository
    description: Docker image repository for the DB seed container
    type: string
    label: DB Seed Image Repository
    group: DB Seed

  - variable: openg2p-registry.dbSeed.image.tag
    description: Docker image tag for the DB seed container
    type: string
    label: DB Seed Image Tag
    group: DB Seed
