package api

import (
	"net/http"

	"github.com/workspaccode/6dx/backend/internal/auth"
	"github.com/workspaccode/6dx/backend/internal/httpx"
)

// authCaller is the identity the middleware put in the request context.
type authCaller = auth.Caller

// Thin aliases so the handlers read without the package prefix everywhere.
func writeJSON(w http.ResponseWriter, status int, payload any) {
	httpx.JSON(w, status, payload)
}

func writeError(w http.ResponseWriter, err error) {
	httpx.Write(w, err)
}

func badRequest(code, message string) error {
	return httpx.BadRequest(code, message)
}

func forbidden(code, message string) error {
	return httpx.Forbidden(code, message)
}

func notFound(code, message string) error {
	return httpx.NotFound(code, message)
}

func conflict(code, message string) error {
	return httpx.Conflict(code, message)
}

func unauthorized(message string) error {
	return httpx.Unauthorized(message)
}

// decodeBody reads the JSON body, tolerating an empty one.
func decodeBody(r *http.Request, dst any) error {
	return httpx.Decode(r, dst)
}

// callerAndUpsert resolves the caller and mirrors the identity into `users`.
// The invite endpoints need the e-mail, which only the token carries.
func (s *Server) callerAndUpsert(r *http.Request) (*authCaller, error) {
	caller, err := auth.FromContext(r.Context())
	if err != nil {
		return nil, unauthorized("سجّل الدخول أولاً.")
	}
	if err := s.store.upsertUser(r.Context(), caller); err != nil {
		return nil, err
	}
	return caller, nil
}

// callerAndWorkspace resolves the authenticated caller and the workspace the
// request targets (X-Workspace-Id, or the first membership).
func (s *Server) callerAndWorkspace(r *http.Request) (*authCaller, *Workspace, error) {
	caller, err := s.callerAndUpsert(r)
	if err != nil {
		return nil, nil, err
	}
	ws, err := s.activeWorkspace(r, caller)
	if err != nil {
		return nil, nil, err
	}
	return caller, ws, nil
}
