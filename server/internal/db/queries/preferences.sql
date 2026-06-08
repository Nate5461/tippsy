-- name: ListUserDrinkPreferences :many
SELECT d.name
FROM user_drink_preferences p
JOIN drinks d ON d.id = p.drink_id
WHERE p.user_id = $1
ORDER BY d.name;

-- name: AddUserDrinkPreference :exec
INSERT INTO user_drink_preferences (user_id, drink_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING;

-- name: ClearUserDrinkPreferences :exec
DELETE FROM user_drink_preferences WHERE user_id = $1;
