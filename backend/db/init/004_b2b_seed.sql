-- ================================================================================
-- PokeGrading — B2B dev seed (customer, API key, reference catalog samples)
-- Dev API key plaintext: pk_test_b2b_dev_key
-- SHA-256 hash: c576804fb09db004ef8f59c95a54b7f56bd81ff604bedb80ae6e632d5926ffcb
-- ================================================================================

INSERT INTO "b2b_customer" ("name", "status", "created_at")
VALUES ('PokeVault Test Shop', 'active', NOW());

INSERT INTO "b2b_api_key" (
  "customer_id",
  "key_hash",
  "label",
  "status",
  "created_at"
)
VALUES (
  1,
  'c576804fb09db004ef8f59c95a54b7f56bd81ff604bedb80ae6e632d5926ffcb',
  'dev-test-key',
  'active',
  NOW()
);
/*
-- language_id: 3 = English (canonical EN)
INSERT INTO "card_reference" (
  "set_name",
  "card_number",
  "edition",
  "finish",
  "language_id",
  "display_name",
  "active",
  "soft_delete",
  "registration_date",
  "modification_date"
)
VALUES
  (
    'SVP',
    1,
    'FIRST_EDITION',
    'HOLO',
    3,
    'Pikachu SVP 001',
    true,
    false,
    NOW(),
    NOW()
  ),
  (
    'SVP',
    2,
    'FIRST_EDITION',
    'HOLO',
    3,
    'Charizard SVP 002 Holo',
    true,
    false,
    NOW(),
    NOW()
  ),
  (
    'SVP',
    2,
    'UNLIMITED',
    'NORMAL',
    3,
    'Charizard SVP 002 Normal',
    true,
    false,
    NOW(),
    NOW()
  ),
  (
    'SVP',
    3,
    'FIRST_EDITION',
    'HOLO',
    3,
    'Withdrawn Card',
    false,
    false,
    NOW(),
    NOW()
  );
*/
