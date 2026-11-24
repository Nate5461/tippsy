-- Revert 0006_log_and_variants. Bare logs cannot survive a NOT NULL rating,
-- so they are dropped.

DELETE FROM reviews WHERE rating IS NULL;
ALTER TABLE reviews ALTER COLUMN rating SET NOT NULL;

ALTER TABLE recipe_ingredients DROP COLUMN is_garnish;

DROP INDEX recipes_parent_recipe_idx;
ALTER TABLE recipes DROP COLUMN parent_recipe_id;

ALTER TABLE recipes DROP CONSTRAINT recipes_glass_fkey;
ALTER TABLE recipes ALTER COLUMN glass DROP NOT NULL;

DROP TABLE glass_types;
