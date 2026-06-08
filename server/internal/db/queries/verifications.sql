-- name: CreateEmailVerification :exec
INSERT INTO email_verifications (user_id, code_hash, expires_at)
VALUES ($1, $2, $3)
ON CONFLICT (user_id) DO UPDATE
    SET code_hash  = EXCLUDED.code_hash,
        expires_at = EXCLUDED.expires_at,
        attempts   = 0;

-- name: GetEmailVerification :one
SELECT user_id, code_hash, expires_at, attempts
FROM email_verifications
WHERE user_id = $1;

-- name: IncrementVerificationAttempts :exec
UPDATE email_verifications SET attempts = attempts + 1 WHERE user_id = $1;

-- name: DeleteEmailVerification :exec
DELETE FROM email_verifications WHERE user_id = $1;

-- name: MarkUserVerified :exec
UPDATE users SET verified_at = now() WHERE id = $1;
