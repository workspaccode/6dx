package auth

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// newGitHubVerifier builds a verifier whose GitHub host is a stub, so no test
// ever reaches the network.
func newGitHubVerifier(t *testing.T, handler http.HandlerFunc) *Verifier {
	t.Helper()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Every grant goes through the app check first; answer it for the
		// tests that only care about the profile.
		if r.Method == http.MethodPost && r.URL.Path == "/applications/"+testClientID+"/token" {
			if appCheck != nil {
				appCheck(w, r)
				return
			}
			user, pass, _ := r.BasicAuth()
			if user != testClientID || pass != testClientSecret {
				http.Error(w, "bad app credentials", http.StatusUnauthorized)
				return
			}
			_ = json.NewEncoder(w).Encode(map[string]any{
				"app":  map[string]any{"client_id": testClientID},
				"user": map[string]any{"id": checkUserID},
			})
			return
		}
		handler(w, r)
	}))
	t.Cleanup(server.Close)
	v := &Verifier{
		githubAPIBase: server.URL,
		httpClient:    server.Client(),
		cache:         make(map[string]githubGrant),
	}
	v.SetGitHubApp(testClientID, testClientSecret)
	return v
}

const (
	testClientID     = "Ov23liTestClientId"
	testClientSecret = "test-secret"
)

// checkUserID is the GitHub id the stub app check reports; appCheck, when set,
// replaces the stub answer entirely.
var (
	checkUserID int64 = 4711
	appCheck    http.HandlerFunc
)

func TestLooksLikeJWT(t *testing.T) {
	cases := map[string]bool{
		"eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxIn0.c2ln": true,
		"gho_16C7e42F292c6912E7710c838347Ae178B4a":  false,
		"":        false,
		"a.b":     false,
		"a.b.c.d": false,
	}
	for token, want := range cases {
		if got := looksLikeJWT(token); got != want {
			t.Errorf("looksLikeJWT(%q) = %v, want %v", token, got, want)
		}
	}
}

func TestVerifyGitHubGrantBuildsTheFirebaseCompatibleCaller(t *testing.T) {
	var sawAuth string
	verifier := newGitHubVerifier(t, func(w http.ResponseWriter, r *http.Request) {
		sawAuth = r.Header.Get("Authorization")
		switch r.URL.Path {
		case "/user":
			_ = json.NewEncoder(w).Encode(map[string]any{
				"id":         4711,
				"login":      "sami",
				"name":       "",
				"email":      "",
				"avatar_url": "https://example.test/a.png",
			})
		case "/user/emails":
			_ = json.NewEncoder(w).Encode([]map[string]any{
				{"email": "other@example.test", "primary": false, "verified": true},
				{"email": "sami@example.test", "primary": true, "verified": true},
			})
		default:
			http.NotFound(w, r)
		}
	})

	caller, err := verifier.Verify(context.Background(), "gho_devicegrant")
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}

	// The Firebase UID of a GitHub account is the numeric GitHub id, so the
	// device flow and the old Firebase sessions resolve to one user row.
	if caller.UID != "4711" {
		t.Errorf("UID = %q, want the GitHub id as a string", caller.UID)
	}
	if caller.GitHubID == nil || *caller.GitHubID != 4711 {
		t.Errorf("GitHubID = %v, want 4711", caller.GitHubID)
	}
	if caller.Email != "sami@example.test" {
		t.Errorf("Email = %q, want the verified primary address", caller.Email)
	}
	if caller.DisplayName != "sami" {
		t.Errorf("DisplayName = %q, want the login as the fallback", caller.DisplayName)
	}
	if sawAuth != "Bearer gho_devicegrant" {
		t.Errorf("Authorization header = %q", sawAuth)
	}
}

func TestVerifyGitHubGrantCachesTheProfile(t *testing.T) {
	calls := 0
	verifier := newGitHubVerifier(t, func(w http.ResponseWriter, r *http.Request) {
		calls++
		if r.URL.Path == "/user" {
			_ = json.NewEncoder(w).Encode(map[string]any{"id": 4711, "login": "sami"})
			return
		}
		_ = json.NewEncoder(w).Encode([]any{})
	})

	if _, err := verifier.Verify(context.Background(), "gho_cached"); err != nil {
		t.Fatalf("Verify: %v", err)
	}
	first := calls
	for i := 0; i < 3; i++ {
		if _, err := verifier.Verify(context.Background(), "gho_cached"); err != nil {
			t.Fatalf("Verify: %v", err)
		}
	}
	if calls != first {
		t.Errorf("GitHub was called %d more times, want 0 (the grant is cached)", calls-first)
	}
}

