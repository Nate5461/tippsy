-- 0003_email_verification: email OTP verification for new registrations.

ALTER TABLE users ADD COLUMN verified_at TIMESTAMPTZ;

CREATE TABLE email_verifications (
    user_id    UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    code_hash  TEXT        NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    attempts   SMALLINT    NOT NULL DEFAULT 0
);
