// Command seed imports official recipe/ingredient content from JSON files.
// Idempotent: safe to re-run after adding or editing files.
//
//	DATABASE_URL=... go run ./cmd/seed -dir internal/seed/data
package main

import (
	"context"
	"encoding/json"
	"flag"
	"log"
	"os"
	"path/filepath"
	"sort"

	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/Nate5461/tippsy/server/internal/seed"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
)

func main() {
	dir := flag.String("dir", "internal/seed/data", "directory of seed JSON files")
	flag.Parse()

	_ = godotenv.Load()
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://tippsy:tippsy@localhost:5432/tippsy?sslmode=disable"
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		log.Fatalf("connect to database: %v", err)
	}
	defer pool.Close()

	paths, err := filepath.Glob(filepath.Join(*dir, "*.json"))
	if err != nil {
		log.Fatalf("list seed files: %v", err)
	}
	if len(paths) == 0 {
		log.Fatalf("no *.json seed files in %s", *dir)
	}
	sort.Strings(paths)

	queries := sqlc.New(pool)
	for _, path := range paths {
		raw, err := os.ReadFile(path)
		if err != nil {
			log.Fatalf("%s: %v", path, err)
		}
		var f seed.File
		if err := json.Unmarshal(raw, &f); err != nil {
			log.Fatalf("%s: parse: %v", path, err)
		}

		// One transaction per file: a bad file rolls back atomically.
		tx, err := pool.Begin(ctx)
		if err != nil {
			log.Fatalf("%s: begin: %v", path, err)
		}
		stats, err := seed.Import(ctx, queries.WithTx(tx), f)
		if err != nil {
			_ = tx.Rollback(ctx)
			log.Fatalf("%s: %v", path, err)
		}
		if err := tx.Commit(ctx); err != nil {
			log.Fatalf("%s: commit: %v", path, err)
		}
		log.Printf("%s: %d ingredients, %d recipes", filepath.Base(path), stats.Ingredients, stats.Recipes)
	}
}
