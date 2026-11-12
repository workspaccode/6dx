// Command api runs the 6DX backend.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/workspaccode/6dx/backend/internal/api"
	"github.com/workspaccode/6dx/backend/internal/auth"
	"github.com/workspaccode/6dx/backend/internal/config"
	"github.com/workspaccode/6dx/backend/internal/db"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	})))

	cfg, err := config.Load()
	if err != nil {
		slog.Error("configuration", "error", err)
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	database, err := db.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("database", "error", err)
		os.Exit(1)
	}
	defer database.Close()

	if cfg.MigrationsOnStartup {
		if err := db.Migrate(ctx, database); err != nil {
			slog.Error("migrations", "error", err)
			os.Exit(1)
		}
		slog.Info("migrations applied")
	}

	verifier, err := auth.NewVerifier(ctx, cfg.ProjectID, cfg.FirebaseCredentialsFile)
	if err != nil {
		// Firebase is only there for ID tokens issued by the old sign-in; the
		// GitHub device flow the app uses now needs nothing but this API.
		slog.Warn("firebase disabled — only GitHub sessions are accepted",
			"error", err)
		verifier = auth.NewGitHubVerifier()
	}

	server := api.New(cfg, database, verifier)
	httpServer := &http.Server{
		Addr:              cfg.Addr,
		Handler:           server.Handler(),
		ReadHeaderTimeout: cfg.ReadHeaderTimeout,
	}

	go func() {
		slog.Info("listening", "addr", cfg.Addr)
		if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("listen", "error", err)
			stop()
		}
	}()

	<-ctx.Done()
	slog.Info("shutting down")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.GracefulShutdownWait)
	defer cancel()
	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		slog.Error("shutdown", "error", err)
	}
	_ = time.AfterFunc(time.Second, func() {})
}
