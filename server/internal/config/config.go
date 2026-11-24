// Package config loads and validates application settings from the environment.
package config

import (
	"fmt"
	"os"

	"github.com/joho/godotenv"
)

// Config holds all runtime configuration. It is loaded once at startup.
type Config struct {
	DatabaseURL   string
	JWTSecret     []byte
	Port          string
	UploadDir     string
	PublicBaseURL string

	// SMTP / email
	SMTPHost     string
	SMTPPort     string
	SMTPUsername string
	SMTPPassword string
	SMTPFrom     string
}

// Load reads configuration from the environment. A local .env file is loaded if
// present (handy for development) but is never required. Required values cause a
// hard error so the server never starts in a half-configured state.
func Load() (Config, error) {
	// Best-effort: ignore the error so production (no .env file) is fine.
	_ = godotenv.Load()

	cfg := Config{
		DatabaseURL:   os.Getenv("DATABASE_URL"),
		JWTSecret:     []byte(os.Getenv("JWT_SECRET")),
		Port:          getenvDefault("PORT", "8080"),
		UploadDir:     getenvDefault("UPLOAD_DIR", "./uploads"),
		PublicBaseURL: getenvDefault("PUBLIC_BASE_URL", "http://localhost:8080"),

		SMTPHost:     getenvDefault("SMTP_HOST", "smtp-relay.brevo.com"),
		SMTPPort:     getenvDefault("SMTP_PORT", "587"),
		SMTPUsername: os.Getenv("SMTP_USERNAME"),
		SMTPPassword: os.Getenv("SMTP_PASSWORD"),
		SMTPFrom:     getenvDefault("SMTP_FROM", "Tippsy <charliebissett906@gmail.com>"),
	}

	if cfg.DatabaseURL == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}
	if len(cfg.JWTSecret) == 0 {
		return Config{}, fmt.Errorf("JWT_SECRET is required")
	}

	return cfg, nil
}

func getenvDefault(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
