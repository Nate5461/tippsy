-- 0001_init: core schema for the drinks-only Tippsy app.
-- UUIDs are generated in Go (uuid.New()) and passed in, so no DB extension is required.

CREATE TABLE users (
    id              UUID PRIMARY KEY,
    username        TEXT NOT NULL,
    email           TEXT NOT NULL,
    password_hash   TEXT NOT NULL,
    profile_picture TEXT,
    location        TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Case-insensitive uniqueness: "Bob" and "bob" cannot both register.
CREATE UNIQUE INDEX users_username_key ON users (lower(username));
CREATE UNIQUE INDEX users_email_key    ON users (lower(email));

CREATE TABLE drinks (
    id                  UUID PRIMARY KEY,
    name                TEXT NOT NULL,
    category            TEXT NOT NULL,
    recipe_ingredients  TEXT[] NOT NULL DEFAULT '{}',
    recipe_instructions TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE follows (
    follower_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    followee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, followee_id),
    CHECK (follower_id <> followee_id)
);
-- Speeds up "who follows X" and the topUsers follower-count aggregation.
CREATE INDEX follows_followee_idx ON follows (followee_id);

CREATE TABLE reviews (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    drink_id         UUID NOT NULL REFERENCES drinks(id) ON DELETE CASCADE,
    rating           SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment          TEXT,
    impairment_level SMALLINT CHECK (impairment_level BETWEEN 1 AND 5),
    photo_url        TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX reviews_drink_id_idx ON reviews (drink_id);
CREATE INDEX reviews_user_id_idx  ON reviews (user_id);

CREATE TABLE user_drink_preferences (
    user_id    UUID NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    drink_id   UUID NOT NULL REFERENCES drinks(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, drink_id)
);
