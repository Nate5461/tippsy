-- name: FollowUser :exec
INSERT INTO follows (follower_id, followee_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;

-- name: UnfollowUser :exec
DELETE FROM follows WHERE follower_id = $1 AND followee_id = $2;

-- name: IsFollowing :one
SELECT EXISTS (
    SELECT 1 FROM follows WHERE follower_id = $1 AND followee_id = $2
);

-- name: ListFollowers :many
SELECT u.id, u.username, u.profile_picture
FROM follows f
JOIN users u ON u.id = f.follower_id
WHERE f.followee_id = $1
ORDER BY f.created_at DESC;

-- name: ListFollowing :many
SELECT u.id, u.username, u.profile_picture
FROM follows f
JOIN users u ON u.id = f.followee_id
WHERE f.follower_id = $1
ORDER BY f.created_at DESC;

-- name: FollowingReviews :many
SELECT rv.id, rv.rating, rv.comment, rv.impairment_level, rv.photo_url,
       rv.user_id, rv.created_at, r.name AS recipe_name, u.username
FROM reviews rv
JOIN recipes r ON r.id = rv.recipe_id
JOIN users u   ON u.id = rv.user_id
WHERE rv.user_id IN (SELECT followee_id FROM follows WHERE follower_id = $1)
ORDER BY rv.created_at DESC;
