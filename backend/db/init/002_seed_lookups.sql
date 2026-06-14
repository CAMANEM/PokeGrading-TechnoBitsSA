-- ================================================================================
-- PokeGrading — Lookup seed data (required FK targets)
-- ================================================================================

INSERT INTO "language" ("name") VALUES
  ('Español'),
  ('Inglés'),
  ('English'),
  ('Spanish'),
  ('Japanese');

INSERT INTO "country" ("name") VALUES
  ('Spain'),
  ('United States'),
  ('Mexico'),
  ('Argentina'),
  ('Colombia'),
  ('Chile'),
  ('Peru'),
  ('Brazil'),
  ('France'),
  ('Germany'),
  ('United Kingdom'),
  ('Japan');

INSERT INTO "card_type" ("name") VALUES
  ('Normal'),
  ('Fighting'),
  ('Fire'),
  ('Water'),
  ('Grass'),
  ('Electric'),
  ('Psychic'),
  ('Dark'),
  ('Metal'),
  ('Dragon'),
  ('Fairy');

INSERT INTO "rarity" ("name") VALUES
  ('Common'),
  ('Uncommon'),
  ('Rare'),
  ('Holo Rare'),
  ('Ultra Rare'),
  ('Secret Rare');

INSERT INTO "status" ("name") VALUES
  ('pending'),
  ('under_review'),
  ('completed'),
  ('rejected');
