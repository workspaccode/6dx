//go:build integration

package api

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	"github.com/workspaccode/6dx/backend/internal/config"
	"github.com/workspaccode/6dx/backend/internal/db"
)

const testWebhookSecret = "hook-secret"

// newGitHubHarness is newHarness with a GitHub App configured (a throwaway
// key), so the webhook endpoint is live.
func newGitHubHarness(t *testing.T) *harness {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	pemKey := pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(key)})
	database, err := db.Open(context.Background(), filepath.Join(t.TempDir(), "gh.db"))
	if err != nil {
		t.Fatal(err)
	}
	if err := db.Migrate(context.Background(), database); err != nil {
		t.Fatal(err)
	}
	cfg := &config.Config{
		ProjectID: "test", CORSOrigins: []string{"*"},
		GitHubAppID: "1", GitHubAppSlug: "sixdx", GitHubPrivateKeyPEM: string(pemKey),
		GitHubWebhookSecret: testWebhookSecret, GitHubStateSecret: "state-secret",
		GitHubClientID: "cid", GitHubClientSecret: "csecret",
	}
	srv := New(cfg, database, fakeVerifier{})
	ts := httptest.NewServer(srv.Handler())
	t.Cleanup(func() {
		ts.Close()
		database.Close()
	})
	return &harness{server: ts, database: database}
}

func (h *harness) webhook(t *testing.T, event, delivery string, payload any) (int, map[string]any) {
	t.Helper()
	body, _ := json.Marshal(payload)
	b := &githubBroker{cfg: &config.Config{GitHubWebhookSecret: testWebhookSecret}}
	req, _ := http.NewRequest(http.MethodPost, h.server.URL+"/github/webhook", bytes.NewReader(body))
	req.Header.Set("X-GitHub-Event", event)
	req.Header.Set("X-GitHub-Delivery", delivery)
	req.Header.Set("X-Hub-Signature-256", "sha256="+b.webhookHMAC(body))
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	var out map[string]any
	_ = json.NewDecoder(resp.Body).Decode(&out)
	return resp.StatusCode, out
}

func prPayload(repo string, number int, title, state, updated string) map[string]any {
	return map[string]any{
		"action":       "synchronize",
		"number":       number,
		"repository":   map[string]any{"full_name": repo},
		"installation": map[string]any{"id": 4242},
		"pull_request": map[string]any{
			"number": number, "title": title, "state": state, "updated_at": updated,
			"user": map[string]any{"login": "octo", "id": 99},
			"head": map[string]any{"ref": "feat/x", "sha": "abc"}, "base": map[string]any{"ref": "main"},
		},
	}
}

