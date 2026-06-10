-- name: CreateReview :one
INSERT INTO reviews (id, user_id, recipe_id, rating, comment, impairment_level, photo_url)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING *;

-- name: ListReviews :many
SELECT rv.id, rv.rating, rv.comment, rv.impairment_level, rv.photo_url,
       rv.user_id, rv.created_at, r.name AS recipe_name, u.username
FROM reviews rv
JOIN recipes r ON r.id = rv.recipe_id
JOIN users u   ON u.id = rv.user_id
ORDER BY rv.created_at DESC;

-- name: ListReviewsByUser :many
SELECT rv.id, rv.rating, rv.comment, rv.impairment_level, rv.photo_url,
       rv.user_id, rv.created_at, r.name AS recipe_name, u.username
FROM reviews rv
JOIN recipes r ON r.id = rv.recipe_id
JOIN users u   ON u.id = rv.user_id
WHERE rv.user_id = $1
ORDER BY rv.created_at DESC;

-- name: ListReviewsByRecipe :many
SELECT rv.id, rv.rating, rv.comment, rv.impairment_level, rv.photo_url,
       rv.user_id, rv.created_at, r.name AS recipe_name, u.username
FROM reviews rv
JOIN recipes r ON r.id = rv.recipe_id
JOIN users u   ON u.id = rv.user_id
WHERE rv.recipe_id = $1
ORDER BY rv.created_at DESC;
