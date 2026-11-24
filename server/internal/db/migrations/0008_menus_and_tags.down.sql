-- Revert 0008_menus_and_tags.
DROP TABLE IF EXISTS menu_tags;
DROP TABLE IF EXISTS recipe_tags;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS menu_items;
DROP TABLE IF EXISTS menus;
DROP TYPE IF EXISTS menu_visibility;
