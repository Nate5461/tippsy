// Command api is the Tippsy HTTP server entrypoint.
package main

import (
	"context"
	"log"
	"net/http"
	"time"

	"github.com/Nate5461/tippsy/server/internal/config"
	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/Nate5461/tippsy/server/internal/email"
	"github.com/Nate5461/tippsy/server/internal/httpapi"
	"github.com/Nate5461/tippsy/server/internal/storage"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("connect to database: %v", err)
	}
	defer pool.Close()

	// Verify the database is reachable before serving traffic.
	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := pool.Ping(pingCtx); err != nil {
		log.Fatalf("ping database: %v", err)
	}

	files, err := storage.New(cfg.UploadDir)
	if err != nil {
		log.Fatalf("storage: %v", err)
	}

	// Wire up the mailer. If SMTP credentials are absent (local dev), fall back
	// to the log sender which just prints codes to stdout.
	var mailer email.Sender
	if cfg.SMTPUsername == "" || cfg.SMTPPassword == "" {
		log.Println("SMTP credentials not set — using log sender (OTPs printed to stdout)")
		mailer = email.LogSender{}
	} else {
		mailer = email.NewSMTPSender(
			cfg.SMTPHost,
			cfg.SMTPPort,
			cfg.SMTPUsername,
			cfg.SMTPPassword,
			cfg.SMTPFrom,
		)
	}

	queries := sqlc.New(pool)
	server := httpapi.NewServer(queries, cfg, files, mailer)

	// Background janitor: periodically purge unverified accounts whose verification
	// window has long passed, freeing their reserved username/email.
	go func() {
		const (
			sweepEvery = time.Hour
			maxAge     = 24 * time.Hour
		)
		ticker := time.NewTicker(sweepEvery)
		defer ticker.Stop()
		for {
			cutoff := pgtype.Timestamptz{Time: time.Now().Add(-maxAge), Valid: true}
			if n, err := queries.DeleteStaleUnverifiedUsers(context.Background(), cutoff); err != nil {
				log.Printf("janitor: delete stale unverified users: %v", err)
			} else if n > 0 {
				log.Printf("janitor: removed %d stale unverified account(s)", n)
			}
			<-ticker.C
		}
	}()

	addr := ":" + cfg.Port
	log.Printf("Tippsy API listening on %s", addr)
	if err := http.ListenAndServe(addr, server.Router()); err != nil {
		log.Fatalf("server: %v", err)
	}
}
