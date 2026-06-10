-- name: GetIngredient :one
SELECT * FROM ingredients WHERE id = $1;

-- name: GetIngredientsByIDs :many
SELECT * FROM ingredients WHERE id = ANY(@ids::uuid[]);

-- Catalogue search for pickers: everyone sees the official catalogue, plus
-- their own custom ingredients.
-- name: SearchIngredients :many
SELECT * FROM ingredients
WHERE (created_by IS NULL OR created_by = @viewer)
  AND name ILIKE @pattern
  AND (sqlc.narg('kind')::ingredient_kind IS NULL OR kind = sqlc.narg('kind'))
ORDER BY name
LIMIT 50;

-- name: CreateIngredient :one
INSERT INTO ingredients (id, name, kind, parent_id, abv, description, created_by)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING *;

-- Seeder upsert: official catalogue rows keyed by case-insensitive name.
-- Parents are resolved in a second pass via SetIngredientParent.
-- name: UpsertOfficialIngredient :one
INSERT INTO ingredients (id, name, kind, abv, description, created_by)
VALUES ($1, $2, $3, $4, $5, NULL)
ON CONFLICT (lower(name)) WHERE created_by IS NULL
DO UPDATE SET kind        = EXCLUDED.kind,
              abv         = EXCLUDED.abv,
              description = COALESCE(EXCLUDED.description, ingredients.description)
RETURNING *;

-- name: GetOfficialIngredientByName :one
SELECT * FROM ingredients
WHERE lower(name) = lower(@name) AND created_by IS NULL;

-- name: SetIngredientParent :exec
UPDATE ingredients SET parent_id = $2 WHERE id = $1;

-- name: ListUnits :many
SELECT * FROM units ORDER BY kind, code;
