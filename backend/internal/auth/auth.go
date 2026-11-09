// Package auth verifies Firebase ID tokens and carries the caller through the
// request context.
package auth

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"google.golang.org/api/option"
)

// Caller is the authenticated Firebase user behind a request.
type Caller struct {
	UID         string
	Email       string
	DisplayName string
	PhotoURL    string
	// GitHubID is the numeric GitHub account the Firebase user signed in
	// with, when they used the GitHub provider. It is the trusted link the
	// install-recovery path relies on.
	GitHubID *int64
}

type contextKey struct{}

// Verifier wraps the Firebase Admin SDK.
type Verifier struct {
	client *auth.Client
}

// NewVerifier builds the Admin SDK client. credentialsFile may be empty, in
// which case the Google application-default credentials are used (the normal
// setup on Cloud Run / a VM with a service account).
func NewVerifier(ctx context.Context, projectID, credentialsFile string) (*Verifier, error) {
	var opts []option.ClientOption
	if credentialsFile != "" {
		opts = append(opts, option.WithCredentialsFile(credentialsFile))
	}
	app, err := firebase.NewApp(ctx, &firebase.Config{ProjectID: projectID}, opts...)
	if err != nil {
		return nil, fmt.Errorf("firebase app: %w", err)
	}
	client, err := app.Auth(ctx)
	if err != nil {
		return nil, fmt.Errorf("firebase auth client: %w", err)
	}
	return &Verifier{client: client}, nil
}

// Verify checks the ID token and returns the caller it belongs to.
func (v *Verifier) Verify(ctx context.Context, idToken string) (*Caller, error) {
	token, err := v.client.VerifyIDToken(ctx, idToken)
	if err != nil {
		return nil, err
	}
	caller := &Caller{UID: token.UID}
	if email, ok := token.Claims["email"].(string); ok {
		caller.Email = email
	}
	if name, ok := token.Claims["name"].(string); ok {
		caller.DisplayName = name
	}
	if picture, ok := token.Claims["picture"].(string); ok {
		caller.PhotoURL = picture
	}
	// `firebase.identities` maps a provider id to the provider-side uid; for
	// GitHub that value is the numeric account id as a string.
	if identities, ok := token.Claims["firebase"].(map[string]any); ok {
		if byProvider, ok := identities["identities"].(map[string]any); ok {
			if values, ok := byProvider["github.com"].([]any); ok && len(values) > 0 {
				if raw, ok := values[0].(string); ok {
					if parsed, err := strconv.ParseInt(raw, 10, 64); err == nil {
						caller.GitHubID = &parsed
					}
				}
			}
		}
	}
	return caller, nil
}

// Middleware rejects anything without a valid `Authorization: Bearer <token>`
// header and puts the caller in the request context. The public routes (the
// GitHub OAuth legs and the webhook) are registered outside it.
func (v *Verifier) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			unauthorized(w, "missing bearer token")
			return
		}
		caller, err := v.Verify(r.Context(), strings.TrimSpace(header[len("Bearer "):]))
		if err != nil {
			unauthorized(w, "invalid token")
			return
		}
		next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), contextKey{}, caller)))
	})
}

// WithCaller puts a caller in the context. The middleware uses it, and so do
// tests that need to act as an account without a real Firebase token.
func WithCaller(ctx context.Context, caller *Caller) context.Context {
	return context.WithValue(ctx, contextKey{}, caller)
}

// FromContext returns the caller set by Middleware.
func FromContext(ctx context.Context) (*Caller, error) {
	caller, ok := ctx.Value(contextKey{}).(*Caller)
	if !ok || caller == nil {
		return nil, errors.New("no caller in context")
	}
	return caller, nil
}

func unauthorized(w http.ResponseWriter, detail string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(http.StatusUnauthorized)
	_, _ = w.Write([]byte(`{"error":"unauthorized","detail":"` + detail + `"}`))
}
