-- 0005_recipe_domain: rebuild the drink domain around structured recipes.
--
-- Pre-launch destructive rebuild: drops the freeform drinks table (and the
-- reviews/preferences rows hanging off it) and recreates the domain as
-- ingredients + measured recipe lines. This unlocks bar inventory matching
-- ("what can I make"), computed strength, and metric/imperial display.

DROP TABLE reviews;
DROP TABLE user_drink_preferences;
DROP TABLE drinks;

CREATE TYPE ingredient_kind AS ENUM ('spirit','liqueur','fortified_wine','wine','beer_cider',
    'bitters','juice','syrup','soda_mixer','dairy_egg','fruit','herb_spice','garnish','other');
CREATE TYPE recipe_method  AS ENUM ('shaken','stirred','built','blended','other');
CREATE TYPE recipe_source  AS ENUM ('official','community');
CREATE TYPE unit_kind      AS ENUM ('volume','count');
CREATE TYPE measure_pref   AS ENUM ('metric','imperial');

-- One table for the whole catalogue: generics, styles, and brands form a
-- hierarchy via parent_id (vodka <- citrus vodka <- Grey Goose Citron).
-- Recipes may reference any level; bar matching walks up the tree.
CREATE TABLE ingredients (
    id          UUID PRIMARY KEY,
    name        TEXT NOT NULL,
    kind        ingredient_kind NOT NULL,
    parent_id   UUID REFERENCES ingredients(id) ON DELETE SET NULL,
    abv         DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (abv >= 0 AND abv <= 100),
    description TEXT,
    created_by  UUID REFERENCES users(id) ON DELETE SET NULL, -- NULL = official catalogue
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Official names are globally unique; custom (user-created) names unique per creator.
CREATE UNIQUE INDEX ingredients_official_name_key ON ingredients (lower(name)) WHERE created_by IS NULL;
CREATE UNIQUE INDEX ingredients_custom_name_key   ON ingredients (created_by, lower(name)) WHERE created_by IS NOT NULL;
CREATE INDEX ingredients_parent_idx ON ingredients (parent_id);

-- Fixed measure vocabulary. Volume units carry a bartending ml equivalent
-- (1 oz = 30 ml by convention, not 29.57); count units (wedge, leaf, ...) do not.
CREATE TABLE units (
    code     TEXT PRIMARY KEY,
    name     TEXT NOT NULL,
    abbrev   TEXT NOT NULL,
    kind     unit_kind NOT NULL,
    ml_equiv DOUBLE PRECISION CHECK (ml_equiv IS NULL OR ml_equiv > 0)
);

INSERT INTO units (code, name, abbrev, kind, ml_equiv) VALUES
    ('ml',       'millilitre',  'ml',       'volume', 1),
    ('cl',       'centilitre',  'cl',       'volume', 10),
    ('oz',       'ounce',       'oz',       'volume', 30),
    ('tsp',      'teaspoon',    'tsp',      'volume', 5),
    ('tbsp',     'tablespoon',  'tbsp',     'volume', 15),
    ('barspoon', 'barspoon',    'barspoon', 'volume', 5),
    ('dash',     'dash',        'dash',     'volume', 0.9),
    ('drop',     'drop',        'drop',     'volume', 0.05),
    ('splash',   'splash',      'splash',   'volume', 15),
    ('top',      'top up',      'top',      'volume', 90), -- nominal volume for strength estimates
    ('piece',    'piece',       'pc',       'count',  NULL),
    ('slice',    'slice',       'slice',    'count',  NULL),
    ('wedge',    'wedge',       'wedge',    'count',  NULL),
    ('twist',    'twist',       'twist',    'count',  NULL),
    ('leaf',     'leaf',        'leaf',     'count',  NULL),
    ('sprig',    'sprig',       'sprig',    'count',  NULL),
    ('pinch',    'pinch',       'pinch',    'count',  NULL),
    ('cube',     'cube',        'cube',     'count',  NULL),
    ('rim',      'rim',         'rim',      'count',  NULL);

CREATE TABLE recipes (
    id           UUID PRIMARY KEY,
    slug         TEXT NOT NULL UNIQUE,                 -- importer idempotency key
    name         TEXT NOT NULL,
    description  TEXT,
    instructions TEXT,
    method       recipe_method NOT NULL DEFAULT 'stirred',
    glass        TEXT,
    source       recipe_source NOT NULL DEFAULT 'community',
    author_id    UUID REFERENCES users(id) ON DELETE SET NULL, -- NULL = Tippsy official
    attribution  TEXT,                                 -- book / IBA / bar credit
    sweetness    SMALLINT CHECK (sweetness BETWEEN 0 AND 10), -- author-set, 0 = bone dry
    est_abv      DOUBLE PRECISION,                     -- computed on write; NULL if unknowable
    image_url    TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX recipes_source_idx ON recipes (source);
CREATE INDEX recipes_author_idx ON recipes (author_id);

-- Reuses set_updated_at() from migration 0004.
CREATE TRIGGER recipes_set_updated_at
    BEFORE UPDATE ON recipes
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TABLE recipe_ingredients (
    recipe_id     UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    position      SMALLINT NOT NULL,
    ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
    amount        DOUBLE PRECISION CHECK (amount IS NULL OR amount > 0), -- NULL = "to taste"/unmeasured
    unit_code     TEXT REFERENCES units(code),
    note          TEXT,                                -- "freshly squeezed"
    is_optional   BOOLEAN NOT NULL DEFAULT false,      -- excluded from makeable matching
    PRIMARY KEY (recipe_id, position)
);
CREATE INDEX recipe_ingredients_ingredient_idx ON recipe_ingredients (ingredient_id);

CREATE TABLE bar_items (
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ingredient_id UUID NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, ingredient_id)
);

CREATE TABLE favourites (
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recipe_id  UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, recipe_id)
);

-- Reviews come back identical except they now point at recipes.
CREATE TABLE reviews (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
    recipe_id        UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    rating           SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment          TEXT,
    impairment_level SMALLINT CHECK (impairment_level BETWEEN 1 AND 5),
    photo_url        TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX reviews_recipe_id_idx ON reviews (recipe_id);
CREATE INDEX reviews_user_id_idx   ON reviews (user_id);

CREATE TABLE user_drink_preferences (
    user_id    UUID NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
    recipe_id  UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, recipe_id)
);

-- How measures are rendered for this user (45 ml vs 1.5 oz).
ALTER TABLE users ADD COLUMN measure_pref measure_pref NOT NULL DEFAULT 'metric';
