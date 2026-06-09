# Configuration seed SQL

This directory holds **configuration seed** data applied by `make extension-setup` / `make extension-seed`.

Start by copying the `meta_data/` tree from an existing extension:

- `../farmer-registry/farmer-extension/src/openg2p_registry_farmer_extension/meta_data/`
- `../national-social-registry/nsr-extension/src/openg2p_registry_nsr_extension/meta_data/`

Then customize register definitions, schemas, tabs, and themes for {{LABEL}}.

The bootstrap includes only `registry-configurations/g2p_registry_configuration.sql` (registry name/logo).
