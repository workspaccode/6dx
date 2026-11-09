// Command migrate applies the embedded SQL migrations and exits.
//
// The API can do this on startup (MIGRATE_ON_STARTUP=true); this command exists
// for a deployment that wants migrations as a separate, explicit step.
package main

import (
	"context"
	"log/slog"
	"os"
	"time"

	"github.com/workspaccode/6dx/backend/internal/db"
)

func main() {
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, nil)))

	url := os.Getenv("DATABASE_URL")
	if url == "" {
		slog.Error("DATABASE_URL is required")
		os.Exit(1)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	pool, err := db.Connect(ctx, url)
	if err != nil {
		slog.Error("connect", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	if err := db.Migrate(ctx, pool); err != nil {
		slog.Error("migrate", "error", err)
		os.Exit(1)
	}

	var applied int
	if err := pool.QueryRow(ctx, `select count(*) from schema_migrations`).Scan(&applied); err != nil {
		slog.Error("count", "error", err)
		os.Exit(1)
	}
	slog.Info("migrations up to date", "applied", applied)
}
