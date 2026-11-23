package api

import (
	"context"
	"log/slog"
	"net/http"
	"strings"
)

// githubRevoker is what the real verifier adds on top of Verifier: revoking a
// token at GitHub and dropping cached grants. The test fake does not have it.
type githubRevoker interface {
	RevokeGitHubToken(ctx context.Context, token string) error
	EvictGitHubUser(githubID int64)
}

// POST /v1/auth/signout — the device's token is revoked at GitHub, so signing
// out really ends it (a copy left in a backup or a stolen phone stops
// working). The app clears its own storage whatever the answer: a failed
// revoke is reported, never a reason to keep the user signed in.
func (s *Server) handleSignOut(w http.ResponseWriter, r *http.Request) {
	token := strings.TrimSpace(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "))
	revoker, ok := s.verifier.(githubRevoker)
	if !ok || token == "" {
		writeJSON(w, http.StatusOK, map[string]bool{"revoked": false})
		return
	}
	if err := revoker.RevokeGitHubToken(r.Context(), token); err != nil {
		slog.Warn("sign-out revoke failed", "error", err)
		writeJSON(w, http.StatusOK, map[string]bool{"revoked": false})
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"revoked": true})
}
