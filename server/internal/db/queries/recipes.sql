-- name: GetRecipeByID :one
SELECT r.*, u.username AS author_name, g.name AS glass_name,
       pr.name AS parent_recipe_name,
       COALESCE(AVG(rv.rating), 0)::float8 AS average_rating,
       COUNT(rv.id)                        AS total_reviews
FROM recipes r
JOIN glass_types g    ON g.slug = r.glass
LEFT JOIN users u     ON u.id = r.author_id
LEFT JOIN recipes pr  ON pr.id = r.parent_recipe_id
LEFT JOIN reviews rv  ON rv.recipe_id = r.id
WHERE r.id = $1
GROUP BY r.id, u.username, g.name, pr.name;

-- Search doubles as the popularity-ranked browse list when the pattern is '%%'.
-- name: SearchRecipes :many
SELECT r.*, u.username AS author_name, g.name AS glass_name,
       pr.name AS parent_recipe_name,
       COALESCE(AVG(rv.rating), 0)::float8 AS average_rating,
       COUNT(rv.id)                        AS total_reviews
FROM recipes r
JOIN glass_types g    ON g.slug = r.glass
LEFT JOIN users u     ON u.id = r.author_id
LEFT JOIN recipes pr  ON pr.id = r.parent_recipe_id
LEFT JOIN reviews rv  ON rv.recipe_id = r.id
WHERE r.name ILIKE @pattern
  AND (sqlc.narg('source')::recipe_source IS NULL OR r.source = sqlc.narg('source'))
  AND (sqlc.narg('max_abv')::float8 IS NULL OR r.est_abv <= sqlc.narg('max_abv'))
GROUP BY r.id, u.username, g.name, pr.name
ORDER BY total_reviews DESC, average_rating DESC, r.name
LIMIT 100;

-- name: CreateRecipe :one
INSERT INTO recipes (id, slug, name, description, instructions, method, glass,
                     source, author_id, attribution, sweetness, est_abv, image_url,
                     parent_recipe_id)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
RETURNING *;

-- Only the author may edit, and only community recipes are editable via the API
-- (official ones are managed by the seeder).
-- name: UpdateRecipe :one
UPDATE recipes
SET name         = @name,
    description  = @description,
    instructions = @instructions,
    method       = @method,
    glass        = @glass,
    sweetness    = @sweetness,
    est_abv      = @est_abv,
    image_url    = @image_url
WHERE id = @id AND author_id = @author_id AND source = 'community'
RETURNING *;

-- name: DeleteRecipe :execrows
DELETE FROM recipes
WHERE id = @id AND author_id = @author_id AND source = 'community';

-- name: ListRecipeIngredients :many
SELECT ri.position, ri.amount, ri.unit_code, ri.note, ri.is_optional, ri.is_garnish,
       un.name AS unit_name, un.abbrev AS unit_abbrev, un.kind AS unit_kind, un.ml_equiv,
       i.id AS ingredient_id, i.name AS ingredient_name,
       i.kind AS ingredient_kind, i.abv
FROM recipe_ingredients ri
JOIN ingredients i ON i.id = ri.ingredient_id
LEFT JOIN units un ON un.code = ri.unit_code
WHERE ri.recipe_id = $1
ORDER BY ri.position;

-- name: InsertRecipeIngredient :exec
INSERT INTO recipe_ingredients (recipe_id, position, ingredient_id, amount, unit_code, note, is_optional, is_garnish)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8);

-- name: DeleteRecipeIngredients :exec
DELETE FROM recipe_ingredients WHERE recipe_id = $1;

-- Seeder upsert: official recipes keyed by slug so re-running the importer
-- updates in place.
-- name: UpsertRecipeBySlug :one
INSERT INTO recipes (id, slug, name, description, instructions, method, glass,
                     source, author_id, attribution, sweetness, est_abv, image_url)
VALUES ($1, $2, $3, $4, $5, $6, $7, 'official', NULL, $8, $9, $10, $11)
ON CONFLICT (slug)
DO UPDATE SET name         = EXCLUDED.name,
              description  = EXCLUDED.description,
              instructions = EXCLUDED.instructions,
              method       = EXCLUDED.method,
              glass        = EXCLUDED.glass,
              source       = 'official',
              attribution  = EXCLUDED.attribution,
              sweetness    = EXCLUDED.sweetness,
              est_abv      = EXCLUDED.est_abv,
              image_url    = EXCLUDED.image_url
RETURNING *;