func TestVerifyGitHubGrantRejectsATokenFromAnotherApp(t *testing.T) {
	appCheck = func(w http.ResponseWriter, r *http.Request) { http.NotFound(w, r) }
	t.Cleanup(func() { appCheck = nil })
	verifier := newGitHubVerifier(t, func(w http.ResponseWriter, r *http.Request) {
		t.Errorf("profile must not be fetched for a foreign grant (%s)", r.URL.Path)
	})

	if _, err := verifier.Verify(context.Background(), "ghp_personal_access_token"); err == nil {
		t.Fatal("a token not issued to this app must be rejected")
	}
}

func TestVerifyGitHubGrantRejectsAMismatchedClientID(t *testing.T) {
	appCheck = func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{
			"app":  map[string]any{"client_id": "someone-else"},
			"user": map[string]any{"id": 4711},
		})
	}
	t.Cleanup(func() { appCheck = nil })
	verifier := newGitHubVerifier(t, func(w http.ResponseWriter, r *http.Request) {})

	if _, err := verifier.Verify(context.Background(), "gho_other"); err == nil {
		t.Fatal("a grant reported for another client id must be rejected")
	}
}

func TestVerifyGitHubGrantFailsClosedWithoutAppCredentials(t *testing.T) {
	verifier := newGitHubVerifier(t, func(w http.ResponseWriter, r *http.Request) {})
	verifier.SetGitHubApp("", "")

	if _, err := verifier.Verify(context.Background(), "gho_any"); err == nil {
		t.Fatal("without app credentials no grant may be accepted")
	}
}

func TestVerifyGitHubGrantIgnoresUnverifiedEmail(t *testing.T) {
	verifier := newGitHubVerifier(t, func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/user":
			_ = json.NewEncoder(w).Encode(map[string]any{
				"id": 4711, "login": "mallory", "email": "victim@company.test",
			})
		case "/user/emails":
			_ = json.NewEncoder(w).Encode([]map[string]any{
				{"email": "victim@company.test", "primary": true, "verified": false},
			})
		}
	})

	caller, err := verifier.Verify(context.Background(), "gho_unverified")
	if err != nil {
		t.Fatalf("Verify: %v", err)
	}
	if caller.Email != "" {
		t.Errorf("Email = %q, want empty for an unverified address", caller.Email)
	}
}

func TestVerifyGitHubGrantRejectsARevokedToken(t *testing.T) {
	verifier := newGitHubVerifier(t, func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, `{"message":"Bad credentials"}`, http.StatusUnauthorized)
	})

	if _, err := verifier.Verify(context.Background(), "gho_revoked"); err == nil {
		t.Fatal("expected an error for a rejected grant")
	}
}

func TestCachedGrantsExpire(t *testing.T) {
	verifier := newGitHubVerifier(t, func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]any{"id": 9, "login": "sami"})
	})

	key := hashToken("gho_expiring")
	verifier.store(key, &Caller{UID: "9"})
	if _, ok := verifier.cached(key); !ok {
		t.Fatal("a fresh grant must be cached")
	}

	verifier.mu.Lock()
	verifier.cache[key] = githubGrant{
		caller:  &Caller{UID: "9"},
		expires: time.Now().Add(-time.Second),
	}
	verifier.mu.Unlock()

	if _, ok := verifier.cached(key); ok {
		t.Fatal("an expired grant must not be served from the cache")
	}
}

func TestMiddlewareRejectsAMissingHeader(t *testing.T) {
	verifier := newGitHubVerifier(t, func(w http.ResponseWriter, r *http.Request) {})

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/v1/me", nil)
	verifier.Middleware(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Fatal("the handler must not run without a token")
	})).ServeHTTP(recorder, request)

	if recorder.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", recorder.Code)
	}
	if !strings.Contains(recorder.Body.String(), "unauthorized") {
		t.Errorf("body = %q", recorder.Body.String())
	}
}
