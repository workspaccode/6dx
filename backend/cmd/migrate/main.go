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

	// DATABASE_FILE is the SQLite path; DATABASE_URL is accepted for a
	// deployment that still exports the old name.
	path := os.Getenv("DATABASE_FILE")
	if path == "" {
		path = os.Getenv("DATABASE_URL")
	}
	if path == "" {
		path = "6dx.db"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	database, err := db.Open(ctx, path)
	if err != nil {
		slog.Error("open", "error", err)
		os.Exit(1)
	}
	defer database.Close()

	if err := db.Migrate(ctx, database); err != nil {
		slog.Error("migrate", "error", err)
		os.Exit(1)
	}

	var applied int
	if err := database.QueryRowContext(ctx,
		`select count(*) from schema_migrations`).Scan(&applied); err != nil {
		slog.Error("count", "error", err)
		os.Exit(1)
	}
	slog.Info("migrations up to date", "database", path, "applied", applied)
}