// Stage B of the stable release: PRs per repository, webhook dedupe and
// ordering, the project link, installation removal, and the review rules.
func TestWebhookAndReviewStability(t *testing.T) {
	h := newGitHubHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "st-lead", nil)
	ws := workspaceOf(t, me)
	for _, q := range []string{
		`insert into github_installations (id, workspace_id, installation_id, account_login, account_type, created_at)
		   values ('gi', '` + ws + `', 4242, 'acme', 'Organization', 't')`,
	} {
		if _, err := h.database.ExecContext(context.Background(), q); err != nil {
			t.Fatal(err)
		}
	}
	for _, name := range []string{"api", "web"} {
		status, body := h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "st-lead", ws,
			map[string]any{"name": name, "repository_full_name": "acme/" + name})
		if status != http.StatusCreated {
			t.Fatalf("project %s: %d %v", name, status, body)
		}
	}

	// PR #5 in two repositories: two rows, each linked to its project.
	h.webhook(t, "pull_request", "d1", prPayload("acme/api", 5, "API five", "open", "2026-11-20T10:00:00Z"))
	h.webhook(t, "pull_request", "d2", prPayload("acme/web", 5, "Web five", "open", "2026-11-20T10:00:00Z"))
	_, snap := h.doWithWorkspace(t, http.MethodGet, "/v1/workspace/snapshot", "st-lead", ws, nil)
	prs := snap["pull_requests"].([]any)
	if len(prs) != 2 {
		t.Fatalf("PR #5 of two repositories: %d rows", len(prs))
	}
	for _, raw := range prs {
		if pr := raw.(map[string]any); pr["project_name"] == nil || pr["repository"] == nil {
			t.Errorf("PR not linked to its project: %v", pr)
		}
	}

	// A duplicate delivery and an older event change nothing.
	if _, out := h.webhook(t, "pull_request", "d1", prPayload("acme/api", 5, "replayed", "closed", "2026-11-21T00:00:00Z")); out["ignored"] != "duplicate_delivery" {
		t.Errorf("duplicate delivery: %v", out)
	}
	h.webhook(t, "pull_request", "d3", prPayload("acme/api", 5, "stale", "closed", "2026-11-19T00:00:00Z"))
	var title, state string
	_ = h.database.QueryRowContext(context.Background(),
		`select title, state from pull_requests where repository = 'acme/api' and number = 5`).Scan(&title, &state)
	if title != "API five" || state != "open" {
		t.Errorf("older event overwrote: %q %q", title, state)
	}

	// Review: ambiguous number needs the repository; then it works.
	if status, _ := h.doWithWorkspace(t, http.MethodPost, "/v1/pull-requests/5/review", "st-lead", ws, map[string]any{"approve": true}); status != http.StatusConflict {
		t.Errorf("ambiguous review: %d, want 409", status)
	}
	if status, body := h.doWithWorkspace(t, http.MethodPost, "/v1/pull-requests/5/review?repository=acme/api", "st-lead", ws, map[string]any{"approve": true}); status != 200 {
		t.Errorf("review with repository: %d %v", status, body)
	}
	// No review on a merged PR.
	h.webhook(t, "pull_request", "d4", prPayload("acme/web", 5, "Web five", "closed", "2026-11-22T00:00:00Z"))
	if status, _ := h.doWithWorkspace(t, http.MethodPost, "/v1/pull-requests/5/review?repository=acme/web", "st-lead", ws, map[string]any{"approve": true}); status != http.StatusConflict {
		t.Errorf("review of a closed PR: %d, want 409", status)
	}

	// The App uninstalled on GitHub: the workspace link goes.
	h.webhook(t, "installation", "d5", map[string]any{"action": "deleted", "installation": map[string]any{"id": 4242}})
	var installs int
	_ = h.database.QueryRowContext(context.Background(), `select count(*) from github_installations`).Scan(&installs)
	if installs != 0 {
		t.Errorf("installation kept after uninstall: %d", installs)
	}
}

func TestStabilityOtherRules(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "so-owner", nil)
	ws := workspaceOf(t, me)
	joinAs(t, h, "so-owner", "so-admin1", "admin")
	joinAs(t, h, "so-owner", "so-admin2", "admin")
	joinAs(t, h, "so-owner", "so-dev", "developer")

	// An admin does not demote another admin; the owner does.
	if status, _ := h.doWithWorkspace(t, http.MethodPatch, "/v1/members/so-admin2", "so-admin1", ws, map[string]any{"role": "viewer"}); status != http.StatusForbidden {
		t.Errorf("admin demoted an admin: %d", status)
	}
	if status, _ := h.doWithWorkspace(t, http.MethodPatch, "/v1/members/so-admin2", "so-owner", ws, map[string]any{"role": "developer"}); status != 200 {
		t.Errorf("owner demotes admin: %d", status)
	}

	// Cancelling an invite.
	h.doWithWorkspace(t, http.MethodPost, "/v1/invites", "so-owner", ws, map[string]any{"emails": []string{"late@x.io"}, "role": "developer"})
	var inviteID string
	_ = h.database.QueryRowContext(context.Background(),
		`select id from workspace_invites where email = 'late@x.io'`).Scan(&inviteID)
	if status, _ := h.doWithWorkspace(t, http.MethodDelete, "/v1/invites/"+inviteID, "so-dev", ws, nil); status != http.StatusForbidden {
		t.Errorf("developer cancelled an invite: %d", status)
	}
	if status, _ := h.doWithWorkspace(t, http.MethodDelete, "/v1/invites/"+inviteID, "so-admin1", ws, nil); status != 200 {
		t.Errorf("admin cancel: %d", status)
	}
	if status, _ := h.doWithWorkspace(t, http.MethodDelete, "/v1/invites/"+inviteID, "so-admin1", ws, nil); status != 404 {
		t.Errorf("second cancel: %d, want 404", status)
	}

	// Approving time marks the caller's pending entries, once.
	_, _ = h.database.ExecContext(context.Background(), `insert into time_entries (id, workspace_id, user_uid, kind, span, created_at)
		values ('te1', ?, 'so-owner', 'code', '1h', 't'), ('te2', ?, 'so-owner', 'code', '2h', 't')`, ws, ws)
	_, first := h.doWithWorkspace(t, http.MethodPost, "/v1/time-entries/approve", "so-owner", ws, nil)
	_, second := h.doWithWorkspace(t, http.MethodPost, "/v1/time-entries/approve", "so-owner", ws, nil)
	if first["approved"] != float64(2) || second["approved"] != float64(0) {
		t.Errorf("time approval: %v then %v", first, second)
	}

	// Timestamps are fixed width (string order = time order).
	var created string
	_ = h.database.QueryRowContext(context.Background(), `select created_at from workspaces where id = ?`, ws).Scan(&created)
	if len(created) != len("2006-01-02T15:04:05.000Z") {
		t.Errorf("timestamp format: %q", created)
	}
}

