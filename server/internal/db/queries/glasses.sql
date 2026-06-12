-- name: ListGlassTypes :many
SELECT * FROM glass_types ORDER BY sort_order, name;
