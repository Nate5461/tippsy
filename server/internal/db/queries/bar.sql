-- name: ListBarItems :many
SELECT b.created_at AS added_at, i.*
FROM bar_items b
JOIN ingredients i ON i.id = b.ingredient_id
WHERE b.user_id = $1
ORDER BY i.kind, i.name;

-- name: AddBarItem :exec
INSERT INTO bar_items (user_id, ingredient_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;

-- name: RemoveBarItem :exec
DELETE FROM bar_items WHERE user_id = $1 AND ingredient_id = $2;
