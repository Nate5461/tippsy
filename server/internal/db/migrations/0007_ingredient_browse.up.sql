-- 0007_ingredient_browse: support the add-to-bar browse grid and bottle artwork.
--
-- popularity drives the "most common spirits" ordering on the add-to-bar grid
-- (higher = shown first); it is only meaningful for top-level generics.
-- image_url holds bottle/generic artwork, served like recipe images through the
-- existing /uploads + PublicBaseURL pipeline (phased: real art lands later).

ALTER TABLE ingredients ADD COLUMN popularity INTEGER NOT NULL DEFAULT 0;
ALTER TABLE ingredients ADD COLUMN image_url  TEXT;

-- Serves the browse grid: top-level generics, most common first.
CREATE INDEX ingredients_popularity_idx
    ON ingredients (popularity DESC, name)
    WHERE parent_id IS NULL;
