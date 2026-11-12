// Package auth verifies the credential behind a request and carries the caller
// through the request context.
//
// Two credentials are accepted:
//
//   - the GitHub access token the app's OAuth device flow obtained. The app is
//     GitHub-only, and the device flow is the one sign-in path it can run on
//     every platform (Android, iOS, macOS, Windows, Linux, web), so the API
//     verifies that grant directly with GitHub;
//   - a Firebase ID token, kept so sessions issued before the switch keep
//     working.
package auth

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"google.golang.org/api/option"
)

// Caller is the authenticated user behind a request.
type Caller struct {
	UID         string
	Email       string
	DisplayName string
	PhotoURL    string
	// GitHubID is the numeric GitHub account the caller signed in with. It is
	// the trusted link the install-recovery path relies on.
	GitHubID *int64
}

const (
	// defaultGitHubAPIBase is the GitHub REST host used to resolve a grant. It
	// is a field on the verifier so a test can point it at httptest.
	defaultGitHubAPIBase = "https://api.github.com"

	// githubGrantTTL is how long a resolved grant is reused. Every API request
	// carries the token and GitHub allows 5000 calls an hour per user, so the
	// profile is cached instead of re-fetched per call.
	githubGrantTTL = 5 * time.Minute

	githubRequestTimeout = 10 * time.Second
)

type contextKey struct{}

// Verifier resolves a bearer token into a caller.
type Verifier struct {
	client *auth.Client

	githubAPIBase string
	httpClient    *http.Client

	mu    sync.Mutex
	cache map[string]githubGrant
}

type githubGrant struct {
	caller  *Caller
	expires time.Time
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
	verifier := NewGitHubVerifier()
	verifier.client = client
	return verifier, nil
}

// NewGitHubVerifier builds a verifier that only knows the GitHub grants the
// app signs in with. It is the normal configuration: Firebase is kept for
// legacy ID tokens, and the API has to run without it.
func NewGitHubVerifier() *Verifier {
	return &Verifier{
		githubAPIBase: defaultGitHubAPIBase,
		httpClient:    &http.Client{Timeout: githubRequestTimeout},
		cache:         make(map[string]githubGrant),
	}
}

// Verify checks a bearer token and returns the caller it belongs to.
//
// A Firebase ID token is a JWT; a GitHub grant is an opaque string, so the
// shape tells the two apart without a round trip.
func (v *Verifier) Verify(ctx context.Context, token string) (*Caller, error) {
	if looksLikeJWT(token) {
		return v.verifyFirebase(ctx, token)
	}
	return v.verifyGitHubGrant(ctx, token)
}

func (v *Verifier) verifyFirebase(ctx context.Context, idToken string) (*Caller, error) {
	if v.client == nil {
		return nil, errors.New("firebase is not configured on this API")
	}
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

// verifyGitHubGrant resolves the GitHub access token the device flow produced
// into a caller.
//
// The uid it reports is the numeric GitHub id, which is only provisional: the
// API then maps it to the uid already stored for that GitHub account (see
// `withStoredIdentity`), so accounts created by the old Firebase sign-in keep
// their workspaces.
func (v *Verifier) verifyGitHubGrant(ctx context.Context, token string) (*Caller, error) {
	if token == "" {
		return nil, errors.New("empty token")
	}
	key := hashToken(token)
	if cached, ok := v.cached(key); ok {
		return cached, nil
	}

	var profile struct {
		ID        int64  `json:"id"`
		Login     string `json:"login"`
		Name      string `json:"name"`
		Email     string `json:"email"`
		AvatarURL string `json:"avatar_url"`
	}
	if err := v.githubGet(ctx, token, "/user", &profile); err != nil {
		return nil, err
	}
	if profile.ID == 0 {
		return nil, errors.New("github returned no account id")
	}

	email := profile.Email
	if email == "" {
		// The profile e-mail stays hidden unless it is public; the scopes the
		// app asks for allow reading the verified primary address instead.
		var emails []struct {
			Email   string `json:"email"`
			Primary bool   `json:"primary"`
		}
		if err := v.githubGet(ctx, token, "/user/emails", &emails); err == nil {
			for _, candidate := range emails {
				if candidate.Primary {
					email = candidate.Email
					break
				}
			}
		}
	}

	githubID := profile.ID
	caller := &Caller{
		UID:         strconv.FormatInt(profile.ID, 10),
		Email:       email,
		DisplayName: profile.Name,
		PhotoURL:    profile.AvatarURL,
		GitHubID:    &githubID,
	}
	if caller.DisplayName == "" {
		caller.DisplayName = profile.Login
	}

	v.store(key, caller)
	return caller, nil
}

// githubGet performs an authenticated GET against the GitHub REST API.
func (v *Verifier) githubGet(ctx context.Context, token, path string, dst any) error {
	request, err := http.NewRequestWithContext(
		ctx,
		http.MethodGet,
		v.githubAPIBase+path,
		nil,
	)
	if err != nil {
		return err
	}
	request.Header.Set("Authorization", "Bearer "+token)
	request.Header.Set("Accept", "application/vnd.github+json")
	request.Header.Set("X-GitHub-Api-Version", "2022-11-28")

	response, err := v.httpClient.Do(request)
	if err != nil {
		return fmt.Errorf("github %s: %w", path, err)
	}
	defer func() { _ = response.Body.Close() }()

	if response.StatusCode == http.StatusUnauthorized {
		return errors.New("github rejected the grant")
	}
	if response.StatusCode != http.StatusOK {
		return fmt.Errorf("github %s: unexpected status %d", path, response.StatusCode)
	}
	return json.NewDecoder(response.Body).Decode(dst)
}

func (v *Verifier) cached(key string) (*Caller, bool) {
	v.mu.Lock()
	defer v.mu.Unlock()
	grant, ok := v.cache[key]
	if !ok || time.Now().After(grant.expires) {
		if ok {
			delete(v.cache, key)
		}
		return nil, false
	}
	return grant.caller, true
}

func (v *Verifier) store(key string, caller *Caller) {
	v.mu.Lock()
	defer v.mu.Unlock()
	// Drop expired entries so a long-running server does not grow forever.
	now := time.Now()
	for candidate, grant := range v.cache {
		if now.After(grant.expires) {
			delete(v.cache, candidate)
		}
	}
	v.cache[key] = githubGrant{caller: caller, expires: now.Add(githubGrantTTL)}
}

// looksLikeJWT reports whether the token is a Firebase ID token (three
// base64url segments) rather than an opaque GitHub grant.
func looksLikeJWT(token string) bool {
	if strings.Count(token, ".") != 2 {
		return false
	}
	return strings.HasPrefix(token, "eyJ")
}

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
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
// tests that need to act as an account without a real token.
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
