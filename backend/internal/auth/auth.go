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
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
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

	// maxGitHubBody caps how much of a GitHub response is read.
	maxGitHubBody = 1 << 20
)

type contextKey struct{}

// Verifier resolves a bearer token into a caller.
type Verifier struct {
	client *auth.Client

	githubAPIBase string
	httpClient    *http.Client

	// githubClientID / githubClientSecret identify the OAuth app the device
	// flow runs against. A grant is accepted only when GitHub confirms it was
	// issued to this app — `GET /user` alone succeeds for any GitHub token.
	githubClientID     string
	githubClientSecret string

	mu    sync.Mutex
	cache map[string]githubGrant
	// epoch counts revocations: a grant checked before one (still valid at
	// GitHub then) is not cached after it, so it cannot outlive the revoke.
	epoch uint64
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

// SetGitHubApp sets the OAuth app whose grants are accepted. Without it every
// GitHub grant is rejected (fail closed).
func (v *Verifier) SetGitHubApp(clientID, clientSecret string) {
	v.githubClientID = clientID
	v.githubClientSecret = clientSecret
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
	// An unverified address must never be trusted: invites are matched by
	// e-mail, and anyone can type someone else's address into a new account.
	if verified, _ := token.Claims["email_verified"].(bool); verified {
		if email, ok := token.Claims["email"].(string); ok {
			caller.Email = email
		}
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
	epoch := v.currentEpoch()

	appUserID, err := v.checkAppGrant(ctx, token)
	if err != nil {
		return nil, err
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

	if profile.ID != appUserID {
		return nil, errors.New("github grant and profile disagree")
	}

	// Only a verified primary address is trusted (see verifyFirebase). The
	// public profile e-mail is ignored: /user/emails says whether it is verified.
	var email string
	var emails []struct {
		Email    string `json:"email"`
		Primary  bool   `json:"primary"`
		Verified bool   `json:"verified"`
	}
	if err := v.githubGet(ctx, token, "/user/emails", &emails); err == nil {
		for _, candidate := range emails {
			if candidate.Primary && candidate.Verified {
				email = candidate.Email
				break
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

	v.storeAt(key, caller, epoch)
	return caller, nil
}

// checkAppGrant asks GitHub whether the token was issued to this API's OAuth
// app (POST /applications/{client_id}/token, Basic auth with the app
// credentials) and returns the GitHub user id it belongs to.
func (v *Verifier) checkAppGrant(ctx context.Context, token string) (int64, error) {
	if v.githubClientID == "" || v.githubClientSecret == "" {
		return 0, errors.New("github app credentials are not configured")
	}
	body, err := json.Marshal(map[string]string{"access_token": token})
	if err != nil {
		return 0, err
	}
	request, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		v.githubAPIBase+"/applications/"+url.PathEscape(v.githubClientID)+"/token",
		bytes.NewReader(body),
	)
	if err != nil {
		return 0, err
	}
	request.SetBasicAuth(v.githubClientID, v.githubClientSecret)
	request.Header.Set("Accept", "application/vnd.github+json")
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-GitHub-Api-Version", "2022-11-28")

	response, err := v.httpClient.Do(request)
	if err != nil {
		return 0, fmt.Errorf("github token check: %w", err)
	}
	defer func() { _ = response.Body.Close() }()

	// 404 = the token is invalid or belongs to another app; 422 = malformed.
	if response.StatusCode == http.StatusNotFound || response.StatusCode == http.StatusUnprocessableEntity {
		return 0, errors.New("github grant was not issued to this app")
	}
	if response.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("github token check: unexpected status %d", response.StatusCode)
	}

	var payload struct {
		App struct {
			ClientID string `json:"client_id"`
		} `json:"app"`
		User struct {
			ID int64 `json:"id"`
		} `json:"user"`
	}
	if err := json.NewDecoder(io.LimitReader(response.Body, maxGitHubBody)).Decode(&payload); err != nil {
		return 0, err
	}
	if payload.App.ClientID != v.githubClientID || payload.User.ID == 0 {
		return 0, errors.New("github grant was not issued to this app")
	}
	return payload.User.ID, nil
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
	return json.NewDecoder(io.LimitReader(response.Body, maxGitHubBody)).Decode(dst)
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
	v.storeLocked(key, caller)
}

func (v *Verifier) storeLocked(key string, caller *Caller) {
	// Drop expired entries so a long-running server does not grow forever.
	now := time.Now()
	for candidate, grant := range v.cache {
		if now.After(grant.expires) {
			delete(v.cache, candidate)
		}
	}
	v.cache[key] = githubGrant{caller: caller, expires: now.Add(githubGrantTTL)}
}

// RevokeGitHubToken signs a device out for good: GitHub deletes the token
// (DELETE /applications/{client_id}/token, Basic auth with the app
// credentials), and the cached grant goes with it, so the token stops working
// here at once instead of after githubGrantTTL. A token GitHub no longer knows
// (404) counts as revoked. A Firebase ID token has nothing to revoke.
func (v *Verifier) RevokeGitHubToken(ctx context.Context, token string) error {
	if token == "" || looksLikeJWT(token) {
		return nil
	}
	v.forget(hashToken(token))
	// A request verified while the DELETE is in flight must not re-cache it.
	defer v.forget(hashToken(token))
	if v.githubClientID == "" || v.githubClientSecret == "" {
		return errors.New("github app credentials are not configured")
	}
	body, err := json.Marshal(map[string]string{"access_token": token})
	if err != nil {
		return err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodDelete,
		v.githubAPIBase+"/applications/"+url.PathEscape(v.githubClientID)+"/token",
		bytes.NewReader(body))
	if err != nil {
		return err
	}
	request.SetBasicAuth(v.githubClientID, v.githubClientSecret)
	request.Header.Set("Accept", "application/vnd.github+json")
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("X-GitHub-Api-Version", "2022-11-28")
	response, err := v.httpClient.Do(request)
	if err != nil {
		return fmt.Errorf("github token revoke: %w", err)
	}
	defer func() { _ = response.Body.Close() }()
	switch response.StatusCode {
	case http.StatusNoContent, http.StatusOK, http.StatusNotFound:
		return nil
	}
	return fmt.Errorf("github token revoke: unexpected status %d", response.StatusCode)
}

// EvictGitHubUser drops every cached grant of a GitHub account: the user
// revoked the app on GitHub (the github_app_authorization webhook), so their
// tokens must stop working now, not when the cache entry expires.
func (v *Verifier) EvictGitHubUser(githubID int64) {
	v.mu.Lock()
	defer v.mu.Unlock()
	v.epoch++
	for key, grant := range v.cache {
		if grant.caller != nil && grant.caller.GitHubID != nil && *grant.caller.GitHubID == githubID {
			delete(v.cache, key)
		}
	}
}

func (v *Verifier) forget(key string) {
	v.mu.Lock()
	defer v.mu.Unlock()
	v.epoch++
	delete(v.cache, key)
}

func (v *Verifier) currentEpoch() uint64 {
	v.mu.Lock()
	defer v.mu.Unlock()
	return v.epoch
}

// storeAt caches the grant unless a revocation happened since epoch was read.
func (v *Verifier) storeAt(key string, caller *Caller, epoch uint64) {
	v.mu.Lock()
	defer v.mu.Unlock()
	if v.epoch == epoch {
		v.storeLocked(key, caller)
	}
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
