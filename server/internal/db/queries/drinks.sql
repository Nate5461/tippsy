-- name: GetDrinkByID :one
SELECT * FROM drinks WHERE id = $1;

-- name: ListAllDrinks :many
SELECT id, name FROM drinks ORDER BY name;

-- name: SearchDrinks :many
SELECT d.*,
       COALESCE(AVG(r.rating), 0)::float8 AS average_rating,
       COUNT(r.id)                        AS total_reviews
FROM drinks d
LEFT JOIN reviews r ON r.drink_id = d.id
WHERE d.name ILIKE @pattern OR d.category ILIKE @pattern
GROUP BY d.id
ORDER BY d.name;
