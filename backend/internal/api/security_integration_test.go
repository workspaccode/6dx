//go:build integration

// Regression tests for the security fixes in docs/review (second pass).
package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/workspaccode/6dx/backend/internal/config"
)

// joinAs invites uid into owner's workspace with role and accepts it.
func joinAs(t *testing.T, h *harness, owner, uid, role string) {
	t.Helper()
	if status, body := h.do(t, http.MethodPost, "/v1/invites", owner,
		map[string]any{"emails": []string{uid + "@6dx.test"}, "role": role}); status != http.StatusCreated {
		t.Fatalf("invite %s: %d %v", uid, status, body)
	}
	h.do(t, http.MethodGet, "/v1/me", uid, nil)
	if status, body := h.do(t, http.MethodPost, "/v1/invites/accept", uid, nil); status != http.StatusOK {
		t.Fatalf("accept %s: %d %v", uid, status, body)
	}
}

func seedClientReport(t *testing.T, h *harness, wsID string) {
	t.Helper()
	if _, err := h.database.ExecContext(context.Background(), `
		insert into client_reports
		  (id, workspace_id, client_name, project_name, decision_options,
		   weekly_highlights, invoice_lines, delivered_items, hourly_rate, invoice_number)
		values (?, ?, 'Client', 'Proj', '["A","B"]', '[]', '["line"]', '[]', '45', 'INV-1')`,
		newID(), wsID); err != nil {
		t.Fatalf("seed report: %v", err)
	}
}

// 03 #15: a developer must not be able to record the client's decision.
func TestOnlyTheClientRecordsTheDecision(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "owner-s1", nil)
	wsID := workspaceOf(t, me)
	seedClientReport(t, h, wsID)
	joinAs(t, h, "owner-s1", "dev-s1", "developer")
	joinAs(t, h, "owner-s1", "client-s1", "viewer")

	status, body := h.doWithWorkspace(t, http.MethodPost, "/v1/client-report/decision",
		"dev-s1", wsID, map[string]any{"option_index": 0})
	if status != http.StatusForbidden || body["error"] != "client_decision_only" {
		t.Fatalf("developer decision: got %d %v, want 403 client_decision_only", status, body)
	}

	status, body = h.doWithWorkspace(t, http.MethodPost, "/v1/client-report/decision",
		"client-s1", wsID, map[string]any{"option_index": 1})
	if status != http.StatusOK || body["choice"] != "B" {
		t.Fatalf("client decision: got %d %v", status, body)
	}

	// The second decision from the client is refused; an admin may correct it.
	status, _ = h.doWithWorkspace(t, http.MethodPost, "/v1/client-report/decision",
		"client-s1", wsID, map[string]any{"option_index": 0})
	if status != http.StatusConflict {
		t.Fatalf("second client decision: got %d, want 409", status)
	}
	status, _ = h.doWithWorkspace(t, http.MethodPost, "/v1/client-report/decision",
		"owner-s1", wsID, map[string]any{"option_index": 0})
	if status != http.StatusOK {
		t.Fatalf("admin override: got %d, want 200", status)
	}
}

