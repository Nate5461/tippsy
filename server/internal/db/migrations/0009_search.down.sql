-- Revert 0009_search. The pg_trgm extension is left installed (harmless, and
-- other features may rely on it).
DROP INDEX IF EXISTS menus_fts_idx;
DROP INDEX IF EXISTS recipes_fts_idx;
DROP INDEX IF EXISTS ingredients_name_trgm;
DROP INDEX IF EXISTS users_username_trgm;
DROP INDEX IF EXISTS menus_name_trgm;
DROP INDEX IF EXISTS recipes_name_trgm;
