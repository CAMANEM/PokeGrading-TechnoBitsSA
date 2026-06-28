-- Migration 006: Add missing seed data for grading pipeline
-- 'unable_to_grade' status + algorithm version '1.0.0'

INSERT INTO "status" ("name") VALUES ('unable_to_grade')
ON CONFLICT DO NOTHING;

INSERT INTO "algorithm" ("version", "release_date") VALUES ('1.0.0', NOW())
ON CONFLICT DO NOTHING;