// 03 #16: the client (viewer) sees no team e-mails, no invites; developers see
// no rates or invoices.
func TestSnapshotIsTrimmedByRole(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "owner-s2", nil)
	wsID := workspaceOf(t, me)
	seedClientReport(t, h, wsID)
	joinAs(t, h, "owner-s2", "dev-s2", "developer")
	joinAs(t, h, "owner-s2", "client-s2", "viewer")

	_, viewer := h.doWithWorkspace(t, http.MethodGet, "/v1/workspace/snapshot", "client-s2", wsID, nil)
	for _, raw := range viewer["members"].([]any) {
		if email := raw.(map[string]any)["email"]; email != nil {
			t.Errorf("viewer sees a member e-mail: %v", email)
		}
	}
	if invites := viewer["invites"].([]any); len(invites) != 0 {
		t.Errorf("viewer sees %d invites, want 0", len(invites))
	}
	if report := viewer["client_report"].(map[string]any); report["hourly_rate"] == nil {
		t.Error("the client must still see their own rate")
	}

	_, dev := h.doWithWorkspace(t, http.MethodGet, "/v1/workspace/snapshot", "dev-s2", wsID, nil)
	report := dev["client_report"].(map[string]any)
	if report["hourly_rate"] != nil || report["invoice_number"] != nil {
		t.Errorf("developer sees finance: rate=%v invoice=%v", report["hourly_rate"], report["invoice_number"])
	}
	if lines := report["invoice_lines"].([]any); len(lines) != 0 {
		t.Errorf("developer sees %d invoice lines", len(lines))
	}

	_, owner := h.doWithWorkspace(t, http.MethodGet, "/v1/workspace/snapshot", "owner-s2", wsID, nil)
	if invites := owner["invites"].([]any); len(invites) == 0 {
		t.Error("the owner must see the invites")
	}

	status, list := h.doWithWorkspace(t, http.MethodGet, "/v1/members", "client-s2", wsID, nil)
	if status != http.StatusOK {
		t.Fatalf("members: %d", status)
	}
	for _, raw := range list["members"].([]any) {
		if email := raw.(map[string]any)["email"]; email != nil {
			t.Errorf("viewer sees a member e-mail in /v1/members: %v", email)
		}
	}
}

// 03 #1: a state issued to one 6DX user is useless in another GitHub
// account's browser, and only workspace admins can be the target.
func TestGithubStateIsBoundToTheRequestingUser(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "attacker", nil)
	wsID := workspaceOf(t, me)
	joinAs(t, h, "attacker", "member-s3", "developer")

	ctx := context.Background()
	if _, err := h.database.ExecContext(ctx,
		`update users set github_id = 100 where uid = 'attacker'`); err != nil {
		t.Fatal(err)
	}
	if _, err := h.database.ExecContext(ctx,
		`update users set github_id = 300 where uid = 'member-s3'`); err != nil {
		t.Fatal(err)
	}

	s := &Server{store: &store{db: h.database}}
	request := httptest.NewRequest(http.MethodGet, "/github/callback", nil)
	attackerState := &statePayload{WorkspaceID: wsID, UserID: "attacker", IssuedAt: time.Now()}

	// The victim (GitHub id 200) completes the OAuth leg with the attacker's state.
	if _, _, ok := s.resolveGithubTarget(request, attackerState, true, 200); ok {
		t.Fatal("a state must not resolve for a different GitHub account")
	}
	// The attacker's own browser resolves.
	if ws, uid, ok := s.resolveGithubTarget(request, attackerState, true, 100); !ok || ws != wsID || uid != "attacker" {
		t.Fatalf("own state: got %q %q %v", ws, uid, ok)
	}
	// A developer of the workspace cannot attach an installation to it.
	memberState := &statePayload{WorkspaceID: wsID, UserID: "member-s3", IssuedAt: time.Now()}
	if _, _, ok := s.resolveGithubTarget(request, memberState, true, 300); ok {
		t.Fatal("a non-admin must not be able to target the workspace")
	}
}

// 03 #1 (second pass): re-signing at /github/setup keeps the original issue time.
func TestGithubStateCannotBeExtended(t *testing.T) {
	b := &githubBroker{cfg: &config.Config{GitHubStateSecret: "s"}}
	old := time.Now().Add(-stateTTL - time.Minute)
	expired := b.signState("ws", "uid", 0, old)
	if _, ok := b.verifyState(expired); ok {
		t.Fatal("an expired state must not verify")
	}

	fresh := b.signState("ws", "uid", 0, time.Now().Add(-stateTTL+time.Minute))
	state, ok := b.verifyState(fresh)
	if !ok {
		t.Fatal("a fresh state must verify")
	}
	resigned := b.signState(state.WorkspaceID, state.UserID, 42, state.IssuedAt)
	again, ok := b.verifyState(resigned)
	if !ok || !again.IssuedAt.Equal(state.IssuedAt) {
		t.Fatalf("re-signed state must keep the issue time: %v %v", again, ok)
	}
}

