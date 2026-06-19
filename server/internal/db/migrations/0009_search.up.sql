-- 0009_search: indexing infrastructure for unified, ranked, typo-tolerant search.
--
-- Full-text relevance comes from core Postgres FTS (to_tsvector / ts_rank); the
-- GIN expression indexes accelerate matching on name + description. Fuzzy / typo
-- tolerance comes from pg_trgm (the `%` similarity operator and similarity()),
-- backed by the trigram GIN indexes on the name columns.
-- Tags are joined at query time, so they are not part of these stored indexes.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Fuzzy / typo tolerance on the user-facing names.
CREATE INDEX recipes_name_trgm     ON recipes     USING gin (name gin_trgm_ops);
CREATE INDEX menus_name_trgm       ON menus       USING gin (name gin_trgm_ops);
CREATE INDEX users_username_trgm   ON users       USING gin (username gin_trgm_ops);
CREATE INDEX ingredients_name_trgm ON ingredients USING gin (name gin_trgm_ops);

-- Full-text acceleration on name + description.
CREATE INDEX recipes_fts_idx ON recipes
    USING gin (to_tsvector('english', name || ' ' || coalesce(description, '')));
CREATE INDEX menus_fts_idx ON menus
    USING gin (to_tsvector('english', name || ' ' || coalesce(description, '')));
