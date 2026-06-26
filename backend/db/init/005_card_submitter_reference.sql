-- ========================================================================
-- PokeGrading — Link card_submitter to card_reference
-- Adds a foreign key so each submitter card knows which reference card
-- it was matched against during the search step.
-- ========================================================================

ALTER TABLE "card_submitter"
  ADD COLUMN "card_reference_id" bigint;

ALTER TABLE "card_submitter"
  ADD FOREIGN KEY ("card_reference_id") REFERENCES "card_reference" ("id")
  DEFERRABLE INITIALLY IMMEDIATE;