// 03 #5: webhooks are verified with the webhook secret, not the state secret,
// and a state signature is never a valid webhook signature.
func TestWebhookUsesItsOwnSecret(t *testing.T) {
	b := &githubBroker{cfg: &config.Config{GitHubStateSecret: "state", GitHubWebhookSecret: "hook"}}
	body := []byte(`{"action":"opened"}`)
	if b.webhookHMAC(body) == b.hmac(string(body)) {
		t.Fatal("webhook and state signatures must differ")
	}
	b2 := &githubBroker{cfg: &config.Config{GitHubStateSecret: "same", GitHubWebhookSecret: "same"}}
	if b2.webhookHMAC(body) == b2.hmac(string(body)) {
		t.Fatal("even with one secret the state signature is domain-separated")
	}
}

// 03 #14: one installation can only belong to one workspace.
func TestInstallationIsUniqueAcrossWorkspaces(t *testing.T) {
	h := newHarness(t)
	_, a := h.do(t, http.MethodGet, "/v1/me", "ws-a", nil)
	_, b := h.do(t, http.MethodGet, "/v1/me", "ws-b", nil)
	ctx := context.Background()
	insert := `insert into github_installations
		(id, workspace_id, installation_id, account_login, created_at)
		values (?, ?, 777, 'org', ?)`
	if _, err := h.database.ExecContext(ctx, insert, newID(), workspaceOf(t, a), nowString()); err != nil {
		t.Fatal(err)
	}
	if _, err := h.database.ExecContext(ctx, insert, newID(), workspaceOf(t, b), nowString()); err == nil {
		t.Fatal("a second workspace must not be able to hold the same installation")
	}
}

// 03 #17: the public device-token endpoint caps its body and never forwards
// an oversized code to GitHub.
func TestDeviceTokenRejectsAHugeBody(t *testing.T) {
	api := newDeviceFlowServer(t, "Ov23liTestClientId", func(w http.ResponseWriter, r *http.Request) {
		t.Error("an oversized body must not reach GitHub")
	})
	huge := `{"device_code":"` + strings.Repeat("a", 64<<10) + `"}`
	response, err := http.Post(api.URL+"/auth/github/device-token", "application/json", strings.NewReader(huge))
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != http.StatusBadRequest {
		t.Fatalf("huge device code: got %d, want 400", response.StatusCode)
	}
}

// 03 #17: sign-in endpoints are rate-limited per IP.
func TestDeviceCodeIsRateLimited(t *testing.T) {
	api := newDeviceFlowServer(t, "Ov23liTestClientId", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"device_code":"d","user_code":"U","verification_uri":"https://github.com/login/device"}`))
	})
	limited := false
	for i := 0; i < 40; i++ {
		response, err := http.Post(api.URL+"/auth/github/device-code", "application/json", nil)
		if err != nil {
			t.Fatal(err)
		}
		response.Body.Close()
		if response.StatusCode == http.StatusTooManyRequests {
			limited = true
			break
		}
	}
	if !limited {
		t.Fatal("40 device-code requests in a minute must hit the limit")
	}
}

// 03 #3: an e-mail already held by another user does not break sign-in.
func TestDuplicateEmailDoesNotBreakTheAccount(t *testing.T) {
	h := newHarness(t)
	h.do(t, http.MethodGet, "/v1/me", "first", nil)
	if _, err := h.database.ExecContext(context.Background(),
		`update users set email = 'second@6dx.test' where uid = 'first'`); err != nil {
		t.Fatal(err)
	}
	// fakeVerifier reports "second@6dx.test" for uid "second".
	if status, body := h.do(t, http.MethodGet, "/v1/me", "second", nil); status != http.StatusOK {
		t.Fatalf("sign-in with a taken e-mail: got %d %v, want 200", status, body)
	}
}
