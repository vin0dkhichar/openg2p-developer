-- PBMS Odoo eligibility SQL uses g2p_register_farmer; Farmer Registry table is g2p_register_farmers.
\c farmer_registry_db
CREATE OR REPLACE VIEW g2p_register_farmer AS SELECT * FROM g2p_register_farmers;
