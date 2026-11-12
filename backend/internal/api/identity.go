package api

import (
	"context"
	"net/http"

	"github.com/workspaccode/6dx/backend/internal/auth"
)

// withStoredIdentity binds a GitHub sign-in to the account that is already
// stored for that GitHub id.
//
// The old sign-in went through Firebase, which mints a random `uid` and keeps
// the GitHub account in `users.github_id`. A device-flow grant has no Firebase
// uid at all, so the verifier can only offer the numeric GitHub id; resolving
// the stored uid here means an existing account keeps its workspaces, projects
// and membership instead of being created a second time.
func (s *Server) withStoredIdentity(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		caller, err := auth.FromContext(r.Context())
		if err != nil || caller.GitHubID == nil {
			next.ServeHTTP(w, r)
			return
		}
		uid, err := s.store.userUIDByGitHubID(r.Context(), *caller.GitHubID)
		if err != nil || uid == "" || uid == caller.UID {
			next.ServeHTTP(w, r)
			return
		}
		bound := *caller
		bound.UID = uid
		next.ServeHTTP(w, r.WithContext(auth.WithCaller(r.Context(), &bound)))
	})
}

// userUIDByGitHubID returns the uid stored for a GitHub account, or "" when the
// account has never signed in.
func (s *store) userUIDByGitHubID(ctx context.Context, githubID int64) (string, error) {
	var uid string
	err := s.db.QueryRowContext(ctx,
		`select uid from users where github_id = ? order by created_at limit 1`,
		githubID,
	).Scan(&uid)
	if err != nil {
		return "", nil
	}
	return uid, nil
}
