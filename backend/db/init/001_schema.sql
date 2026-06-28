-- ================================================================================
-- PokeGrading — PostgreSQL schema (primary metadata store)
-- Applied automatically on first Docker volume init via backend/db/init/
-- ================================================================================

CREATE TABLE "country" (
  "id" SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "name" varchar NOT NULL
);

CREATE TABLE "language" (
  "id" SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "name" varchar NOT NULL
);

CREATE TABLE "card_type" (
  "id" SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "name" varchar NOT NULL
);

CREATE TABLE "rarity" (
  "id" SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "name" varchar NOT NULL
);

CREATE TABLE "status" (
  "id" SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "name" varchar NOT NULL
);

CREATE TABLE "algorithm" (
  "version" varchar PRIMARY KEY,
  "global_precision" decimal,
  "release_date" timestamp
);

CREATE TABLE "submitter" (
  "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "username" varchar UNIQUE NOT NULL,
  "password_hash" varchar NOT NULL,
  "email" varchar UNIQUE NOT NULL,
  "country_id" smallint,
  "language_id" smallint,
  "registration_date" timestamp
);

CREATE TABLE "reviewer" (
  "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "username" varchar UNIQUE NOT NULL,
  "password_hash" varchar NOT NULL,
  "email" varchar UNIQUE NOT NULL,
  "country_id" smallint,
  "language_id" smallint,
  "registration_date" timestamp
);

CREATE TABLE "admin" (
  "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "username" varchar UNIQUE NOT NULL,
  "password_hash" varchar NOT NULL,
  "email" varchar UNIQUE NOT NULL,
  "country_id" smallint,
  "language_id" smallint,
  "registration_date" timestamp
);

CREATE TABLE "card_submitter" (
  "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "submitter_id" bigint NOT NULL,
  "hash_id" bigint,
  "card_reference_id" bigint,
  "img_id" BIGINT GENERATED ALWAYS AS IDENTITY,
  "display_name" varchar,
  "set_name" varchar,
  "card_number" int,
  "edition" varchar,
  "finish" varchar,
  "illustrator" varchar,
  "year" smallint,
  "hp" smallint,
  "language_id" smallint,
  "type_id" smallint,
  "rarity_id" smallint,
  "registration_date" timestamp,
  "modification_date" timestamp,
  "version" smallint,
  "active" boolean DEFAULT true
);

-- Perceptual hashes are color-aware: per-channel (R, G, B) 64-bit hashes
-- concatenated into a single 192-bit value rendered as 48 hex chars.
CREATE TABLE "hash_submitter" (
  "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "average_hash_hex" varchar(48),
  "difference_hash_hex" varchar(48),
  "center_average_hash_hex" varchar(48),
  "center_difference_hash_hex" varchar(48),
  "date" timestamp
);

CREATE TABLE "card_reference" (
  "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "responsible_id" bigint,
  "hash_id" bigint,
  "img_id" BIGINT GENERATED ALWAYS AS IDENTITY,
  "display_name" varchar,
  "set_name" varchar,
  "card_number" int,
  "edition" varchar,
  "finish" varchar,
  "illustrator" varchar,
  "year" smallint,
  "hp" smallint,
  "language_id" smallint,
  "type_id" smallint,
  "rarity_id" smallint,
  "psa_grade" decimal,
  "grading_features_json" jsonb,
  "soft_delete" boolean DEFAULT false,
  "registration_date" timestamp,
  "modification_date" timestamp,
  "version" smallint,
  "active" boolean DEFAULT true
);

-- Perceptual hashes are color-aware: per-channel (R, G, B) 64-bit hashes
-- concatenated into a single 192-bit value rendered as 48 hex chars.
CREATE TABLE "hash_reference" (
  "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "average_hash_hex" varchar(48),
  "difference_hash_hex" varchar(48),
  "center_average_hash_hex" varchar(48),
  "center_difference_hash_hex" varchar(48),
  "date" timestamp
);

CREATE TABLE "pre_grade" (
  "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "card_submitter_id" bigint NOT NULL,
  "reviewer_id" bigint,
  "algorithm_version" varchar,
  "status_id" smallint,
  "centering_grade" decimal,
  "corners_grade" decimal,
  "edges_grade" decimal,
  "surface_grade" decimal,
  "final_estimated_grade" decimal,
  "confidence_score" decimal,
  "explanation" text,
  "manually_reviewed" boolean DEFAULT false,
  "recommend_paid_evaluation" boolean DEFAULT false,
  "log_id" varchar,
  "requested_date" timestamp,
  "graded_date" timestamp,
  "last_modified_date" timestamp
);

ALTER TABLE "submitter" ADD FOREIGN KEY ("country_id") REFERENCES "country" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "submitter" ADD FOREIGN KEY ("language_id") REFERENCES "language" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "reviewer" ADD FOREIGN KEY ("country_id") REFERENCES "country" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "reviewer" ADD FOREIGN KEY ("language_id") REFERENCES "language" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "admin" ADD FOREIGN KEY ("country_id") REFERENCES "country" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "admin" ADD FOREIGN KEY ("language_id") REFERENCES "language" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "card_submitter" ADD FOREIGN KEY ("submitter_id") REFERENCES "submitter" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "card_submitter" ADD FOREIGN KEY ("hash_id") REFERENCES "hash_submitter" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "card_submitter" ADD FOREIGN KEY ("card_reference_id") REFERENCES "card_reference" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "card_submitter" ADD FOREIGN KEY ("language_id") REFERENCES "language" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "card_submitter" ADD FOREIGN KEY ("type_id") REFERENCES "card_type" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "card_submitter" ADD FOREIGN KEY ("rarity_id") REFERENCES "rarity" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "card_reference" ADD FOREIGN KEY ("responsible_id") REFERENCES "admin" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "card_reference" ADD FOREIGN KEY ("hash_id") REFERENCES "hash_reference" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "card_reference" ADD FOREIGN KEY ("language_id") REFERENCES "language" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "card_reference" ADD FOREIGN KEY ("type_id") REFERENCES "card_type" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "card_reference" ADD FOREIGN KEY ("rarity_id") REFERENCES "rarity" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "pre_grade" ADD FOREIGN KEY ("card_submitter_id") REFERENCES "card_submitter" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "pre_grade" ADD FOREIGN KEY ("reviewer_id") REFERENCES "reviewer" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "pre_grade" ADD FOREIGN KEY ("algorithm_version") REFERENCES "algorithm" ("version") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "pre_grade" ADD FOREIGN KEY ("status_id") REFERENCES "status" ("id") DEFERRABLE INITIALLY IMMEDIATE;

CREATE INDEX ix_card_submitter_identity
  ON card_submitter (LOWER(set_name), card_number, LOWER(edition), language_id, LOWER(finish));
