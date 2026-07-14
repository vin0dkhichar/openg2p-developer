-- Minimal geo tables for local dev sample seeding (load_geo_data.py).
-- Production uses the commons master-data service schema.

CREATE TABLE IF NOT EXISTS g2p_geo_levels (
    level_id VARCHAR PRIMARY KEY,
    level_mnemonic VARCHAR NOT NULL,
    parent_level_id VARCHAR
);

CREATE TABLE IF NOT EXISTS g2p_geo_level_values (
    level_value_id VARCHAR PRIMARY KEY,
    level_id VARCHAR NOT NULL,
    level_value_mnemonic VARCHAR NOT NULL,
    parent_level_value_id VARCHAR
);
