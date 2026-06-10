-- 0005_recipe_domain down: restore the pre-0005 freeform drinks schema.
-- Structure only — drink/review/preference data from before the migration is
-- not recoverable (this was an accepted pre-launch destructive rebuild).

ALTER TABLE users DROP COLUMN measure_pref;

DROP TABLE user_drink_preferences;
DROP TABLE reviews;
DROP TABLE favourites;
DROP TABLE bar_items;
DROP TABLE recipe_ingredients;
DROP TABLE recipes;
DROP TABLE units;
DROP TABLE ingredients;

DROP TYPE measure_pref;
DROP TYPE unit_kind;
DROP TYPE recipe_source;
DROP TYPE recipe_method;
DROP TYPE ingredient_kind;

-- Recreate the 0001-era tables that 0005 dropped.
CREATE TABLE drinks (
    id                  UUID PRIMARY KEY,
    name                TEXT NOT NULL,
    category            TEXT NOT NULL,
    recipe_ingredients  TEXT[] NOT NULL DEFAULT '{}',
    recipe_instructions TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE reviews (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    drink_id         UUID NOT NULL REFERENCES drinks(id) ON DELETE CASCADE,
    rating           SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment          TEXT,
    impairment_level SMALLINT CHECK (impairment_level BETWEEN 1 AND 5),
    photo_url        TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX reviews_drink_id_idx ON reviews (drink_id);
CREATE INDEX reviews_user_id_idx  ON reviews (user_id);

CREATE TABLE user_drink_preferences (
    user_id    UUID NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    drink_id   UUID NOT NULL REFERENCES drinks(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, drink_id)
);
