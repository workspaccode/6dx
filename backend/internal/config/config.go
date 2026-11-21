// Package config reads the environment the API needs.
package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// Config is the whole runtime configuration. Everything has a sane default
// except the database URL and the Firebase credentials, which are required.
type Config struct {
	// Addr is the listen address, e.g. ":8080".
	Addr string

	// DatabaseURL is the SQLite file path (default `6dx.db`). SQLite is the
	// default engine: one file, no server, no container.
	DatabaseURL string

	// FirebaseCredentialsFile is the path to the service account JSON that
	// lets the API verify Firebase ID tokens. When empty, the Google
	// application-default credentials are used instead.
	FirebaseCredentialsFile string

	// ProjectID is the Firebase project that issues the tokens.
	ProjectID string

	// CORSOrigins is the allow-list for browser clients (web build). "*"
	// allows every origin — fine for the beta, not for production.
	CORSOrigins []string

	// GitHub App credentials. All six are required for the GitHub features.
	GitHubAppID          string
	GitHubAppSlug        string
	GitHubPrivateKeyPEM  string
	GitHubWebhookSecret  string
	GitHubClientID       string
	GitHubClientSecret   string
	GitHubOAuthRedirect  string
	GitHubStateSecret    string
	GitHubStateTTL       time.Duration
	MigrationsOnStartup  bool
	ReadHeaderTimeout    time.Duration
	GracefulShutdownWait time.Duration
}

// Load builds a Config from the environment, failing fast on anything the
// server cannot run without.
//
// A `.env` file next to the binary (or in the working directory) is read first,
// so `go run ./cmd/api` works without exporting anything by hand. Variables
// already present in the real environment always win.
func Load() (*Config, error) {
	loadDotEnv(".env")
	loadDotEnv(filepath.Join("..", ".env"))

	cfg := &Config{
		Addr:                    env("ADDR", ":8080"),
		DatabaseURL:             env("DATABASE_FILE", "6dx.db"),
		FirebaseCredentialsFile: os.Getenv("FIREBASE_CREDENTIALS_FILE"),
		ProjectID:               os.Getenv("FIREBASE_PROJECT_ID"),
		CORSOrigins:             splitList(env("CORS_ORIGINS", "*")),
		GitHubAppID:             os.Getenv("GITHUB_APP_ID"),
		GitHubAppSlug:           os.Getenv("GITHUB_APP_SLUG"),
		GitHubPrivateKeyPEM:     privateKeyFromEnv(),
		GitHubWebhookSecret:     os.Getenv("GITHUB_WEBHOOK_SECRET"),
		GitHubClientID:          os.Getenv("GITHUB_CLIENT_ID"),
		GitHubClientSecret:      os.Getenv("GITHUB_CLIENT_SECRET"),
		GitHubOAuthRedirect:     os.Getenv("GITHUB_OAUTH_REDIRECT"),
		GitHubStateSecret:       os.Getenv("GITHUB_STATE_SECRET"),
		GitHubStateTTL:          30 * time.Minute,
		MigrationsOnStartup:     env("MIGRATE_ON_STARTUP", "true") == "true",
		ReadHeaderTimeout:       15 * time.Second,
		GracefulShutdownWait:    20 * time.Second,
	}

	
	// FIREBASE_PROJECT_ID is optional: it only keeps ID tokens issued by the
	// old Firebase sign-in valid. The app signs in with GitHub now, and that
	// path is verified against the GitHub API instead.
	if cfg.FirebaseCredentialsFile != "" {
		if _, err := os.Stat(cfg.FirebaseCredentialsFile); err != nil {
			return nil, fmt.Errorf(
				"FIREBASE_CREDENTIALS_FILE points at %q which does not exist — "+
					"download it from Firebase console → Project settings → "+
					"Service accounts → Generate new private key",
				cfg.FirebaseCredentialsFile)
		}
	}
	if cfg.GitHubStateSecret == "" {
		// The state secret must not drift between restarts: an in-flight
		// install would break. Fall back to the webhook secret, like the
		// previous implementation did.
		cfg.GitHubStateSecret = cfg.GitHubWebhookSecret
	}
	if cfg.GitHubOAuthRedirect == "" {
		cfg.GitHubOAuthRedirect = strings.TrimSuffix(env("PUBLIC_BASE_URL", ""), "/") + "/github/callback"
	}

	return cfg, nil
}

// GitHubEnabled reports whether every credential the GitHub broker needs is
// present. The broker fails closed when it is not.
func (c *Config) GitHubEnabled() bool {
	return c.GitHubAppID != "" && c.GitHubPrivateKeyPEM != "" &&
		c.GitHubWebhookSecret != "" && c.GitHubClientID != "" &&
		c.GitHubClientSecret != "" && c.GitHubAppSlug != ""
}

// loadDotEnv reads a KEY=VALUE file and sets the variables that are not already
// present. A missing file is not an error: a deployment usually injects the
// environment directly.
func loadDotEnv(path string) {
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		line = strings.TrimPrefix(line, "export ")
		key, value, found := strings.Cut(line, "=")
		if !found {
			continue
		}
		key = strings.TrimSpace(key)
		value = strings.TrimSpace(value)
		// Strip one layer of surrounding quotes, keeping any \n escapes for
		// privateKeyFromEnv to expand.
		if len(value) >= 2 {
			if (value[0] == '"' && value[len(value)-1] == '"') ||
				(value[0] == '\'' && value[len(value)-1] == '\'') {
				value = value[1 : len(value)-1]
			}
		}
		// An empty value never wins: a placeholder like `GITHUB_CLIENT_ID=`
		// must not shadow a filled-in line further down the file.
		if key == "" || value == "" {
			continue
		}
		if _, exists := os.LookupEnv(key); exists {
			continue
		}
		_ = os.Setenv(key, value)
	}
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func splitList(value string) []string {
	parts := strings.Split(value, ",")
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		if trimmed := strings.TrimSpace(part); trimmed != "" {
			out = append(out, trimmed)
		}
	}
	return out
}

// privateKeyFromEnv accepts either the PEM itself (with literal \n escapes,
// as containers usually deliver it) or a path to a .pem file.
func privateKeyFromEnv() string {
	if inline := os.Getenv("GITHUB_PRIVATE_KEY"); inline != "" {
		return strings.ReplaceAll(inline, `\n`, "\n")
	}
	path := os.Getenv("GITHUB_PRIVATE_KEY_FILE")
	if path == "" {
		return ""
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return string(data)
}

// Bool is a tiny helper for optional numeric flags in tests.
func Bool(value string, fallback bool) bool {
	if value == "" {
		return fallback
	}
	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}
	return parsed
}
