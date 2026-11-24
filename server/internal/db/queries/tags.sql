-- Tags: one shared, free-form pool keyed by a normalized slug. Recipes and menus
-- both reference tags through their respective join tables.

-- Idempotent insert keyed by slug. The no-op DO UPDATE guarantees RETURNING
-- always yields the row (whether freshly inserted or pre-existing), and keeps the
-- original label rather than clobbering it with later casing.
-- name: UpsertTag :one
INSERT INTO tags (id, slug, label)
VALUES ($1, $2, $3)
ON CONFLICT (slug) DO UPDATE SET label = tags.label
RETURNING *;

-- Tag autocomplete: prefix match on slug, plus a looser substring match on label.
-- name: SearchTags :many
SELECT * FROM tags
WHERE slug LIKE @prefix || '%'
   OR label ILIKE '%' || @prefix || '%'
ORDER BY label
LIMIT 20;

-- name: ListRecipeTags :many
SELECT t.* FROM tags t
JOIN recipe_tags rt ON rt.tag_id = t.id
WHERE rt.recipe_id = $1
ORDER BY t.label;

-- name: DeleteRecipeTags :exec
DELETE FROM recipe_tags WHERE recipe_id = $1;

-- name: InsertRecipeTag :exec
INSERT INTO recipe_tags (recipe_id, tag_id) VALUES ($1, $2)
ON CONFLICT DO NOTHING;

-- name: ListMenuTags :many
SELECT t.* FROM tags t
JOIN menu_tags mt ON mt.tag_id = t.id
WHERE mt.menu_id = $1
ORDER BY t.label;

-- name: DeleteMenuTags :exec
DELETE FROM menu_tags WHERE menu_id = $1;

-- name: InsertMenuTag :exec
INSERT INTO menu_tags (menu_id, tag_id) VALUES ($1, $2)
ON CONFLICT DO NOTHING;
