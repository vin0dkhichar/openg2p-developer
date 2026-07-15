-- SPAR strategy rows (idempotent). Strategy id 5 matches G2P Bridge BANK_FA deconstruct format.
-- See https://docs.openg2p.org/products/spar and g2p-bridge Helm seedData.

INSERT INTO strategy (id, description, strategy_type, construct_strategy, deconstruct_strategy, active, created_at, updated_at)
VALUES
  (1, 'Key Cloak', 'ID',
   'token:{sub}@nationalId',
   '^token:(?P<sub>.[^.]*)@nationalId$',
   true, NOW(), NOW()),
  (2, 'Bank', 'FA',
   'account_number:{account_number}.branch_name:{branch_name}.branch_code:{branch_code}.bank_name:{bank_name}.bank_code:{bank_code}.fa_type:{fa_type}',
   '^account_number:(?P<account_number>.*)\.branch_name:(?P<branch_name>.*)\.branch_code:(?P<branch_code>.*)\.bank_name:(?P<bank_name>.*)\.bank_code:(?P<bank_code>.*)\.fa_type:(?P<fa_type>.*)$',
   true, NOW(), NOW()),
  (5, 'Bank (G2P Bridge)', 'FA',
   'account_number:{account_number}.branch_code:{branch_code}.bank_code:{bank_code}.mobile_number:.email_address:.fa_type:BANK_ACCOUNT',
   '^account_number:(?P<account_number>.*)\.branch_code:(?P<branch_code>.*)\.bank_code:(?P<bank_code>.*)\.mobile_number:(?P<mobile_number>.*)\.email_address:(?P<email_address>.*)\.fa_type:(?P<fa_type>.*)$',
   true, NOW(), NOW())
ON CONFLICT (id) DO NOTHING;
