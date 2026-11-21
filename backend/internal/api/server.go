// Package api wires the HTTP surface: routing, middleware and the handlers.
package api

import (
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/workspaccode/6dx/backend/internal/config"
	"github.com/workspaccode/6dx/backend/internal/db"
	"github.com/workspaccode/6dx/backend/internal/httpx"
)

// Verifier is the dependency the middleware needs. It is an interface so a test
// can inject a fake caller without Firebase.
type Verifier interface {
	Middleware(http.Handler) http.Handler
}

// Server holds everything the handlers need.
type Server struct {
	cfg      *config.Config
	store    *store
	verifier Verifier
	github   *githubBroker

	// httpClient carries out the GitHub calls the device-flow proxy makes.
	httpClient *http.Client
	// githubOAuthBase is https://github.com; a test points it at httptest.
	githubOAuthBase string
}

// New builds the server and the router.
func New(cfg *config.Config, database *db.DB, verifier Verifier) *Server {
	s := &Server{
		cfg:             cfg,
		store:           &store{db: database},
		verifier:        verifier,
		httpClient:      &http.Client{Timeout: 20 * time.Second},
		githubOAuthBase: "https://github.com",
	}
	if cfg.GitHubEnabled() {
		broker, err := newGithubBroker(cfg)
		if err != nil {
			slog.Error("github broker disabled", "error", err)
		} else {
			s.github = broker
		}
	} else {
		slog.Warn("github credentials incomplete — the GitHub endpoints fail closed")
	}
	return s
}

