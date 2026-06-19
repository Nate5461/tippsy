-- Menus: user-created lists of cocktails (public or private). Distinct from the
-- computed makeable-from-bar feature (see makeable.sql).
--
-- recipe_count and tag arrays come from correlated subqueries (each COALESCEd to
-- a non-null value) so they compose cleanly without join fan-out.

-- name: CreateMenu :one
INSERT INTO menus (id, user_id, name, description, visibility, image_url)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- Only the owner may edit. A miss (wrong owner or unknown id) returns zero rows,
-- which the handler treats as "not found", mirroring UpdateRecipe.
-- name: UpdateMenu :one
UPDATE menus
SET name        = @name,
    description = @description,
    visibility  = @visibility,
    image_url   = @image_url
WHERE id = @id AND user_id = @user_id
RETURNING *;

-- name: DeleteMenu :execrows
DELETE FROM menus WHERE id = @id AND user_id = @user_id;

-- name: GetMenuByID :one
SELECT m.*, u.username AS author_name,
       COALESCE((SELECT COUNT(*) FROM menu_items mi WHERE mi.menu_id = m.id), 0)::bigint AS recipe_count,
       COALESCE((SELECT array_agg(t.slug  ORDER BY t.label)
                 FROM menu_tags mt JOIN tags t ON t.id = mt.tag_id
                 WHERE mt.menu_id = m.id), ARRAY[]::text[]) AS tag_slugs,
       COALESCE((SELECT array_agg(t.label ORDER BY t.label)
                 FROM menu_tags mt JOIN tags t ON t.id = mt.tag_id
                 WHERE mt.menu_id = m.id), ARRAY[]::text[]) AS tag_labels
FROM menus m
JOIN users u ON u.id = m.user_id
WHERE m.id = $1;

-- A user's own menus. include_private is true only when the viewer is the owner;
-- otherwise only the public ones are returned.
-- name: ListMenusByUser :many
SELECT m.*, u.username AS author_name,
       COALESCE((SELECT COUNT(*) FROM menu_items mi WHERE mi.menu_id = m.id), 0)::bigint AS recipe_count,
       COALESCE((SELECT array_agg(t.slug  ORDER BY t.label)
                 FROM menu_tags mt JOIN tags t ON t.id = mt.tag_id
                 WHERE mt.menu_id = m.id), ARRAY[]::text[]) AS tag_slugs,
       COALESCE((SELECT array_agg(t.label ORDER BY t.label)
                 FROM menu_tags mt JOIN tags t ON t.id = mt.tag_id
                 WHERE mt.menu_id = m.id), ARRAY[]::text[]) AS tag_labels
FROM menus m
JOIN users u ON u.id = m.user_id
WHERE m.user_id = @owner
  AND (sqlc.arg('include_private')::bool OR m.visibility = 'public')
ORDER BY m.updated_at DESC;

-- Public-menu discovery: full-text + fuzzy (pg_trgm) + tag match, same shape as
-- SearchRecipes. An empty query ranks everything 0 and falls back to recency.
-- name: SearchMenus :many
SELECT m.*, u.username AS author_name,
       COALESCE((SELECT COUNT(*) FROM menu_items mi WHERE mi.menu_id = m.id), 0)::bigint AS recipe_count,
       COALESCE((SELECT array_agg(t.slug  ORDER BY t.label)
                 FROM menu_tags mt JOIN tags t ON t.id = mt.tag_id
                 WHERE mt.menu_id = m.id), ARRAY[]::text[]) AS tag_slugs,
       COALESCE((SELECT array_agg(t.label ORDER BY t.label)
                 FROM menu_tags mt JOIN tags t ON t.id = mt.tag_id
                 WHERE mt.menu_id = m.id), ARRAY[]::text[]) AS tag_labels,
       COALESCE(
         CASE WHEN @query::text = '' THEN 0
              ELSE ts_rank(
                     setweight(to_tsvector('english', m.name), 'A') ||
                     setweight(to_tsvector('english', coalesce(m.description, '')), 'B'),
                     websearch_to_tsquery('english', @query::text))
                   + similarity(m.name, @query::text)
         END, 0)::float8 AS rank
FROM menus m
JOIN users u ON u.id = m.user_id
WHERE m.visibility = 'public'
  AND (
        @query::text = ''
        OR to_tsvector('english', m.name || ' ' || coalesce(m.description, '')) @@ websearch_to_tsquery('english', @query::text)
        OR m.name % @query::text
        OR EXISTS (SELECT 1 FROM menu_tags mt2 JOIN tags t2 ON t2.id = mt2.tag_id
                   WHERE mt2.menu_id = m.id AND (t2.slug = @query::text OR t2.label ILIKE '%' || @query::text || '%'))
      )
  AND (sqlc.narg('tag')::text IS NULL OR EXISTS (
          SELECT 1 FROM menu_tags mt3 JOIN tags t3 ON t3.id = mt3.tag_id
          WHERE mt3.menu_id = m.id AND t3.slug = sqlc.narg('tag')))
ORDER BY rank DESC, recipe_count DESC, m.updated_at DESC
LIMIT sqlc.arg('lim');

-- Recipes in a menu, in display order. Same recipe summary columns as the other
-- recipe list queries, plus the line's position and note.
-- name: ListMenuItems :many
SELECT r.*, u.username AS author_name, g.name AS glass_name, pr.name AS parent_recipe_name,
       COALESCE(AVG(rv.rating), 0)::float8 AS average_rating,
       COUNT(rv.id)                        AS total_reviews,
       mi.position, mi.note
FROM menu_items mi
JOIN recipes r       ON r.id = mi.recipe_id
JOIN glass_types g   ON g.slug = r.glass
LEFT JOIN users u    ON u.id = r.author_id
LEFT JOIN recipes pr ON pr.id = r.parent_recipe_id
LEFT JOIN reviews rv ON rv.recipe_id = r.id
WHERE mi.menu_id = $1
GROUP BY r.id, u.username, g.name, pr.name, mi.position, mi.note
ORDER BY mi.position;

-- Full replace path (used on menu update): clear then re-insert with positions.
-- name: DeleteMenuItems :exec
DELETE FROM menu_items WHERE menu_id = $1;

-- name: InsertMenuItem :exec
INSERT INTO menu_items (menu_id, recipe_id, position, note)
VALUES ($1, $2, $3, $4)
ON CONFLICT (menu_id, recipe_id) DO UPDATE SET position = EXCLUDED.position, note = EXCLUDED.note;

-- Append a single recipe to the end of a menu (POST /menus/{id}/items).
-- name: AddMenuItem :exec
INSERT INTO menu_items (menu_id, recipe_id, position, note)
VALUES (
    @menu_id, @recipe_id,
    COALESCE((SELECT MAX(position) + 1 FROM menu_items WHERE menu_id = @menu_id), 0),
    @note
)
ON CONFLICT (menu_id, recipe_id) DO UPDATE SET note = EXCLUDED.note;

-- name: DeleteMenuItem :execrows
DELETE FROM menu_items WHERE menu_id = @menu_id AND recipe_id = @recipe_id;
