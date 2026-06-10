-- name: AddFavourite :exec
INSERT INTO favourites (user_id, recipe_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;

-- name: RemoveFavourite :exec
DELETE FROM favourites WHERE user_id = $1 AND recipe_id = $2;

-- name: ListFavourites :many
SELECT r.*, u.username AS author_name,
       COALESCE(AVG(rv.rating), 0)::float8 AS average_rating,
       COUNT(rv.id)                        AS total_reviews,
       f.created_at                        AS favourited_at
FROM favourites f
JOIN recipes r       ON r.id = f.recipe_id
LEFT JOIN users u    ON u.id = r.author_id
LEFT JOIN reviews rv ON rv.recipe_id = r.id
WHERE f.user_id = $1
GROUP BY r.id, u.username, f.created_at
ORDER BY f.created_at DESC;
