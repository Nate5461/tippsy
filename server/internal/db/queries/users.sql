-- name: CreateUser :one
INSERT INTO users (id, username, email, password_hash)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: GetUserByID :one
SELECT * FROM users WHERE id = $1;

-- name: GetUserByEmail :one
SELECT * FROM users WHERE lower(email) = lower(@email);

-- name: GetUserByUsername :one
SELECT * FROM users WHERE lower(username) = lower(@username);

-- Re-registration: overwrite an as-yet-unverified account's credentials so the
-- email's rightful owner can claim it. The verified_at guard makes this affect
-- zero rows for already-verified accounts.
-- name: UpdateUnverifiedUserCredentials :one
UPDATE users
SET username = @username, password_hash = @password_hash
WHERE id = @id AND verified_at IS NULL
RETURNING *;

-- Cleanup: drop unverified accounts whose verification window has long passed,
-- freeing their username/email. Cascades remove any dependent rows.
-- name: DeleteStaleUnverifiedUsers :execrows
DELETE FROM users
WHERE verified_at IS NULL AND created_at < @cutoff;

-- Updates the mutable profile fields. email is permanent after signup, but
-- username may be changed (e.g. during account setup) subject to a
-- uniqueness check performed by the caller. updated_at is maintained by the
-- users_set_updated_at trigger.
-- name: UpdateUser :one
UPDATE users
SET username        = COALESCE(sqlc.narg('username'), username),
    display_name    = COALESCE(sqlc.narg('display_name'), display_name),
    bio             = COALESCE(sqlc.narg('bio'), bio),
    profile_picture = COALESCE(sqlc.narg('profile_picture'), profile_picture),
    measure_pref    = COALESCE(sqlc.narg('measure_pref'), measure_pref)
WHERE id = sqlc.arg('id')
RETURNING *;

-- Ranked, typo-tolerant user search over username and display_name. An empty
-- query lists everyone alphabetically (similarity to '' is 0 for all rows).
-- name: SearchUsers :many
SELECT * FROM users
WHERE @query::text = ''
   OR username ILIKE '%' || @query::text || '%'
   OR display_name ILIKE '%' || @query::text || '%'
   OR username % @query::text
ORDER BY similarity(username, @query::text) DESC, username
LIMIT sqlc.arg('lim');

-- name: TopUsers :many
SELECT u.*, COUNT(f.follower_id) AS follower_count
FROM users u
LEFT JOIN follows f ON f.followee_id = u.id
GROUP BY u.id
ORDER BY follower_count DESC, u.username
LIMIT 5;
