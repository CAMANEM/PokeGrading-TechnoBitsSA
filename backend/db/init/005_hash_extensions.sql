-- ================================================================================
-- PokeGrading — Extended perceptual hashes (edge + back image)
-- Applied on fresh Docker init after 004_b2b_seed.sql
-- ================================================================================

ALTER TABLE hash_submitter
  ADD COLUMN IF NOT EXISTS edge_hash_hex varchar,
  ADD COLUMN IF NOT EXISTS back_average_hash_hex varchar,
  ADD COLUMN IF NOT EXISTS back_difference_hash_hex varchar,
  ADD COLUMN IF NOT EXISTS back_center_average_hash_hex varchar,
  ADD COLUMN IF NOT EXISTS back_center_difference_hash_hex varchar,
  ADD COLUMN IF NOT EXISTS back_edge_hash_hex varchar;

ALTER TABLE hash_reference
  ADD COLUMN IF NOT EXISTS edge_hash_hex varchar,
  ADD COLUMN IF NOT EXISTS back_average_hash_hex varchar,
  ADD COLUMN IF NOT EXISTS back_difference_hash_hex varchar,
  ADD COLUMN IF NOT EXISTS back_center_average_hash_hex varchar,
  ADD COLUMN IF NOT EXISTS back_center_difference_hash_hex varchar,
  ADD COLUMN IF NOT EXISTS back_edge_hash_hex varchar;
