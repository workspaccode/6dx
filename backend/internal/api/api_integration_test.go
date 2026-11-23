//go:build integration

// Integration tests for the authorization layer — the Go port of the RLS
// policies. They need nothing but a temp file: SQLite is embedded.
//
//	go test -tags=integration ./internal/api/ -v
package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"

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
	server   *httptest.Server
	database *db.DB
}

func newHarness(t *testing.T) *harness {
	t.Helper()

	path := filepath.Join(t.TempDir(), "test.db")
	ctx := context.Background()
	database, err := db.Open(ctx, path)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	if err := db.Migrate(ctx, database); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	cfg := &config.Config{ProjectID: "test", CORSOrigins: []string{"*"}}
	srv := New(cfg, database, fakeVerifier{})
	ts := httptest.NewServer(srv.Handler())
	t.Cleanup(func() {
		ts.Close()
		database.Close()
	})
	return &harness{server: ts, database: database}
}

func (h *harness) do(t *testing.T, method, path, uid string, body any) (int, map[string]any) {
	return h.doWithWorkspace(t, method, path, uid, "", body)
}

func (h *harness) doWithWorkspace(
	t *testing.T,
	method, path, uid, workspaceID string,
	body any,
) (int, map[string]any) {
	t.Helper()
	payload := ""
	if body != nil {
		encoded, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal: %v", err)
		}
		payload = string(encoded)
	}
	request, err := http.NewRequest(method, h.server.URL+path, strings.NewReader(payload))
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

	var decoded map[string]any
	_ = json.NewDecoder(response.Body).Decode(&decoded)
	return response.StatusCode, decoded
}

func workspaceOf(t *testing.T, body map[string]any) string {
	t.Helper()
	workspace, ok := body["workspace"].(map[string]any)
	if !ok {
		t.Fatalf("no workspace in response: %v", body)
	}
	id, _ := workspace["id"].(string)
	if id == "" {
		t.Fatalf("empty workspace id: %v", workspace)
	}
	return id
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
	workspace := body["workspace"].(map[string]any)
	if workspace["role"] != "owner" {
		t.Fatalf("expected role owner, got %v", workspace["role"])
	}
	first := workspaceOf(t, body)

	// Second call must reuse the same workspace, not create another.
	_, again := h.do(t, http.MethodGet, "/v1/me", "owner-1", nil)
	if workspaceOf(t, again) != first {
		t.Fatal("workspace changed between calls")
	}

	var count int
	if err := h.database.QueryRowContext(context.Background(),
		`select count(*) from workspaces`).Scan(&count); err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != 1 {
		t.Fatalf("expected exactly one workspace, got %d", count)
	}
}

// TestViewerCannotWrite: 0004 made viewers read-only.
func TestViewerCannotWrite(t *testing.T) {
	h := newHarness(t)

	_, me := h.do(t, http.MethodGet, "/v1/me", "owner-2", nil)
	wsID := workspaceOf(t, me)

	if status, body := h.do(t, http.MethodPost, "/v1/invites", "owner-2",
		map[string]any{"emails": []string{"viewer-2@6dx.test"}, "role": "viewer"}); status != http.StatusCreated {
		t.Fatalf("invite failed: %d %v", status, body)
	}

	// The viewer signs in (getting their own workspace), then accepts.
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
}

// TestOwnerCannotBeGranted: only a transfer hands out owner.
func TestOwnerCannotBeGranted(t *testing.T) {
	h := newHarness(t)
	h.do(t, http.MethodGet, "/v1/me", "owner-3", nil)

	h.do(t, http.MethodPost, "/v1/invites", "owner-3",
		map[string]any{"emails": []string{"dev-3@6dx.test"}, "role": "developer"})
	h.do(t, http.MethodGet, "/v1/me", "dev-3", nil)
	h.do(t, http.MethodPost, "/v1/invites/accept", "dev-3", nil)

	status, body := h.do(t, http.MethodPatch, "/v1/members/dev-3", "owner-3",
		map[string]any{"role": "owner"})
	if status != http.StatusForbidden {
		t.Fatalf("expected 403, got %d %v", status, body)
	}
	if body["error"] != "owner_not_assignable" {
		t.Fatalf("expected owner_not_assignable, got %v", body["error"])
	}
}

