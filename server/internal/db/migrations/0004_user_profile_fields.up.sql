-- 0004_user_profile_fields: add the mutable profile fields (display_name, bio)
-- and an auto-maintained updated_at. username/email stay immutable post-signup.

ALTER TABLE users ADD COLUMN display_name TEXT;
ALTER TABLE users ADD COLUMN bio          TEXT;
ALTER TABLE users ADD COLUMN updated_at   TIMESTAMPTZ NOT NULL DEFAULT now();

-- Keep updated_at current on every row update without the app having to set it.
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_set_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();
