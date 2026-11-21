// Package config reads the environment the API needs.
package config

import (
	"fmt"
	"net"
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
	MigrationsOnStartup  bool

	// Environment is "development" (default) or "production". Production
	// refuses to start with settings that are only safe on a laptop.
	Environment string

	// PublicBaseURL is where the API is reachable from the internet, e.g.
	// https://api.example.com. Used for the GitHub callback URL.
	PublicBaseURL string

	// TrustedProxies are the reverse proxies (CIDRs) allowed to set
	// X-Forwarded-For. Empty = the API is reached directly and the peer
	// address is the client.
	TrustedProxies []*net.IPNet

	// Requests per minute per client IP.
	RateLimitSignIn int
	RateLimitAPI    int

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
		MigrationsOnStartup:     env("MIGRATE_ON_STARTUP", "true") == "true",
		ReadHeaderTimeout:       15 * time.Second,
		GracefulShutdownWait:    20 * time.Second,
		Environment:             env("APP_ENV", "development"),
		PublicBaseURL:           strings.TrimSuffix(env("PUBLIC_BASE_URL", ""), "/"),
	}

	var err error
	if cfg.TrustedProxies, err = parseCIDRs(os.Getenv("TRUSTED_PROXIES")); err != nil {
		return nil, err
	}
	if cfg.RateLimitSignIn, err = envInt("RATE_LIMIT_SIGNIN_PER_MIN", 30); err != nil {
		return nil, err
	}
	if cfg.RateLimitAPI, err = envInt("RATE_LIMIT_API_PER_MIN", 600); err != nil {
		return nil, err
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
		cfg.GitHubOAuthRedirect = cfg.PublicBaseURL + "/github/callback"
	}

	if cfg.IsProduction() {
		if err := cfg.validateProduction(); err != nil {
			return nil, err
		}
	}
	return cfg, nil
}

// IsProduction reports whether APP_ENV=production.
func (c *Config) IsProduction() bool { return c.Environment == "production" }

// validateProduction lists every setting that is fine locally but unsafe on a
// public server, so a misconfigured deploy fails at start-up instead of
// running open.
func (c *Config) validateProduction() error {
	var problems []string
	for _, origin := range c.CORSOrigins {
		if origin == "*" {
			problems = append(problems, "CORS_ORIGINS must list the web origins, not *")
		}
	}
	if !strings.HasPrefix(c.PublicBaseURL, "https://") {
		problems = append(problems, "PUBLIC_BASE_URL must be an https:// URL")
	}
	if c.GitHubClientID == "" || c.GitHubClientSecret == "" {
		problems = append(problems, "GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET are required")
	}
	if c.GitHubWebhookSecret != "" && c.GitHubStateSecret == c.GitHubWebhookSecret {
		problems = append(problems, "GITHUB_STATE_SECRET must be set and differ from GITHUB_WEBHOOK_SECRET")
	}
	if !strings.HasPrefix(c.GitHubOAuthRedirect, "https://") {
		problems = append(problems, "GITHUB_OAUTH_REDIRECT must be https://")
	}
	if len(problems) > 0 {
		return fmt.Errorf("APP_ENV=production but: %s", strings.Join(problems, "; "))
	}
	return nil
}

func envInt(key string, fallback int) (int, error) {
	raw := os.Getenv(key)
	if raw == "" {
		return fallback, nil
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value <= 0 {
		return 0, fmt.Errorf("%s must be a positive integer, got %q", key, raw)
	}
	return value, nil
}

// parseCIDRs reads "10.0.0.0/8, 172.16.0.1" — a bare IP is a /32 (or /128).
func parseCIDRs(raw string) ([]*net.IPNet, error) {
	var out []*net.IPNet
	for _, part := range splitList(raw) {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		if !strings.Contains(part, "/") {
			if ip := net.ParseIP(part); ip != nil && ip.To4() != nil {
				part += "/32"
			} else {
				part += "/128"
			}
		}
		_, network, err := net.ParseCIDR(part)
		if err != nil {
			return nil, fmt.Errorf("TRUSTED_PROXIES: %q is not an IP or CIDR", part)
		}
		out = append(out, network)
	}
	return out, nil
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
