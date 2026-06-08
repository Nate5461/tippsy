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
internal/
  config/           env loading + validation
  db/
    migrations/     golang-migrate .sql files (schema source of truth)
    queries/        sqlc input: hand-written SQL
    sqlc/           sqlc OUTPUT — generated, do not edit
  httpapi/          chi router, middleware, handlers, DTOs
  auth/             JWT issue/verify, password hashing, request-context user ID
  storage/          saving uploaded files to disk
uploads/            runtime upload dir (gitignored)
```

Request flow: **router → global middleware → `RequireAuth` (protected groups) → handler →
sqlc queries → pgx pool**. Handlers never touch SQL; `auth`/`storage` are small focused
packages injected at startup in `main.go`.

## Getting started

Requires Go 1.22+, the `sqlc` and `migrate` CLIs, and Docker (or a local Postgres).

```bash
cp .env.example .env          # then edit JWT_SECRET
make db-up                    # start Postgres in Docker
make migrate-up               # apply schema + seed drinks
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
| POST | `/auth/register` | – | create account |
| POST | `/auth/login` | – | returns JWT |
| GET | `/users/{id}` | – | profile + their reviews |
| PUT | `/users/{id}` | ✓ | self only |
| POST | `/users/{id}/follow` / `/unfollow` | ✓ | follower = token, target = path |
| GET | `/users/{id}/followers` / `/following` | – | |
| GET | `/users/{id}/following/reviews` | – | feed of followed users' reviews |
| GET | `/users/topUsers` | – | top 5 by follower count |
| GET | `/search/users?username=` | – | |
| GET | `/search/drinks?query=` | – | with avg rating + review counts |
| GET | `/search/allDrinks` | – | id + name |
| POST | `/reviews` | ✓ | multipart, optional `photo`; user from token |
| GET | `/reviews` | – | all reviews, newest first |
| GET | `/reviews/drink?drinkId=` | – | reviews for one drink |
| GET | `/reviews/mostReviewedDrinks` | – | top 5 by review count |
| GET | `/uploads/*` | – | static review photos |
