-- Shared roles and databases for OpenG2P local development.
-- Runs once on first Postgres container start.

-- Odoo shared role (PBMS + Social Registry native dev)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'odoo') THEN
    CREATE ROLE odoo WITH LOGIN PASSWORD 'odoo' CREATEDB;
  END IF;
END
$$;

-- PBMS
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'pbmsuser') THEN
    CREATE ROLE pbmsuser WITH LOGIN PASSWORD 'pbmspass' CREATEDB;
  END IF;
END
$$;

SELECT 'CREATE DATABASE pbmsdb OWNER pbmsuser'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'pbmsdb')\gexec

-- Social Registry
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sruser') THEN
    CREATE ROLE sruser WITH LOGIN PASSWORD 'srpass' CREATEDB;
  END IF;
END
$$;

SELECT 'CREATE DATABASE socialregistrydb OWNER sruser'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'socialregistrydb')\gexec

-- Registry Gen2
SELECT 'CREATE DATABASE registry_db OWNER postgres'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'registry_db')\gexec

SELECT 'CREATE DATABASE openg2p_gen2_master_data_db OWNER postgres'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'openg2p_gen2_master_data_db')\gexec

SELECT 'CREATE DATABASE masterdatadb OWNER postgres'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'masterdatadb')\gexec

-- G2P Bridge
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'bridgeuser') THEN
    CREATE ROLE bridgeuser WITH LOGIN PASSWORD 'bridgepass' CREATEDB;
  END IF;
END
$$;

SELECT 'CREATE DATABASE g2pbridgedb OWNER bridgeuser'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'g2pbridgedb')\gexec

SELECT 'CREATE DATABASE examplebankdb OWNER bridgeuser'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'examplebankdb')\gexec

-- SPAR
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sparuser') THEN
    CREATE ROLE sparuser WITH LOGIN PASSWORD 'password' CREATEDB;
  END IF;
END
$$;

SELECT 'CREATE DATABASE spardb OWNER sparuser'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'spardb')\gexec
