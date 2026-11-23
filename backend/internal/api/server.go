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
	private.HandleFunc("DELETE /v1/invites/{id}", s.handleCancelInvite)
	private.HandleFunc("POST /v1/tasks/{id}/comments", s.handleAddComment)
	private.HandleFunc("POST /v1/tasks/{id}/subtasks", s.handleAddSubtask)
	private.HandleFunc("PATCH /v1/subtasks/{sid}", s.handleToggleSubtask)
	private.HandleFunc("POST /v1/pull-requests/{number}/review", s.handleReviewPullRequest)
	private.HandleFunc("POST /v1/time-entries/approve", s.handleApproveTimeEntries)

	private.HandleFunc("GET /v1/members", s.handleListMembers)
	private.HandleFunc("PATCH /v1/members/{uid}", s.handleChangeMemberRole)
	private.HandleFunc("DELETE /v1/members/{uid}", s.handleRemoveMember)

	private.HandleFunc("POST /v1/invites", s.handleSendInvites)
	private.HandleFunc("GET /v1/invites/pending", s.handlePendingInvites)
	private.HandleFunc("POST /v1/invites/sync", s.handleSyncInvites)
	private.HandleFunc("POST /v1/invites/accept", s.handleAcceptInvite)
	private.HandleFunc("GET /v1/invites/{id}", s.handleGetInvite)
	private.HandleFunc("POST /v1/invites/{id}/decline", s.handleDeclineInvite)

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
	private.HandleFunc("GET /v1/groups/{gid}/home", s.handleGroupHome)
	private.HandleFunc("GET /v1/groups/{gid}/workflow", s.handleListWorkflow)
	private.HandleFunc("POST /v1/groups/{gid}/workflow", s.handleCreateWorkflowState)
	private.HandleFunc("PUT /v1/groups/{gid}/workflow/order", s.handleReorderWorkflow)
	private.HandleFunc("PATCH /v1/groups/{gid}/workflow/{sid}", s.handleUpdateWorkflowState)
	private.HandleFunc("GET /v1/groups/{gid}/projects/{pid}/me", s.handleProjectMe)
	private.HandleFunc("PATCH /v1/groups/{gid}/projects/{pid}", s.handleUpdateGroupProject)
	private.HandleFunc("GET /v1/groups/{gid}/projects/{pid}/members", s.handleListProjectMembers)
	private.HandleFunc("PUT /v1/groups/{gid}/projects/{pid}/members/{uid}", s.handleSetProjectMember)
	private.HandleFunc("DELETE /v1/groups/{gid}/projects/{pid}/members/{uid}", s.handleRemoveProjectMember)
	// Links between projects of different groups (§3.1).
	lk := "/v1/groups/{gid}/projects/{pid}/links"
	private.HandleFunc("GET "+lk, s.handleListLinks)
	private.HandleFunc("POST "+lk, s.handleRequestLink)
	private.HandleFunc("GET "+lk+"/candidates", s.handleLinkCandidates)
	private.HandleFunc("POST "+lk+"/{lid}/approve", s.handleApproveLink)
	private.HandleFunc("POST "+lk+"/{lid}/revoke", s.handleRevokeLink)
	private.HandleFunc("GET "+lk+"/{lid}/summary", s.handleLinkSummary)
	private.HandleFunc("GET "+lk+"/{lid}/tasks", s.handleLinkTasks)
	private.HandleFunc("POST "+lk+"/{lid}/deps", s.handleAddLinkDep)
	private.HandleFunc("DELETE "+lk+"/{lid}/deps/{did}", s.handleDeleteLinkDep)
	// Hardware (docs/design/groups-and-roles.md §7): every route goes through
	// hwHandler — hardware group, project access, private projects.
	private.HandleFunc("GET /v1/groups/{gid}/phases", s.handleListPhaseTemplates)
	private.HandleFunc("POST /v1/groups/{gid}/phases", s.handleCreatePhaseTemplate)
	private.HandleFunc("PUT /v1/groups/{gid}/phases/order", s.handleReorderPhaseTemplates)
	private.HandleFunc("PATCH /v1/groups/{gid}/phases/{tid}", s.handleUpdatePhaseTemplate)
	hw := "/v1/groups/{gid}/projects/{pid}/hw/"
	private.HandleFunc("GET "+hw+"phases", s.hwProgressHandler(s.handleListPhases))
	private.HandleFunc("PATCH "+hw+"phases/{phid}", s.hwHandler(s.handleUpdatePhase))
	private.HandleFunc("POST "+hw+"phases/{phid}/gate", s.hwHandler(s.handleGateDecision))
	private.HandleFunc("GET "+hw+"overview", s.hwProgressHandler(s.handleHWOverview))
	private.HandleFunc("GET "+hw+"parts", s.hwHandler(s.handleListParts))
	private.HandleFunc("POST "+hw+"parts", s.hwHandler(s.handleCreatePart))
	private.HandleFunc("PATCH "+hw+"parts/{partid}", s.hwHandler(s.handleUpdatePart))
	private.HandleFunc("GET "+hw+"parts/{partid}/children", s.hwHandler(s.handleListPartChildren))
	private.HandleFunc("PUT "+hw+"parts/{partid}/children/{child}", s.hwHandler(s.handleSetPartChild))
	private.HandleFunc("DELETE "+hw+"parts/{partid}/children/{child}", s.hwHandler(s.handleDeletePartChild))
	private.HandleFunc("GET "+hw+"parts/{partid}/where-used", s.hwHandler(s.handleWhereUsed))
	private.HandleFunc("GET "+hw+"bom/{rid}/tree", s.hwHandler(s.handleBOMTree))
	private.HandleFunc("GET "+hw+"bom", s.hwHandler(s.handleListBOM))
	private.HandleFunc("POST "+hw+"bom", s.hwHandler(s.handleCreateBOM))
	private.HandleFunc("GET "+hw+"bom/{rid}", s.hwHandler(s.handleGetBOM))
	private.HandleFunc("DELETE "+hw+"bom/{rid}", s.hwHandler(s.handleDeleteBOMDraft))
	private.HandleFunc("PUT "+hw+"bom/{rid}/lines/{partid}", s.hwHandler(s.handleSetBOMLine))
	private.HandleFunc("DELETE "+hw+"bom/{rid}/lines/{partid}", s.hwHandler(s.handleDeleteBOMLine))
	private.HandleFunc("POST "+hw+"bom/{rid}/release", s.hwHandler(s.handleReleaseBOM))
	private.HandleFunc("GET "+hw+"ecos", s.hwHandler(s.handleListECOs))
	private.HandleFunc("POST "+hw+"ecos", s.hwHandler(s.handleCreateECO))
	private.HandleFunc("GET "+hw+"ecos/{eid}", s.hwHandler(s.handleGetECO))
	private.HandleFunc("POST "+hw+"ecos/{eid}/items", s.hwHandler(s.handleAddECOItem))
	private.HandleFunc("DELETE "+hw+"ecos/{eid}/items/{iid}", s.hwHandler(s.handleDeleteECOItem))
	private.HandleFunc("POST "+hw+"ecos/{eid}/submit", s.hwHandler(s.handleSubmitECO))
	private.HandleFunc("POST "+hw+"ecos/{eid}/review", s.hwHandler(s.handleReviewECO))
	private.HandleFunc("POST "+hw+"ecos/{eid}/release", s.hwHandler(s.handleReleaseECO))
	private.HandleFunc("GET "+hw+"builds", s.hwHandler(s.handleListBuilds))
	private.HandleFunc("POST "+hw+"builds", s.hwHandler(s.handleCreateBuild))
	private.HandleFunc("PATCH "+hw+"builds/{bid}", s.hwHandler(s.handleUpdateBuild))
	private.HandleFunc("GET "+hw+"builds/{bid}/units", s.hwHandler(s.handleListUnits))
	private.HandleFunc("POST "+hw+"builds/{bid}/units", s.hwHandler(s.handleCreateUnits))
	private.HandleFunc("PATCH "+hw+"units/{unid}", s.hwHandler(s.handleUpdateUnit))
	private.HandleFunc("GET "+hw+"units/{unid}/results", s.hwHandler(s.handleListUnitResults))
	private.HandleFunc("POST "+hw+"units/{unid}/results", s.hwHandler(s.handleRecordResult))
	private.HandleFunc("GET "+hw+"tests", s.hwHandler(s.handleListTestPlans))
	private.HandleFunc("POST "+hw+"tests", s.hwHandler(s.handleCreateTestPlan))
	private.HandleFunc("POST "+hw+"tests/{tpid}/approve", s.hwHandler(s.handleApproveTestPlan))
	private.HandleFunc("GET "+hw+"firmware", s.hwHandler(s.handleListFirmware))
	private.HandleFunc("POST "+hw+"firmware", s.hwHandler(s.handleLinkFirmware))
	private.HandleFunc("DELETE "+hw+"firmware", s.hwHandler(s.handleUnlinkFirmware))
	private.HandleFunc("POST "+hw+"ecos/{eid}/reopen", s.hwHandler(s.handleECOStatus("draft")))
	private.HandleFunc("POST "+hw+"ecos/{eid}/cancel", s.hwHandler(s.handleECOStatus("cancelled")))
	// Procurement and inventory: group level (stock, vendors) and project
	// level (POs, reservations, demand).
	private.HandleFunc("GET /v1/groups/{gid}/inventory/settings", s.handleGetInvSettings)
	private.HandleFunc("PATCH /v1/groups/{gid}/inventory/settings", s.handleUpdateInvSettings)
	private.HandleFunc("GET /v1/groups/{gid}/vendors", s.handleListVendors)
	private.HandleFunc("POST /v1/groups/{gid}/vendors", s.handleCreateVendor)
	private.HandleFunc("PATCH /v1/groups/{gid}/vendors/{vid}", s.handleUpdateVendor)
	private.HandleFunc("GET /v1/groups/{gid}/stock", s.handleListStock)
	private.HandleFunc("GET /v1/groups/{gid}/stock/movements", s.handleListMovements)
	private.HandleFunc("POST /v1/groups/{gid}/stock/movements", s.handleCreateMovement)
	private.HandleFunc("GET "+hw+"demand", s.hwHandler(s.handleDemand))
	// Certifications (project; the client reads them) and lab booking (group).
	private.HandleFunc("GET "+hw+"certs", s.hwProgressHandler(s.handleListCerts))
	private.HandleFunc("POST "+hw+"certs", s.hwHandler(s.handleCreateCert))
	private.HandleFunc("PATCH "+hw+"certs/{cid}", s.hwHandler(s.handleUpdateCert))
	private.HandleFunc("GET /v1/groups/{gid}/lab/assets", s.handleListLabAssets)
	private.HandleFunc("POST /v1/groups/{gid}/lab/assets", s.handleCreateLabAsset)
	private.HandleFunc("PATCH /v1/groups/{gid}/lab/assets/{aid}", s.handleUpdateLabAsset)
	private.HandleFunc("GET /v1/groups/{gid}/lab/bookings", s.handleListLabBookings)
	private.HandleFunc("POST /v1/groups/{gid}/lab/bookings", s.handleCreateLabBooking)
	private.HandleFunc("POST /v1/groups/{gid}/lab/bookings/{bkid}/cancel", s.handleCancelLabBooking)
	private.HandleFunc("GET "+hw+"reservations", s.hwHandler(s.handleListReservations))
	private.HandleFunc("POST "+hw+"reservations", s.hwHandler(s.handleCreateReservation))
	private.HandleFunc("DELETE "+hw+"reservations/{rsid}", s.hwHandler(s.handleReleaseReservation))
	private.HandleFunc("POST "+hw+"builds/{bid}/issue", s.hwHandler(s.handleIssueBuild))
	private.HandleFunc("GET "+hw+"pos", s.hwHandler(s.handleListPOs))
	private.HandleFunc("POST "+hw+"pos", s.hwHandler(s.handleCreatePO))
	private.HandleFunc("GET "+hw+"pos/{poid}", s.hwHandler(s.handleGetPO))
	private.HandleFunc("PUT "+hw+"pos/{poid}/lines/{part}", s.hwHandler(s.handleSetPOLine))
	private.HandleFunc("DELETE "+hw+"pos/{poid}/lines/{part}", s.hwHandler(s.handleDeletePOLine))
	private.HandleFunc("POST "+hw+"pos/{poid}/submit", s.hwHandler(s.handleSubmitPO))
	private.HandleFunc("POST "+hw+"pos/{poid}/approve", s.hwHandler(s.handleApprovePO))
	private.HandleFunc("POST "+hw+"pos/{poid}/receive", s.hwHandler(s.handleReceivePO))
	private.HandleFunc("POST "+hw+"pos/{poid}/close", s.hwHandler(s.handlePOStatus("closed")))
	private.HandleFunc("POST "+hw+"pos/{poid}/cancel", s.hwHandler(s.handlePOStatus("cancelled")))

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
				"Authorization, Content-Type, X-Workspace-Id, X-Group-Id")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
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
