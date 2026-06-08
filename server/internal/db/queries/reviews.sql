-- name: CreateReview :one
INSERT INTO reviews (id, user_id, drink_id, rating, comment, impairment_level, photo_url)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING *;

-- name: ListReviews :many
SELECT r.id, r.rating, r.comment, r.impairment_level, r.photo_url,
       r.user_id, r.created_at, d.name AS drink_name, u.username
FROM reviews r
JOIN drinks d ON d.id = r.drink_id
JOIN users u ON u.id = r.user_id
ORDER BY r.created_at DESC;

-- name: ListReviewsByUser :many
SELECT r.id, r.rating, r.comment, r.impairment_level, r.photo_url,
       r.user_id, r.created_at, d.name AS drink_name, u.username
FROM reviews r
JOIN drinks d ON d.id = r.drink_id
JOIN users u ON u.id = r.user_id
WHERE r.user_id = $1
ORDER BY r.created_at DESC;

-- name: ListReviewsByDrink :many
SELECT r.id, r.rating, r.comment, r.impairment_level, r.photo_url,
       r.user_id, r.created_at, d.name AS drink_name, u.username
FROM reviews r
JOIN drinks d ON d.id = r.drink_id
JOIN users u ON u.id = r.user_id
WHERE r.drink_id = $1
ORDER BY r.created_at DESC;

-- name: MostReviewedDrinks :many
SELECT d.id, d.name, d.category, d.recipe_ingredients, d.recipe_instructions,
       d.created_at, COUNT(r.id) AS total_reviews
FROM drinks d
JOIN reviews r ON r.drink_id = d.id
GROUP BY d.id
ORDER BY total_reviews DESC
LIMIT 5;
