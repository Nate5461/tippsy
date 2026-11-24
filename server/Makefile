# Tippsy Go backend — common tasks.
# Override DATABASE_URL via the environment if needed.
DATABASE_URL ?= postgres://tippsy:tippsy@localhost:5432/tippsy?sslmode=disable
MIGRATIONS   := internal/db/migrations

.PHONY: db-up db-down migrate-up migrate-down sqlc seed run build test test-integration tidy

## Start/stop local Postgres
db-up:
	docker compose up -d

db-down:
	docker compose down

## Migrations (requires golang-migrate CLI)
migrate-up:
	migrate -path $(MIGRATIONS) -database "$(DATABASE_URL)" up

migrate-down:
	migrate -path $(MIGRATIONS) -database "$(DATABASE_URL)" down 1

## Regenerate type-safe query code from SQL
sqlc:
	sqlc generate

## Import official ingredient/recipe content (idempotent; see internal/seed/README.md)
seed:
	DATABASE_URL="$(DATABASE_URL)" go run ./cmd/seed -dir internal/seed/data

## Run / build the server
run:
	go run ./cmd/api

build:
	go build -o bin/api ./cmd/api

## Tests
test:
	go test ./...

test-integration:
	go test -tags=integration ./...

tidy:
	go mod tidy
