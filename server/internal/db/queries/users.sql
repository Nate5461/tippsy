-- name: CreateUser :one
INSERT INTO users (id, username, email, password_hash)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: GetUserByID :one
SELECT * FROM users WHERE id = $1;

-- name: GetUserByEmail :one
SELECT * FROM users WHERE lower(email) = lower(@email);

-- name: ExistsUserByUsernameOrEmail :one
SELECT EXISTS (
    SELECT 1 FROM users WHERE lower(username) = lower(@username) OR lower(email) = lower(@email)
);

-- name: UpdateUser :one
UPDATE users
SET username        = COALESCE(sqlc.narg('username'), username),
    profile_picture = COALESCE(sqlc.narg('profile_picture'), profile_picture)
WHERE id = sqlc.arg('id')
RETURNING *;

-- name: SearchUsers :many
SELECT * FROM users
WHERE username ILIKE @pattern
ORDER BY username
LIMIT 50;

-- name: TopUsers :many
SELECT u.*, COUNT(f.follower_id) AS follower_count
FROM users u
LEFT JOIN follows f ON f.followee_id = u.id
GROUP BY u.id
ORDER BY follower_count DESC, u.username
LIMIT 5;
