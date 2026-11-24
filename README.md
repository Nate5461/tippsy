# Tippsy
*A new way to discover, log and review cocktails, for seasoned connoisseurs and new drinkers alike.*

## Features
- **Accounts**: sign up, log in, and verify your email with a one-time code (JWT auth).
- **Structured recipes**: every recipe line is an ingredient, an amount and a unit. Measures show in metric or imperial, and strength (ABV) is estimated by the server.
- **Log a drink**: record a drink you had, or create your own recipe or variant with a glass, garnish and photo.
- **My Bar**: track the bottles you own and see which recipes you can make with them.
- **Search & discovery**: one search across recipes, users, menus and tags.
- **Menus & tags**: put recipes together into your own menus, and tag recipes with shared tags.
- **Social**: review and rate recipes, follow other users, see a feed of reviews from people you follow, and favourite recipes.

## Project layout
```
server/    Go + PostgreSQL API (see server/README.md for architecture and endpoints)
ios/       SwiftUI app (Xcode project)
```

## Prerequisites
- Go 1.25+
- Docker (for local Postgres), or a local Postgres 16
- [`golang-migrate`](https://github.com/golang-migrate/migrate) and [`sqlc`](https://sqlc.dev) CLIs
- Xcode

## Running the API
```bash
cd server
cp .env.example .env          # then set JWT_SECRET (leave SMTP blank to log emails locally)
make db-up                    # start Postgres in Docker
make migrate-up               # apply the schema
make seed                     # import the official ingredient/recipe catalogue
make run                      # API on :8080
curl localhost:8080/healthz   # {"status":"ok"}
```

Tests: `make test` runs unit tests. `make test-integration` runs DB-backed tests and needs Postgres running.
`make sqlc` regenerates the query code. It also needs a live, migrated database.

## Running the iOS app
Open `ios/Tippsy/Tippsy.xcodeproj` in Xcode and run it.
- **Simulator**: connects to `http://localhost:8080` automatically.
- **Physical device**: set `devLANHost` in `ios/Tippsy/Tippsy/Services/APIConfig.swift` to your Mac's LAN IP (`ipconfig getifaddr en0`).
