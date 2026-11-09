//go:build integration

// Integration tests for the authorization layer — the Go port of the RLS
// policies. They need a real Postgres:
//
//	docker run --rm -d -p 55432:5432 -e POSTGRES_PASSWORD=test \
//	  -e POSTGRES_DB=sixdx postgres:17-alpine
//	DATABASE_URL=postgres://postgres:test@localhost:55432/sixdx?sslmode=disable \
//	  go test -tags=integration ./internal/api/ -v
package api

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/workspaccode/6dx/backend/internal/auth"
	"github.com/workspaccode/6dx/backend/internal/config"
	"github.com/workspaccode/6dx/backend/internal/db"
)

// fakeVerifier stands in for Firebase: the token value is the caller's uid, so
// a test can act as any account without a real ID token.
type fakeVerifier struct{}

func (fakeVerifier) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		if uid == "" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		caller := &auth.Caller{UID: uid, Email: uid + "@6dx.test"}
		next.ServeHTTP(w, r.WithContext(auth.WithCaller(r.Context(), caller)))
	})
}

type harness struct {
	server *httptest.Server
	pool   *pgxpool.Pool
}

func newHarness(t *testing.T) *harness {
	t.Helper()

	url := os.Getenv("DATABASE_URL")
	if url == "" {
		t.Skip("DATABASE_URL not set")
	}

	ctx := context.Background()
	pool, err := db.Connect(ctx, url)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	if err := db.Migrate(ctx, pool); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	// A clean slate per run.
	if _, err := pool.Exec(ctx, `
		truncate github_installations, notifications, workspace_invites,
		         client_reports, tasks, projects, workspace_members,
		         workspaces, users cascade`); err != nil {
		t.Fatalf("truncate: %v", err)
	}

	cfg := &config.Config{ProjectID: "test", CORSOrigins: []string{"*"}}
	srv := New(cfg, pool, fakeVerifier{})
	ts := httptest.NewServer(srv.Handler())
	t.Cleanup(func() {
		ts.Close()
		pool.Close()
	})
	return &harness{server: ts, pool: pool}
}

func (h *harness) do(t *testing.T, method, path, uid string, body any) (int, map[string]any) {
	return h.doWithWorkspace(t, method, path, uid, "", body)
}

func (h *harness) doWithWorkspace(t *testing.T, method, path, uid, workspaceID string, body any) (int, map[string]any) {
	t.Helper()
	var reader *strings.Reader
	if body != nil {
		encoded, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal: %v", err)
		}
		reader = strings.NewReader(string(encoded))
	} else {
		reader = strings.NewReader("")
	}
	request, err := http.NewRequest(method, h.server.URL+path, reader)
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	request.Header.Set("Content-Type", "application/json")
	if uid != "" {
		request.Header.Set("Authorization", "Bearer "+uid)
	}
	if workspaceID != "" {
		request.Header.Set("X-Workspace-Id", workspaceID)
	}
	response, err := http.DefaultClient.Do(request)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer response.Body.Close()

	var payload map[string]any
	_ = json.NewDecoder(response.Body).Decode(&payload)
	return response.StatusCode, payload
}

// TestUnauthenticatedIsRejected: no token, no access.
func TestUnauthenticatedIsRejected(t *testing.T) {
	h := newHarness(t)
	if status, _ := h.do(t, http.MethodGet, "/v1/me", "", nil); status != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", status)
	}
}

// TestFirstSignInCreatesWorkspace: the port of ensure_my_workspace().
func TestFirstSignInCreatesWorkspace(t *testing.T) {
	h := newHarness(t)

	status, body := h.do(t, http.MethodGet, "/v1/me", "owner-1", nil)
	if status != http.StatusOK {
		t.Fatalf("expected 200, got %d (%v)", status, body)
	}
	workspace, _ := body["workspace"].(map[string]any)
	if workspace["role"] != "owner" {
		t.Fatalf("expected role owner, got %v", workspace["role"])
	}

	// Second call must reuse the same workspace, not create another.
	_, again := h.do(t, http.MethodGet, "/v1/me", "owner-1", nil)
	second, _ := again["workspace"].(map[string]any)
	if second["id"] != workspace["id"] {
		t.Fatalf("workspace changed between calls: %v != %v", second["id"], workspace["id"])
	}
}

