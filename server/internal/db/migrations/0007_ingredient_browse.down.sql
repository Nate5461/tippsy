-- Revert 0007_ingredient_browse.
DROP INDEX ingredients_popularity_idx;
ALTER TABLE ingredients DROP COLUMN image_url;
ALTER TABLE ingredients DROP COLUMN popularity;
