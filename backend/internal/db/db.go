// Package db owns the database connection and runs the SQL migrations.
//
// SQLite is the default: one file, no server, no container, nothing to install.
package db

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"io/fs"
	"log/slog"
	"sort"
	"strings"
	"time"

	_ "modernc.org/sqlite" // pure Go, no CGO
)

//go:embed migrations/sqlite/*.sql
var sqliteMigrations embed.FS

// DB is the shared handle.
type DB struct {
	*sql.DB
}

// Open connects. An empty dsn means "SQLite at ./6dx.db".
//
// The pragmas matter: `foreign_keys(1)` turns the references on (SQLite has
// them off by default), `journal_mode(WAL)` keeps reads from blocking a write,
// and `busy_timeout` makes a concurrent write wait instead of failing.
func Open(ctx context.Context, dsn string) (*DB, error) {
	if dsn == "" {
		dsn = "6dx.db"
	}
	if strings.HasPrefix(dsn, "postgres://") || strings.HasPrefix(dsn, "postgresql://") {
		return nil, fmt.Errorf(
			"this build uses SQLite; set DATABASE_FILE=./6dx.db instead of DATABASE_URL")
	}
	if strings.HasPrefix(dsn, "file:") {
		if !strings.Contains(dsn, "_pragma") {
			dsn += "?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_pragma=foreign_keys(1)"
		}
	} else {
		dsn = "file:" + dsn +
			"?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_pragma=foreign_keys(1)"
	}

	handle, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}
	// SQLite serialises writes anyway; one connection avoids "database is
	// locked" surprises and keeps the ordering deterministic.
	handle.SetMaxOpenConns(1)
	handle.SetMaxIdleConns(1)
	handle.SetConnMaxLifetime(0)

	var lastErr error
	for attempt := 0; attempt < 20; attempt++ {
		pingCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
		lastErr = handle.PingContext(pingCtx)
		cancel()
		if lastErr == nil {
			return &DB{DB: handle}, nil
		}
		select {
		case <-ctx.Done():
			handle.Close()
			return nil, ctx.Err()
		case <-time.After(time.Second):
		}
	}
	handle.Close()
	return nil, fmt.Errorf("database unreachable: %w", lastErr)
}

// Migrate applies every embedded migration once, in name order, and records it
// in schema_migrations so a restart is a no-op.
func Migrate(ctx context.Context, database *DB) error {
	if _, err := database.ExecContext(ctx, `
		create table if not exists schema_migrations (
			version    text primary key,
			applied_at text not null
		)`); err != nil {
		return fmt.Errorf("create schema_migrations: %w", err)
	}

	entries, err := fs.Glob(sqliteMigrations, "migrations/sqlite/*.sql")
	if err != nil {
		return err
	}
	sort.Strings(entries)

	for _, entry := range entries {
		version := strings.TrimSuffix(strings.TrimPrefix(entry, "migrations/sqlite/"), ".sql")

		var applied int
		if err := database.QueryRowContext(ctx,
			`select count(*) from schema_migrations where version = ?`, version,
		).Scan(&applied); err != nil {
			return fmt.Errorf("check %s: %w", version, err)
		}
		if applied > 0 {
			continue
		}

		body, err := sqliteMigrations.ReadFile(entry)
		if err != nil {
			return fmt.Errorf("read %s: %w", entry, err)
		}

		// One transaction per file: a half-applied schema is never left behind.
		tx, err := database.BeginTx(ctx, nil)
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, string(body)); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("apply %s: %w", version, err)
		}
		if _, err := tx.ExecContext(ctx,
			`insert into schema_migrations (version, applied_at) values (?, ?)`,
			version, nowString(),
		); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("record %s: %w", version, err)
		}
		if err := tx.Commit(); err != nil {
			return fmt.Errorf("commit %s: %w", version, err)
		}
		slog.Info("migration applied", "version", version)
	}
	return nil
}

func nowString() string { return time.Now().UTC().Format(time.RFC3339Nano) }
