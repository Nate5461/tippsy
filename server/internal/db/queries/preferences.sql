-- name: ListUserDrinkPreferences :many
SELECT r.name
FROM user_drink_preferences p
JOIN recipes r ON r.id = p.recipe_id
WHERE p.user_id = $1
ORDER BY r.name;

-- name: AddUserDrinkPreference :exec
INSERT INTO user_drink_preferences (user_id, recipe_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;

-- name: ClearUserDrinkPreferences :exec
DELETE FROM user_drink_preferences WHERE user_id = $1;