func TestPruneActivity(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "pr-owner", nil)
	ws := workspaceOf(t, me)
	ctx := context.Background()
	if _, err := h.database.ExecContext(ctx, `insert into activity_events (id, workspace_id, type, text, created_at)
		values ('old', ?, 'x', 'old', '2020-01-01T00:00:00.000Z'), ('new', ?, 'x', 'new', ?)`, ws, ws, nowString()); err != nil {
		t.Fatal(err)
	}
	srv := New(&config.Config{ProjectID: "test"}, h.database, fakeVerifier{})
	n, err := srv.PruneActivity(ctx)
	if err != nil || n != 1 {
		t.Fatalf("prune: %d %v", n, err)
	}
	var left int
	_ = h.database.QueryRowContext(ctx, `select count(*) from activity_events where id in ('old', 'new')`).Scan(&left)
	if left != 1 {
		t.Errorf("rows left: %d", left)
	}
}

// A PR row from before 0010 (repository unknown) is claimed by its first
// webhook instead of getting a duplicate next to it; suspend keeps the link.
func TestWebhookClaimsLegacyPullRequest(t *testing.T) {
	h := newGitHubHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "lg-lead", nil)
	ws := workspaceOf(t, me)
	ctx := context.Background()
	for _, q := range []string{
		`insert into github_installations (id, workspace_id, installation_id, account_login, account_type, created_at)
		   values ('gi', '` + ws + `', 4242, 'acme', 'Organization', 't')`,
		`insert into pull_requests (id, workspace_id, repository, number, title, branch, base_branch, state, created_at)
		   values ('legacy', '` + ws + `', '', 7, 'old', 'b', 'main', 'open', 't')`,
	} {
		if _, err := h.database.ExecContext(ctx, q); err != nil {
			t.Fatal(err)
		}
	}
	h.webhook(t, "pull_request", "l1", prPayload("acme/api", 7, "seven", "open", "2026-11-20T10:00:00Z"))
	var n int
	var id, repo string
	_ = h.database.QueryRowContext(ctx, `select count(*), max(id), max(repository) from pull_requests where number = 7`).Scan(&n, &id, &repo)
	if n != 1 || id != "legacy" || repo != "acme/api" {
		t.Errorf("legacy claim: %d rows, id %q, repo %q", n, id, repo)
	}
	h.webhook(t, "installation", "l2", map[string]any{"action": "suspend", "installation": map[string]any{"id": 4242}})
	_ = h.database.QueryRowContext(ctx, `select count(*) from github_installations`).Scan(&n)
	if n != 1 {
		t.Errorf("suspend dropped the installation")
	}
}
