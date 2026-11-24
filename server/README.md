# Tippsy API (Go)

A modern Go rewrite of the Tippsy backend: a drink curation / review / social app.
Replaces the legacy Node/Express + MongoDB backend in `../backend/` (kept around until the
iOS app is migrated, then removed).

## Stack

- **Go** with `net/http` + [chi](https://github.com/go-chi/chi) router
- **PostgreSQL** accessed via [pgx](https://github.com/jackc/pgx) + [sqlc](https://sqlc.dev) (type-safe, generated query code)
- **golang-migrate** for schema migrations
- **JWT** (HS256) auth with real verification middleware; **bcrypt** password hashing
- **Docker Compose** for a local database

## Project layout

```
cmd/api/            entrypoint (main.go)
cmd/seed/           recipe/ingredient content importer (idempotent)
internal/
  config/           env loading + validation
  db/
    migrations/     golang-migrate .sql files (schema source of truth)
    queries/        sqlc input: hand-written SQL
    sqlc/           sqlc OUTPUT — generated, do not edit
  httpapi/          chi router, middleware, handlers, DTOs
  auth/             JWT issue/verify, password hashing, request-context user ID
  recipes/          domain logic: strength (ABV) estimation, measure display
  seed/             seed JSON format + importer (see its README.md)
  storage/          saving uploaded files to disk
uploads/            runtime upload dir (gitignored)
```

## Domain model

Recipes are structured: each recipe line is an **ingredient** + **amount** +
**unit**. Ingredients form a hierarchy via `parent_id` (Grey Goose → Vodka), so
a bottle in your bar satisfies recipes that call for the generic. Volume units
carry bartending ml equivalents (1 oz = 30 ml), and the API renders every
measure in both systems; `users.measure_pref` says which one a client shows.
Strength (`est_abv` + a 1–5 band) is computed from ingredient ABVs, volumes,
and method-based dilution — sweetness is author-set. Recipes are `official`
(seeded, author NULL = Tippsy) or `community` (user-uploaded, public
immediately, filterable via `?source=`). "My Menu" is computed, not stored:
popular recipes makeable from the user's `bar_items`.

Request flow: **router → global middleware → `RequireAuth` (protected groups) → handler →
sqlc queries → pgx pool**. Handlers never touch SQL; `auth`/`storage` are small focused
packages injected at startup in `main.go`.

## Getting started

Requires Go 1.22+, the `sqlc` and `migrate` CLIs, and Docker (or a local Postgres).

```bash
cp .env.example .env          # then edit JWT_SECRET
make db-up                    # start Postgres in Docker
make migrate-up               # apply schema
make seed                     # import the official ingredient/recipe catalogue
make run                      # start the API on :8080
curl localhost:8080/healthz   # {"status":"ok"}
```

## Development loop (changing the schema/queries)

1. Add a migration pair in `internal/db/migrations/` (`NNNN_name.up.sql` / `.down.sql`).
2. `make migrate-up` to apply it.
3. Add/edit queries in `internal/db/queries/*.sql` (annotated with `-- name: X :one|:many|:exec`).
4. `make sqlc` to regenerate `internal/db/sqlc/`.
5. Call the generated method from a handler; the compiler verifies the types.

## Tests

```bash
make test               # unit tests (no DB)
make test-integration   # DB-backed tests (build tag: integration)
```

## Endpoints

| Method | Path | Auth | Notes |
| --- | --- | --- | --- |
| POST | `/auth/register` | – | create account (then email OTP verification) |
| POST | `/auth/login` | – | returns JWT |
| GET | `/users/{id}` | – | profile + their reviews |
| PUT | `/users/{id}` | ✓ | self only; incl. `measurePref` (metric/imperial) |
| POST | `/users/{id}/follow` / `/unfollow` | ✓ | follower = token, target = path |
| GET | `/users/{id}/followers` / `/following` | – | |
| GET | `/users/{id}/following/reviews` | – | feed of followed users' reviews |
| GET | `/users/topUsers` | – | top 5 by follower count |
| GET | `/users/{id}/favourites` | – | recipes they bookmarked |
| GET | `/users/{id}/bar` | ✓ | self only — ingredients on hand |
| POST | `/users/{id}/bar` | ✓ | `{ingredientId}` |
| DELETE | `/users/{id}/bar/{ingredientId}` | ✓ | |
| GET | `/users/{id}/menu` | ✓ | self only — popular recipes makeable from the bar |
| GET | `/search/users?username=` | – | |
| GET | `/units` | – | measure vocabulary (codes, ml equivalents) |
| GET | `/ingredients?query=&kind=` | ✓ | official catalogue + caller's customs |
| POST | `/ingredients` | ✓ | custom ingredient, visible to creator only |
| GET | `/recipes?query=&source=&maxAbv=` | – | popularity-ranked search |
| GET | `/recipes/{id}` | – | full structured recipe (lines, both measure systems) |
| POST | `/recipes` | ✓ | community recipe; strength computed server-side |
| PUT / DELETE | `/recipes/{id}` | ✓ | own community recipes only |
| POST / DELETE | `/recipes/{id}/favourite` | ✓ | |
| GET | `/recipes/{id}/reviews` | – | |
| POST | `/reviews` | ✓ | multipart: `recipe_id`, `rating`, optional `photo` |
| GET | `/reviews` | – | all reviews, newest first |
| GET | `/uploads/*` | – | static review photos |
