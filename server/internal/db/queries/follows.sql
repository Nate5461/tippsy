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
SELECT r.id, r.rating, r.comment, r.impairment_level, r.photo_url,
       r.user_id, r.created_at, d.name AS drink_name, u.username
FROM reviews r
JOIN drinks d ON d.id = r.drink_id
JOIN users u ON u.id = r.user_id
WHERE r.user_id IN (SELECT followee_id FROM follows WHERE follower_id = $1)
ORDER BY r.created_at DESC;
