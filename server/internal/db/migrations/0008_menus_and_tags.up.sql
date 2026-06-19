-- 0008_menus_and_tags: user-created menus (lists of cocktails) and a shared,
-- free-form tag pool attached to both recipes and menus.
--
-- "Menus" are the user-facing "list" primitive (public or private). This is a
-- different concept from the computed makeable-from-bar feature, which now lives
-- at /users/{id}/makeable.
-- Tags are normalized to a lowercase slug (one shared pool) so a search like
-- "summer" can surface both cocktails and menus through the same vocabulary.

CREATE TYPE menu_visibility AS ENUM ('public', 'private');

CREATE TABLE menus (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    description TEXT,
    visibility  menu_visibility NOT NULL DEFAULT 'public',
    image_url   TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX menus_user_idx ON menus (user_id, updated_at DESC);

-- Reuse the shared trigger function from 0004 to keep updated_at current.
CREATE TRIGGER menus_set_updated_at
    BEFORE UPDATE ON menus
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- Ordered recipes within a menu (mirrors recipe_ingredients' position pattern).
CREATE TABLE menu_items (
    menu_id   UUID NOT NULL REFERENCES menus(id)   ON DELETE CASCADE,
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    position  SMALLINT NOT NULL,
    note      TEXT,
    PRIMARY KEY (menu_id, recipe_id)
);
CREATE INDEX menu_items_menu_idx ON menu_items (menu_id, position);

-- Shared, free-form tag pool. slug is the normalized key; label keeps the
-- first-seen display casing.
CREATE TABLE tags (
    id         UUID PRIMARY KEY,
    slug       TEXT NOT NULL UNIQUE,
    label      TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE recipe_tags (
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    tag_id    UUID NOT NULL REFERENCES tags(id)    ON DELETE CASCADE,
    PRIMARY KEY (recipe_id, tag_id)
);
CREATE INDEX recipe_tags_tag_idx ON recipe_tags (tag_id);

CREATE TABLE menu_tags (
    menu_id UUID NOT NULL REFERENCES menus(id) ON DELETE CASCADE,
    tag_id  UUID NOT NULL REFERENCES tags(id)  ON DELETE CASCADE,
    PRIMARY KEY (menu_id, tag_id)
);
CREATE INDEX menu_tags_tag_idx ON menu_tags (tag_id);