// TestClientDecisionValidation: 0007 rejects an out-of-range option and the
// second decision from a non-admin.
func TestClientDecisionValidation(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "owner-4", nil)
	wsID := workspaceOf(t, me)

	if _, err := h.database.ExecContext(context.Background(), `
		insert into client_reports
		  (id, workspace_id, client_name, project_name, decision_options,
		   weekly_highlights, invoice_lines, delivered_items)
		values (?, ?, 'Client', 'Proj', '["A","B"]', '[]', '[]', '[]')`,
		newID(), wsID); err != nil {
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
		"client_report",
	} {
		if _, ok := body[key]; !ok {
			t.Errorf("snapshot is missing %q", key)
		}
	}
	if body["workspace_id"] == "" {
		t.Error("snapshot has an empty workspace_id")
	}
}

// TestTasksRoundTrip: create, list, change status, delete.
func TestTasksRoundTrip(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "owner-6", nil)
	wsID := workspaceOf(t, me)

	status, body := h.do(t, http.MethodPost, "/v1/tasks", "owner-6",
		map[string]any{"title": "First task"})
	if status != http.StatusCreated {
		t.Fatalf("create failed: %d %v", status, body)
	}
	task := body["task"].(map[string]any)
	taskID := task["id"].(string)

	_, list := h.do(t, http.MethodGet, "/v1/tasks", "owner-6", nil)
	tasks, _ := list["tasks"].([]any)
	if len(tasks) != 1 {
		t.Fatalf("expected one task, got %d", len(tasks))
	}

	status, body = h.do(t, http.MethodPatch, "/v1/tasks/"+taskID+"/status", "owner-6",
		map[string]any{"status": "done"})
	if status != http.StatusOK {
		t.Fatalf("status change failed: %d %v", status, body)
	}
	if body["task"].(map[string]any)["status"] != "done" {
		t.Fatalf("expected done, got %v", body["task"])
	}

	if status, body := h.do(t, http.MethodDelete, "/v1/tasks/"+taskID, "owner-6", nil); status != http.StatusOK {
		t.Fatalf("delete failed: %d %v", status, body)
	}
	_ = wsID
}

// TestTwoAccountsGetSeparateWorkspaces: a second account never lands in the
// first one's workspace.
func TestTwoAccountsGetSeparateWorkspaces(t *testing.T) {
	h := newHarness(t)
	_, first := h.do(t, http.MethodGet, "/v1/me", "owner-7", nil)
	_, second := h.do(t, http.MethodGet, "/v1/me", "owner-8", nil)

	if workspaceOf(t, first) == workspaceOf(t, second) {
		t.Fatal("two accounts share a workspace")
	}

	// And an unknown workspace id in the header is refused, not silently
	// redirected to the caller's own workspace.
	status, body := h.doWithWorkspace(t, http.MethodGet, "/v1/tasks",
		"owner-8", workspaceOf(t, first), nil)
	if status != http.StatusForbidden {
		t.Fatalf("expected 403 for a foreign workspace, got %d %v", status, body)
	}
}

// TestMarkAllNotificationsRead covers the "تعليم الكل كمقروء" action.
func TestMarkAllNotificationsRead(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "owner-9", nil)
	wsID := workspaceOf(t, me)

	if _, err := h.database.ExecContext(context.Background(), `
		insert into notifications (id, workspace_id, user_uid, kind, title, body, is_read, created_at)
		values (?, ?, 'owner-9', 'review', 't', 'b', 0, ?)`,
		newID(), wsID, nowString()); err != nil {
		t.Fatalf("seed: %v", err)
	}

	status, body := h.do(t, http.MethodPost, "/v1/notifications/read-all", "owner-9", nil)
	if status != http.StatusOK {
		t.Fatalf("expected 200, got %d %v", status, body)
	}
	if updated, _ := body["updated"].(float64); updated != 1 {
		t.Fatalf("expected one notification updated, got %v", body["updated"])
	}
}

