//go:build integration

// Tests for the GitHub device-flow proxy the app signs in through.
//
//	go test -tags=integration ./internal/api/ -run Device
package api

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"

	"github.com/workspaccode/6dx/backend/internal/config"
	"github.com/workspaccode/6dx/backend/internal/db"
)

// newDeviceFlowServer wires the API against a stub github.com, so these tests
// never reach the network.
func newDeviceFlowServer(
	t *testing.T,
	clientID string,
	githubHandler http.HandlerFunc,
) *httptest.Server {
	t.Helper()

	ctx := context.Background()
	database, err := db.Open(ctx, filepath.Join(t.TempDir(), "auth.db"))
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	if err := db.Migrate(ctx, database); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	cfg := &config.Config{
		ProjectID:      "test",
		CORSOrigins:    []string{"*"},
		GitHubClientID: clientID,
	}
	srv := New(cfg, database, fakeVerifier{})

	if githubHandler != nil {
		github := httptest.NewServer(githubHandler)
		t.Cleanup(github.Close)
		srv.githubOAuthBase = github.URL
	}

	api := httptest.NewServer(srv.Handler())
	t.Cleanup(func() {
		api.Close()
		database.Close()
	})
	return api
}

func TestDeviceCodeIsProxiedWithTheServerClientID(t *testing.T) {
	var seenForm string
	api := newDeviceFlowServer(t, "Ov23liTestClientId",
		func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path != "/login/device/code" {
				t.Errorf("path = %q", r.URL.Path)
			}
			_ = r.ParseForm()
			seenForm = r.PostForm.Encode()
			_, _ = w.Write([]byte(`{"device_code":"dev","user_code":"ABCD-1234",` +
				`"verification_uri":"https://github.com/login/device",` +
				`"expires_in":900,"interval":5}`))
		})

	response, err := http.Post(api.URL+"/auth/github/device-code", "application/json", nil)
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer func() { _ = response.Body.Close() }()

	if response.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", response.StatusCode)
	}
	var body map[string]any
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body["user_code"] != "ABCD-1234" {
		t.Errorf("user_code = %v", body["user_code"])
	}
	if !strings.Contains(seenForm, "client_id=Ov23liTestClientId") {
		t.Errorf("GitHub saw %q, want the server client id", seenForm)
	}
	if !strings.Contains(seenForm, "scope=read%3Auser+user%3Aemail") {
		t.Errorf("GitHub saw %q, want the identity scopes", seenForm)
	}
}

func TestDeviceTokenPassesPendingAnswersThrough(t *testing.T) {
	api := newDeviceFlowServer(t, "Ov23liTestClientId",
		func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path != "/login/oauth/access_token" {
				t.Errorf("path = %q", r.URL.Path)
			}
			// `authorization_pending` is a normal answer while the user has not
			// confirmed the code yet; the client polls again.
			_, _ = w.Write([]byte(`{"error":"authorization_pending"}`))
		})

	response, err := http.Post(
		api.URL+"/auth/github/device-token",
		"application/json",
		strings.NewReader(`{"device_code":"dev-123"}`),
	)
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer func() { _ = response.Body.Close() }()

	var body map[string]any
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body["error"] != "authorization_pending" {
		t.Errorf("error = %v, want the pending answer passed through", body["error"])
	}
}

func TestDeviceCodeFailsClearlyWithoutAClientID(t *testing.T) {
	api := newDeviceFlowServer(t, "", nil)

	response, err := http.Post(api.URL+"/auth/github/device-code", "application/json", nil)
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer func() { _ = response.Body.Close() }()

	if response.StatusCode != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want 503", response.StatusCode)
	}
}

func TestDeviceCodeAllowsTheWebOrigin(t *testing.T) {	api := newDeviceFlowServer(t, "Ov23liTestClientId",
		func(w http.ResponseWriter, r *http.Request) {
			_, _ = w.Write([]byte(`{"device_code":"dev","user_code":"ABCD-1234"}`))
		})

	request, err := http.NewRequest(http.MethodPost, api.URL+"/auth/github/device-code", nil)
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	request.Header.Set("Origin", "http://localhost:8081")
	request.Header.Set("Content-Type", "application/json")

	response, err := http.DefaultClient.Do(request)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer func() { _ = response.Body.Close() }()

	// Without this header the Flutter web build cannot read the answer, which
	// is the whole reason the proxy exists. The server echoes the allowed
	// origin (it never answers `*` for a credentialed client).
	if got := response.Header.Get("Access-Control-Allow-Origin"); got != "http://localhost:8081" {
		t.Errorf("Access-Control-Allow-Origin = %q, want the request origin", got)
	}
}
