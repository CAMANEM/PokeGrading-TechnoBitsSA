-- ================================================================================
-- PokeGrading — Calibrated baseline schema
-- Stores per-(set, finish) calibrated grading baselines.
-- ================================================================================

CREATE TABLE "calibrated_baseline" (
  "id" BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "set_name" varchar NOT NULL,
  "finish" varchar NOT NULL,
  "baseline_version" varchar NOT NULL,
  "description" text,
  "config_json" jsonb NOT NULL,
  "reference_card_count" int NOT NULL DEFAULT 0,
  "average_psa_grade" decimal,
  "psa_grade_std_dev" decimal,
  "quality_score" decimal,
  "calibrated_at" timestamp NOT NULL,
  "registered_by" bigint,
  "active" boolean DEFAULT true,
  "created_at" timestamp NOT NULL DEFAULT NOW(),
  "modified_at" timestamp NOT NULL DEFAULT NOW()
);

-- Unique constraint: one active baseline per (set, finish)
CREATE UNIQUE INDEX ix_calibrated_baseline_identity
  ON calibrated_baseline (LOWER(set_name), LOWER(finish))
  WHERE active = true;

-- Index for quick lookup
CREATE INDEX ix_calibrated_baseline_set_finish
  ON calibrated_baseline (LOWER(set_name), LOWER(finish));

ALTER TABLE "calibrated_baseline" ADD FOREIGN KEY ("registered_by") REFERENCES "admin" ("id") DEFERRABLE INITIALLY IMMEDIATE;