// A new task can carry its assignee, points and due date; the assignee
// must belong to the task's group.
func TestCreateTaskWithAssignee(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "ct-lead", nil)
	ws := workspaceOf(t, me)
	_, created := createGroup(t, h, "ct-lead", ws, "App", "software")
	gid := groupIDOf(t, created)
	joinGroupAs(t, h, "ct-lead", ws, gid, "ct-dev", "member", "developer")
	joinAs(t, h, "ct-lead", "ct-outsider", "developer")
	_, project := h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "ct-lead", ws, map[string]any{"name": "P", "group_id": gid})
	pid := project["project"].(map[string]any)["id"]

	status, body := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks", "ct-lead", ws, map[string]any{
		"title": "Pay", "project_id": pid, "assignee_uid": "ct-dev", "points": 5, "due_at": "2026-12-31",
	})
	if status != http.StatusCreated {
		t.Fatalf("create: %d %v", status, body)
	}
	task := body["task"].(map[string]any)
	if task["assignee_uid"] != "ct-dev" || task["due_at"] != "2026-12-31" {
		t.Errorf("task: %v", task)
	}
	for _, bad := range []map[string]any{
		{"title": "x", "project_id": pid, "assignee_uid": "ct-outsider"},
		{"title": "x", "project_id": pid, "points": 500},
		{"title": "x", "project_id": pid, "due_at": "soon"},
	} {
		if status, _ := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks", "ct-lead", ws, bad); status != http.StatusBadRequest {
			t.Errorf("accepted %v: %d", bad, status)
		}
	}
}

// Comments and subtasks are written through their own endpoints and come
// back in the snapshot; a group's rules guard them.
func TestTaskCommentsAndSubtasks(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "cs-lead", nil)
	ws := workspaceOf(t, me)
	_, created := createGroup(t, h, "cs-lead", ws, "App", "software")
	gid := groupIDOf(t, created)
	joinGroupAs(t, h, "cs-lead", ws, gid, "cs-client", "guest", "client")
	joinAs(t, h, "cs-lead", "cs-outsider", "developer")
	_, project := h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "cs-lead", ws, map[string]any{"name": "P", "group_id": gid})
	_, task := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks", "cs-lead", ws,
		map[string]any{"title": "T", "project_id": project["project"].(map[string]any)["id"]})
	tid := task["task"].(map[string]any)["id"].(string)

	// The client follows progress read-only (matrix §4.5): no comments.
	if status, _ := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks/"+tid+"/comments", "cs-client", ws, map[string]any{"body": "متى؟"}); status != 403 {
		t.Errorf("client comment: %d, want 403", status)
	}
	if status, _ := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks/"+tid+"/comments", "cs-lead", ws, map[string]any{"body": "تمام"}); status != 201 {
		t.Errorf("lead comment: %d", status)
	}
	if status, _ := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks/"+tid+"/comments", "cs-outsider", ws, map[string]any{"body": "x"}); status != 404 {
		t.Errorf("outsider comment: %d, want 404", status)
	}
	if status, _ := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks/"+tid+"/comments", "cs-lead", ws, map[string]any{"body": " "}); status != 400 {
		t.Errorf("empty comment: %d", status)
	}
	if status, _ := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks/"+tid+"/subtasks", "cs-client", ws, map[string]any{"title": "x"}); status != 403 {
		t.Errorf("client subtask: %d, want 403", status)
	}
	_, sub := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks/"+tid+"/subtasks", "cs-lead", ws, map[string]any{"title": "Step 1"})
	sid := sub["subtask"].(map[string]any)["id"].(string)
	if status, _ := h.doWithWorkspace(t, http.MethodPatch, "/v1/subtasks/"+sid, "cs-lead", ws, map[string]any{"done": true}); status != 200 {
		t.Errorf("toggle: %d", status)
	}
	_, snap := h.doInGroup(t, http.MethodGet, "/v1/workspace/snapshot", "cs-lead", ws, gid, nil)
	if len(snap["comments"].([]any)) != 1 || len(snap["subtasks"].([]any)) != 1 ||
		snap["subtasks"].([]any)[0].(map[string]any)["is_done"] != true {
		t.Errorf("snapshot comments/subtasks: %v %v", snap["comments"], snap["subtasks"])
	}
}