// Handler returns the fully wired http.Handler.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()

	// --- public ------------------------------------------------------------
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	// The GitHub App browser legs and the webhook are public by design: the
	// signed state carries the binding and the webhook is HMAC verified.
	mux.HandleFunc("GET /github/setup", s.handleGithubSetup)
	mux.HandleFunc("GET /github/callback", s.handleGithubCallback)
	mux.HandleFunc("POST /github/webhook", s.handleGithubWebhook)

	// Sign-in itself is public: the device flow runs before a session exists.
	// It is proxied here because GitHub's OAuth endpoints send no CORS headers.
	// Rate-limited per IP: every call spends the app's GitHub quota, and a
	// flood on device-code would lock everyone out of sign-in. The device
	// flow polls every ~5s for up to 15 min, which stays well under the limit.
	clientIP := httpx.ClientIPResolver{Trusted: s.cfg.TrustedProxies}.ClientIP
	signIn := httpx.NewRateLimiter(orDefault(s.cfg.RateLimitSignIn, 30), time.Minute)
	mux.Handle("POST /auth/github/device-code",
		signIn.Middleware(clientIP, http.HandlerFunc(s.handleGithubDeviceCode)))
	mux.Handle("POST /auth/github/device-token",
		signIn.Middleware(clientIP, http.HandlerFunc(s.handleGithubDeviceToken)))

	// --- authenticated -----------------------------------------------------
	private := http.NewServeMux()
	private.HandleFunc("GET /v1/me", s.handleMe)
	private.HandleFunc("GET /v1/workspace/snapshot", s.handleSnapshot)

	private.HandleFunc("GET /v1/projects", s.handleListProjects)
	private.HandleFunc("POST /v1/projects", s.handleCreateProject)
	private.HandleFunc("POST /v1/projects/{id}/archive", s.handleArchiveProject)

	private.HandleFunc("GET /v1/tasks", s.handleListTasks)
	private.HandleFunc("POST /v1/tasks", s.handleCreateTask)
	private.HandleFunc("PATCH /v1/tasks/{id}/status", s.handleUpdateTaskStatus)
	private.HandleFunc("DELETE /v1/tasks/{id}", s.handleDeleteTask)
	private.HandleFunc("POST /v1/pull-requests/{number}/review", s.handleReviewPullRequest)
	private.HandleFunc("POST /v1/time-entries/approve", s.handleApproveTimeEntries)

	private.HandleFunc("GET /v1/members", s.handleListMembers)
	private.HandleFunc("PATCH /v1/members/{uid}", s.handleChangeMemberRole)
	private.HandleFunc("DELETE /v1/members/{uid}", s.handleRemoveMember)

	private.HandleFunc("POST /v1/invites", s.handleSendInvites)
	private.HandleFunc("GET /v1/invites/pending", s.handlePendingInvites)
	private.HandleFunc("POST /v1/invites/sync", s.handleSyncInvites)
	private.HandleFunc("POST /v1/invites/accept", s.handleAcceptInvite)

	private.HandleFunc("GET /v1/workspace/plan", s.handleWorkspacePlan)
	private.HandleFunc("GET /v1/groups", s.handleListGroups)
	private.HandleFunc("POST /v1/groups", s.handleCreateGroup)
	private.HandleFunc("GET /v1/groups/{gid}/me", s.handleGroupMe)
	private.HandleFunc("PATCH /v1/groups/{gid}", s.handleUpdateGroup)
	private.HandleFunc("DELETE /v1/groups/{gid}", s.handleDeleteGroup)
	private.HandleFunc("POST /v1/groups/{gid}/transfer", s.handleTransferGroupLead)
	private.HandleFunc("GET /v1/groups/{gid}/members", s.handleListGroupMembers)
	private.HandleFunc("PATCH /v1/groups/{gid}/members/{uid}", s.handleUpdateGroupMember)
	private.HandleFunc("DELETE /v1/groups/{gid}/members/{uid}", s.handleRemoveGroupMember)
	private.HandleFunc("POST /v1/groups/{gid}/invites", s.handleSendGroupInvites)

	private.HandleFunc("POST /v1/notifications/{id}/read", s.handleMarkNotificationRead)
	private.HandleFunc("POST /v1/notifications/read-all", s.handleMarkAllNotificationsRead)

	private.HandleFunc("POST /v1/client-report/decision", s.handleClientDecision)

	private.HandleFunc("GET /v1/github/installation", s.handleGithubInstallation)
	private.HandleFunc("GET /v1/github/repositories", s.handleGithubRepositories)
	private.HandleFunc("POST /v1/github/token", s.handleGithubToken)
	private.HandleFunc("POST /v1/github/install-url", s.handleGithubInstallURL)
	private.HandleFunc("POST /v1/github/disconnect", s.handleGithubDisconnect)

	// The limiter runs before token verification, so a flood of bad tokens
	// cannot turn into a flood of GitHub calls.
	api := httpx.NewRateLimiter(orDefault(s.cfg.RateLimitAPI, 600), time.Minute)
	mux.Handle("/v1/", api.Middleware(clientIP, s.verifier.Middleware(s.withStoredIdentity(private))))

	return s.withCommon(mux)
}

// withCommon adds CORS, request logging and a panic guard.
func (s *Server) withCommon(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()

		if origin := r.Header.Get("Origin"); origin != "" && s.originAllowed(origin) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Headers",
				"Authorization, Content-Type, X-Workspace-Id")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Max-Age", "86400")
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		defer func() {
			if recovered := recover(); recovered != nil {
				slog.Error("panic", "path", r.URL.Path, "recovered", recovered)
				writeJSON(w, http.StatusInternalServerError, map[string]string{
					"error": "internal", "message": "حدث خطأ غير متوقع.",
				})
			}
			slog.Info("request",
				"method", r.Method,
				"path", r.URL.Path,
				"duration_ms", time.Since(started).Milliseconds(),
			)
		}()

		next.ServeHTTP(w, r)
	})
}

func (s *Server) originAllowed(origin string) bool {
	for _, allowed := range s.cfg.CORSOrigins {
		if allowed == "*" || strings.EqualFold(allowed, origin) {
			return true
		}
	}
	return false
}

// orDefault keeps tests (which build a bare Config) on the production limits.
func orDefault(value, fallback int) int {
	if value > 0 {
		return value
	}
	return fallback
}
