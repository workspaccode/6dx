//go:build integration

// The GitHub device flow reports the numeric GitHub id as the uid. Accounts
// created by the old Firebase sign-in have a random uid and keep the GitHub
// account in `users.github_id`, so the API has to map the sign-in onto the
// stored row or the user would lose every workspace.
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

// githubVerifier mimics a device-flow grant: the header carries the GitHub
// account id, and the caller it builds looks exactly like the real verifier's.
type githubVerifier struct{}

func (githubVerifier) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		raw := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer gh:")
		if raw == "" || raw == r.Header.Get("Authorization") {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		var githubID int64
		for _, digit := range raw {
			githubID = githubID*10 + int64(digit-'0')
		}
		next.ServeHTTP(w, r.WithContext(auth.WithCaller(r.Context(), &auth.Caller{
			UID:         raw,
			Email:       "sami@example.test",
			DisplayName: "Sami",
			GitHubID:    &githubID,
		})))
	})
}

func TestDeviceFlowBindsToTheStoredAccount(t *testing.T) {
	ctx := context.Background()
	database, err := db.Open(ctx, filepath.Join(t.TempDir(), "identity.db"))
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	t.Cleanup(func() { database.Close() })
	if err := db.Migrate(ctx, database); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	// The account the previous Firebase sign-in created: random uid, GitHub
	// account kept in github_id.
	const legacyUID = "cEVIahLegacyFirebaseUid"
	if _, err := database.ExecContext(ctx, `
		insert into users (uid, email, display_name, github_id, created_at, updated_at)
		values (?, 'sami@example.test', 'Sami', 201337285, '2024-01-01', '2024-01-01')`,
		legacyUID,
	); err != nil {
		t.Fatalf("seed user: %v", err)
	}

	server := New(&config.Config{ProjectID: "test", CORSOrigins: []string{"*"}},
		database, githubVerifier{})
	api := httptest.NewServer(server.Handler())
	t.Cleanup(api.Close)

	request, err := http.NewRequest(http.MethodGet, api.URL+"/v1/me", nil)
	if err != nil {
		t.Fatalf("request: %v", err)
	}
	request.Header.Set("Authorization", "Bearer gh:201337285")

	response, err := http.DefaultClient.Do(request)
	if err != nil {
		t.Fatalf("do: %v", err)
	}
	defer func() { _ = response.Body.Close() }()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("status = %d, want 200", response.StatusCode)
	}

	var body struct {
		User struct {
			UID string `json:"uid"`
		} `json:"user"`
	}
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body.User.UID != legacyUID {
		t.Errorf("uid = %q, want the stored %q", body.User.UID, legacyUID)
	}

	// And no second account was created for the same GitHub user.
	var count int
	if err := database.QueryRowContext(ctx,
		`select count(*) from users where github_id = 201337285`,
	).Scan(&count); err != nil {
		t.Fatalf("count: %v", err)
	}
	if count != 1 {
		t.Errorf("users with that GitHub id = %d, want 1", count)
	}
}
