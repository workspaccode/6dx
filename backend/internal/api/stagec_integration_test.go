//go:build integration

package api

import (
	"io"
	"net/http"
	"net/url"
	"strings"
	"testing"
	"time"
)

// Stage C: a GitHub connect state is accepted by one callback only.
func TestGithubStateIsSingleUse(t *testing.T) {
	h, srv := newGitHubServer(t)
	state := srv.github.signState("ws", "uid", 4242, time.Now())
	callback := func() string {
		resp, err := http.Get(h.server.URL + "/github/callback?code=abc&state=" + url.QueryEscape(state))
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		return string(body)
	}
	if first := callback(); strings.Contains(first, "اتستخدم") {
		t.Fatalf("first callback refused as used: %s", first)
	}
	if second := callback(); !strings.Contains(second, "اتستخدم") {
		t.Errorf("replayed state accepted: %s", second)
	}
	recovery := srv.github.signRecovery(4242)
	for i, want := range []bool{false, true} {
		resp, _ := http.Get(h.server.URL + "/github/callback?code=abc&state=" + url.QueryEscape(recovery))
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		if got := strings.Contains(string(body), "اتستخدم"); got != want {
			t.Errorf("recovery callback %d: used=%v, want %v", i, got, want)
		}
	}
}

// Sign-out answers even when the verifier cannot revoke (the app clears its
// storage either way).
func TestSignOutRoute(t *testing.T) {
	h := newHarness(t)
	status, body := h.do(t, http.MethodPost, "/v1/auth/signout", "so-user", nil)
	if status != http.StatusOK || body["revoked"] != false {
		t.Errorf("signout: %d %v", status, body)
	}
}

// /github/setup spends the app's state when it re-signs it.
func TestGithubSetupSpendsState(t *testing.T) {
	h, srv := newGitHubServer(t)
	state := srv.github.signState("ws", "uid", 0, time.Now())
	client := &http.Client{CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	setup := func() (int, string) {
		resp, err := client.Get(h.server.URL + "/github/setup?installation_id=4242&state=" + url.QueryEscape(state))
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		return resp.StatusCode, string(body)
	}
	if status, _ := setup(); status != http.StatusFound {
		t.Fatalf("first setup: %d, want a redirect to GitHub", status)
	}
	if _, body := setup(); !strings.Contains(body, "اتستخدم") {
		t.Errorf("state re-signed twice: %s", body)
	}
}
