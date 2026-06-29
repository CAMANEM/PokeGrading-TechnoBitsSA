-- ================================================================================
-- PokeGrading — B2B API schema (customers, keys, audit, idempotency, rate limits)
-- ================================================================================

CREATE TABLE "b2b_customer" (
  "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "name" varchar NOT NULL,
  "status" varchar NOT NULL DEFAULT 'active',
  "created_at" timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE "b2b_api_key" (
  "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "customer_id" bigint NOT NULL,
  "key_hash" varchar NOT NULL,
  "label" varchar,
  "status" varchar NOT NULL DEFAULT 'active',
  "created_at" timestamp NOT NULL DEFAULT NOW(),
  "revoked_at" timestamp,
  "grace_period_ends_at" timestamp
);

CREATE TABLE "b2b_consult_audit" (
  "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "api_key_id" bigint NOT NULL,
  "customer_id" bigint NOT NULL,
  "request_id" varchar,
  "ip_address" varchar,
  "card_count" int NOT NULL,
  "api_version" varchar NOT NULL,
  "outcome" varchar NOT NULL,
  "created_at" timestamp NOT NULL DEFAULT NOW()
);

CREATE TABLE "b2b_idempotency" (
  "api_key_id" bigint NOT NULL,
  "request_id" varchar NOT NULL,
  "request_hash" varchar NOT NULL,
  "response_json" jsonb NOT NULL,
  "created_at" timestamp NOT NULL DEFAULT NOW(),
  "expires_at" timestamp NOT NULL,
  PRIMARY KEY ("api_key_id", "request_id")
);

CREATE TABLE "b2b_rate_usage" (
  "api_key_id" bigint NOT NULL,
  "window_key" varchar NOT NULL,
  "cards_consumed" int NOT NULL DEFAULT 0,
  PRIMARY KEY ("api_key_id", "window_key")
);

ALTER TABLE "b2b_api_key"
  ADD FOREIGN KEY ("customer_id") REFERENCES "b2b_customer" ("id")
  DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "b2b_consult_audit"
  ADD FOREIGN KEY ("api_key_id") REFERENCES "b2b_api_key" ("id")
  DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "b2b_consult_audit"
  ADD FOREIGN KEY ("customer_id") REFERENCES "b2b_customer" ("id")
  DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "b2b_idempotency"
  ADD FOREIGN KEY ("api_key_id") REFERENCES "b2b_api_key" ("id")
  DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "b2b_rate_usage"
  ADD FOREIGN KEY ("api_key_id") REFERENCES "b2b_api_key" ("id")
  DEFERRABLE INITIALLY IMMEDIATE;

CREATE INDEX ix_card_reference_identity
  ON card_reference (
    LOWER(set_name),
    card_number,
    LOWER(edition),
    language_id,
    LOWER(finish)
  );

CREATE INDEX ix_b2b_api_key_hash ON b2b_api_key (key_hash);

CREATE INDEX ix_b2b_idempotency_expires ON b2b_idempotency (expires_at);
