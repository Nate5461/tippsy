-- 0006_log_and_variants: glass catalogue, recipe variants, garnish lines, bare logs.
--
-- Supports the Letterboxd-style log/create flow: a tweaked recipe publishes as
-- a community variant pointing at its original via parent_recipe_id, glass
-- becomes a required pick from a server-managed list, garnish lines render in
-- their own section, and a review without a rating is a valid "I made this" log.

-- Finite, server-managed glass catalogue (extended by future migrations).
CREATE TABLE glass_types (
    slug       TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    sort_order SMALLINT NOT NULL DEFAULT 0
);

INSERT INTO glass_types (slug, name, sort_order) VALUES
    ('rocks',         'Rocks / Old Fashioned', 1),
    ('highball',      'Highball',              2),
    ('collins',       'Collins',               3),
    ('coupe',         'Coupe',                 4),
    ('martini',       'Martini',               5),
    ('nick-and-nora', 'Nick & Nora',           6),
    ('margarita',     'Margarita',             7),
    ('hurricane',     'Hurricane',             8),
    ('tiki',          'Tiki Mug',              9),
    ('copper-mug',    'Copper Mug',            10),
    ('julep-cup',     'Julep Cup',             11),
    ('flute',         'Champagne Flute',       12),
    ('wine',          'Wine Glass',            13),
    ('snifter',       'Snifter',               14),
    ('shot',          'Shot Glass',            15),
    ('punch-cup',     'Punch Cup',             16),
    ('irish-coffee',  'Irish Coffee Mug',      17),
    ('pint',          'Pint Glass',            18);

-- glass: free text -> required slug. The column keeps its name; existing
-- values are normalized and anything unknown falls back to 'rocks'.
UPDATE recipes SET glass = lower(trim(glass));
UPDATE recipes SET glass = 'rocks'
WHERE glass IS NULL OR glass NOT IN (SELECT slug FROM glass_types);
ALTER TABLE recipes ALTER COLUMN glass SET NOT NULL;
ALTER TABLE recipes ADD CONSTRAINT recipes_glass_fkey
    FOREIGN KEY (glass) REFERENCES glass_types(slug);

-- Variant lineage: a community tweak of an existing recipe points at the
-- recipe it was edited from. SET NULL so deleting an original turns its
-- variants into standalone recipes instead of destroying user content.
ALTER TABLE recipes ADD COLUMN parent_recipe_id UUID
    REFERENCES recipes(id) ON DELETE SET NULL;
CREATE INDEX recipes_parent_recipe_idx ON recipes (parent_recipe_id);

-- Garnish lines: rendered in their own sub-section and excluded from ABV math.
ALTER TABLE recipe_ingredients ADD COLUMN is_garnish BOOLEAN NOT NULL DEFAULT false;
UPDATE recipe_ingredients ri SET is_garnish = true
FROM ingredients i WHERE i.id = ri.ingredient_id AND i.kind = 'garnish';

-- Bare logs: "I made this" with no rating. The existing CHECK
-- (rating BETWEEN 1 AND 5) passes NULL, so dropping NOT NULL is sufficient.
ALTER TABLE reviews ALTER COLUMN rating DROP NOT NULL;
