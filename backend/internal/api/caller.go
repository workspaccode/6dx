package api

import (
	"net/http"

	"github.com/workspaccode/6dx/backend/internal/auth"
	"github.com/workspaccode/6dx/backend/internal/httpx"
)

// callerAndUpsert resolves the caller and mirrors the identity into `users`.
// The invite endpoints need the e-mail, which only the token carries.
func (s *Server) callerAndUpsert(r *http.Request) (*auth.Caller, error) {
	caller, err := auth.FromContext(r.Context())
	if err != nil {
		return nil, httpx.Unauthorized("سجّل الدخول أولاً.")
	}
	if err := s.store.upsertUser(r.Context(), caller); err != nil {
		return nil, err
	}
	return caller, nil
}
