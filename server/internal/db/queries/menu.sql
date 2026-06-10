-- "My Menu": popular recipes the user can make from their bar.
--
-- bar_expanded is the user's bar plus every ancestor of each bottle, so owning
-- "Grey Goose" satisfies a recipe line that asks for plain "vodka". A recipe
-- qualifies when every required (non-optional) line is covered.
-- Ranking is popularity for now; AI-assisted ranking can re-order later.
-- name: MakeableRecipes :many
WITH RECURSIVE bar_expanded AS (
    SELECT i.id, i.parent_id
    FROM bar_items b
    JOIN ingredients i ON i.id = b.ingredient_id
    WHERE b.user_id = $1
    UNION
    SELECT p.id, p.parent_id
    FROM ingredients p
    JOIN bar_expanded c ON c.parent_id = p.id
)
SELECT r.*, u.username AS author_name,
       COALESCE(AVG(rv.rating), 0)::float8 AS average_rating,
       COUNT(rv.id)                        AS total_reviews
FROM recipes r
LEFT JOIN users u    ON u.id = r.author_id
LEFT JOIN reviews rv ON rv.recipe_id = r.id
WHERE EXISTS (
          SELECT 1 FROM recipe_ingredients ri WHERE ri.recipe_id = r.id
      )
  AND NOT EXISTS (
          SELECT 1 FROM recipe_ingredients ri
          WHERE ri.recipe_id = r.id
            AND NOT ri.is_optional
            AND ri.ingredient_id NOT IN (SELECT id FROM bar_expanded)
      )
GROUP BY r.id, u.username
ORDER BY total_reviews DESC, average_rating DESC, r.name
LIMIT 100;