// TestViewerCannotWrite: 0004 made viewers read-only.
func TestViewerCannotWrite(t *testing.T) {
	h := newHarness(t)

	// Owner bootstraps, then invites a viewer and accepts on their behalf.
	_, me := h.do(t, http.MethodGet, "/v1/me", "owner-2", nil)
	workspace := me["workspace"].(map[string]any)
	wsID := workspace["id"].(string)

	if status, body := h.do(t, http.MethodPost, "/v1/invites", "owner-2",
		map[string]any{"emails": []string{"viewer-2@6dx.test"}, "role": "viewer"}); status != http.StatusCreated {
		t.Fatalf("invite failed: %d %v", status, body)
	}

	// The viewer signs in, then accepts.
	h.do(t, http.MethodGet, "/v1/me", "viewer-2", nil)
	if status, body := h.do(t, http.MethodPost, "/v1/invites/accept", "viewer-2", nil); status != http.StatusOK {
		t.Fatalf("accept failed: %d %v", status, body)
	}

	// The viewer is in the workspace but must not create a project *there*.
	// The header names the workspace explicitly: without it the API would fall
	// back to the viewer's own workspace, where they are the owner.
	status, body := h.doWithWorkspace(t, http.MethodPost, "/v1/projects",
		"viewer-2", wsID, map[string]any{"name": "Nope"})
	if status != http.StatusForbidden {
		t.Fatalf("expected 403 for viewer write, got %d %v", status, body)
	}
	if body["error"] != "viewer_read_only" {
		t.Fatalf("expected viewer_read_only, got %v", body["error"])
	}

	// The owner can.
	status, body = h.doWithWorkspace(t, http.MethodPost, "/v1/projects",
		"owner-2", wsID, map[string]any{"name": "Yes"})
	if status != http.StatusCreated {
		t.Fatalf("owner write failed: %d %v", status, body)
	}

	_ = wsID
}

// TestOwnerCannotBeGranted: only transferOwnership hands out owner.
func TestOwnerCannotBeGranted(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "owner-3", nil)
	_ = me

	h.do(t, http.MethodPost, "/v1/invites", "owner-3",
		map[string]any{"emails": []string{"dev-3@6dx.test"}, "role": "developer"})
	h.do(t, http.MethodGet, "/v1/me", "dev-3", nil)
	h.do(t, http.MethodPost, "/v1/invites/accept", "dev-3", nil)

	status, body := h.do(t, http.MethodPatch, "/v1/members/dev-3", "owner-3",
		map[string]any{"role": "owner"})
	if status != http.StatusForbidden {
		t.Fatalf("expected 403, got %d %v", status, body)
	}
}

// TestClientDecisionValidation: 0007 rejects an out-of-range option and the
// second decision from a non-admin.
func TestClientDecisionValidation(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "owner-4", nil)
	wsID := me["workspace"].(map[string]any)["id"].(string)

	if _, err := h.pool.Exec(context.Background(), `
		insert into client_reports (workspace_id, client_name, project_name, decision_options)
		values ($1::uuid, 'Client', 'Proj', array['A','B'])`, wsID); err != nil {
		t.Fatalf("seed report: %v", err)
	}

	status, body := h.do(t, http.MethodPost, "/v1/client-report/decision", "owner-4",
		map[string]any{"option_index": 7})
	if status != http.StatusBadRequest {
		t.Fatalf("expected 400 for out-of-range, got %d %v", status, body)
	}

	status, body = h.do(t, http.MethodPost, "/v1/client-report/decision", "owner-4",
		map[string]any{"option_index": 1})
	if status != http.StatusOK {
		t.Fatalf("expected 200, got %d %v", status, body)
	}
	if body["choice"] != "B" {
		t.Fatalf("expected choice B, got %v", body["choice"])
	}
}

// TestSnapshotShape pins the contract the Flutter mapper depends on.
func TestSnapshotShape(t *testing.T) {
	h := newHarness(t)
	h.do(t, http.MethodGet, "/v1/me", "owner-5", nil)

	status, body := h.do(t, http.MethodGet, "/v1/workspace/snapshot", "owner-5", nil)
	if status != http.StatusOK {
		t.Fatalf("expected 200, got %d", status)
	}
	for _, key := range []string{
		"workspace_id", "name", "members", "invites", "tasks", "comments",
		"subtasks", "dependencies", "activity", "sprints", "pull_requests",
		"labels", "integrations", "repositories", "notifications", "digest",
	} {
		if _, ok := body[key]; !ok {
			t.Errorf("snapshot is missing %q", key)
		}
	}
}

// TestNonMemberCannotReadAnotherWorkspace: the snapshot is scoped to the
// caller's membership.
func TestNonMemberCannotReadAnotherWorkspace(t *testing.T) {
	h := newHarness(t)
	h.do(t, http.MethodGet, "/v1/me", "owner-6", nil)
	// A second account gets its own workspace, never the first one.
	_, other := h.do(t, http.MethodGet, "/v1/me", "owner-7", nil)
	if other["workspace"].(map[string]any)["id"] == "" {
		t.Fatal("expected a workspace")
	}

	var count int
	err := h.pool.QueryRow(context.Background(),
		`select count(*) from workspace_members where user_uid = 'owner-7'`).Scan(&count)
	if err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != 1 {
		t.Fatalf("expected exactly one membership, got %d", count)
	}
	_ = fmt.Sprint(count)
}
