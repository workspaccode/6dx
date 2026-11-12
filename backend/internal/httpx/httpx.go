// Package httpx holds the small HTTP helpers every handler shares.
package httpx

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"
)

// Error is an error that already knows the status code and the message the
// client should see. Handlers return it and `Write` renders it.
type Error struct {
	Status  int
	Code    string
	Message string
}

func (e *Error) Error() string { return e.Code + ": " + e.Message }

func BadRequest(code, message string) *Error {
	return &Error{Status: http.StatusBadRequest, Code: code, Message: message}
}

func Unavailable(code, message string) *Error {
	return &Error{Status: http.StatusServiceUnavailable, Code: code, Message: message}
}

func BadGateway(code, message string) *Error {
	return &Error{Status: http.StatusBadGateway, Code: code, Message: message}
}

func Internal(code, message string) *Error {
	return &Error{Status: http.StatusInternalServerError, Code: code, Message: message}
}

func Unauthorized(message string) *Error {
	return &Error{Status: http.StatusUnauthorized, Code: "unauthorized", Message: message}
}

func Forbidden(code, message string) *Error {
	return &Error{Status: http.StatusForbidden, Code: code, Message: message}
}

func NotFound(code, message string) *Error {
	return &Error{Status: http.StatusNotFound, Code: code, Message: message}
}

func Conflict(code, message string) *Error {
	return &Error{Status: http.StatusConflict, Code: code, Message: message}
}

// JSON writes a JSON body with the given status.
func JSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if payload == nil {
		return
	}
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		slog.Error("write response", "error", err)
	}
}

// Write renders an error: an *Error keeps its status, anything else becomes a
// 500 with a generic message (the detail goes to the log, not the client).
func Write(w http.ResponseWriter, err error) {
	var appErr *Error
	if errors.As(err, &appErr) {
		JSON(w, appErr.Status, map[string]string{
			"error":   appErr.Code,
			"message": appErr.Message,
		})
		return
	}
	slog.Error("unhandled error", "error", err)
	JSON(w, http.StatusInternalServerError, map[string]string{
		"error":   "internal",
		"message": "حدث خطأ غير متوقع.",
	})
}

// Decode reads a JSON body into dst. Unknown fields are rejected so a typo in
// the client is a 400 rather than a silently ignored field.
func Decode(r *http.Request, dst any) error {
	decoder := json.NewDecoder(http.MaxBytesReader(nil, r.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(dst); err != nil {
		if errors.Is(err, io.EOF) {
			// An empty body is fine: most POST endpoints have no required
			// fields (accepting an invite, disconnecting GitHub, …).
			return nil
		}
		return BadRequest("invalid_body", "صيغة الطلب غير صحيحة: "+err.Error())
	}
	return nil
}

// PathValue is a tiny wrapper so handlers do not import the mux directly.
func PathValue(r *http.Request, name string) string {
	return r.PathValue(name)
}

// QueryOr returns the query parameter or a fallback.
func QueryOr(r *http.Request, name, fallback string) string {
	if value := strings.TrimSpace(r.URL.Query().Get(name)); value != "" {
		return value
	}
	return fallback
}
