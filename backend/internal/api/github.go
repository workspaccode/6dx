package api

import (
	"crypto"
	"crypto/hmac"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/workspaccode/6dx/backend/internal/config"
)

// githubBroker is the GitHub App broker. The three-leg design and every
// security check of the Cloud Function / edge function are preserved:
//
//	leg 1  the app asks for a signed install URL
//	leg 2  GitHub's Setup URL — the state names the workspace; when GitHub
//	       drops it (it documents only installation_id/setup_action) a
//	       recovery token names the installation and the workspace comes from
//	       the GitHub identity instead
//	leg 3  the OAuth callback — the user token proves who is in the browser,
//	       the account must belong to them (personal) or be administered by
//	       them (org), and only then is anything stored
//	hook   HMAC over the raw body, pull request state upserted
type githubBroker struct {
	cfg        *config.Config
	privateKey *rsa.PrivateKey
	httpClient *http.Client
}

const (
	githubAPI         = "https://api.github.com"
	githubOAuth       = "https://github.com/login/oauth"
	stateTTL          = 30 * time.Minute
	githubHTTPTimeout = 15 * time.Second
)

func newGithubBroker(cfg *config.Config) (*githubBroker, error) {
	block, _ := pem.Decode([]byte(cfg.GitHubPrivateKeyPEM))
	if block == nil {
		return nil, errors.New("GITHUB_PRIVATE_KEY is not a PEM block")
	}
	parsed, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err != nil {
		key, err2 := x509.ParsePKCS8PrivateKey(block.Bytes)
		if err2 != nil {
			return nil, fmt.Errorf("parse private key: %w", err)
		}
		rsaKey, ok := key.(*rsa.PrivateKey)
		if !ok {
			return nil, errors.New("private key is not RSA")
		}
		parsed = rsaKey
	}
	return &githubBroker{
		cfg:        cfg,
		privateKey: parsed,
		httpClient: &http.Client{Timeout: githubHTTPTimeout},
	}, nil
}

// --- state ------------------------------------------------------------------

func (b *githubBroker) hmac(payload string) string {
	mac := hmac.New(sha256.New, []byte(b.cfg.GitHubStateSecret))
	mac.Write([]byte(payload))
	return hex.EncodeToString(mac.Sum(nil))
}

func (b *githubBroker) signState(workspaceID, userID string, installationID int64) string {
	payload := fmt.Sprintf("v1.%s.%s.%d.%d", workspaceID, userID, installationID, time.Now().UnixMilli())
	return payload + "." + b.hmac(payload)
}

type statePayload struct {
	WorkspaceID    string
	UserID         string
	InstallationID int64
}

func (b *githubBroker) verifyState(state string) (*statePayload, bool) {
	parts := strings.Split(state, ".")
	if len(parts) != 6 || parts[0] != "v1" {
		return nil, false
	}
	payload := strings.Join(parts[:5], ".")
	if !hmac.Equal([]byte(b.hmac(payload)), []byte(parts[5])) {
		return nil, false
	}
	issuedAt, err := strconv.ParseInt(parts[4], 10, 64)
	if err != nil {
		return nil, false
	}
	if age := time.Since(time.UnixMilli(issuedAt)); age < 0 || age > stateTTL {
		return nil, false
	}
	installationID, _ := strconv.ParseInt(parts[3], 10, 64)
	return &statePayload{
		WorkspaceID:    parts[1],
		UserID:         parts[2],
		InstallationID: installationID,
	}, true
}

func (b *githubBroker) signRecovery(installationID int64) string {
	payload := fmt.Sprintf("r1.%d.%d", installationID, time.Now().UnixMilli())
	return payload + "." + b.hmac(payload)
}

func (b *githubBroker) verifyRecovery(state string) (int64, bool) {
	parts := strings.Split(state, ".")
	if len(parts) != 4 || parts[0] != "r1" {
		return 0, false
	}
	payload := strings.Join(parts[:3], ".")
	if !hmac.Equal([]byte(b.hmac(payload)), []byte(parts[3])) {
		return 0, false
	}
	issuedAt, err := strconv.ParseInt(parts[2], 10, 64)
	if err != nil {
		return 0, false
	}
	if age := time.Since(time.UnixMilli(issuedAt)); age < 0 || age > stateTTL {
		return 0, false
	}
	id, _ := strconv.ParseInt(parts[1], 10, 64)
	return id, id != 0
}

// --- GitHub API -------------------------------------------------------------

func (b *githubBroker) appJWT() (string, error) {
	now := time.Now()
	claims := jwt.MapClaims{
		"iat": now.Add(-60 * time.Second).Unix(),
		"exp": now.Add(9 * time.Minute).Unix(),
		"iss": b.cfg.GitHubAppID,
	}
	return jwt.NewWithClaims(jwt.SigningMethodRS256, claims).SignedString(b.privateKey)
}

func (b *githubBroker) installationToken(installationID int64) (string, error) {
	appToken, err := b.appJWT()
	if err != nil {
		return "", err
	}
	request, err := http.NewRequest(http.MethodPost,
		fmt.Sprintf("%s/app/installations/%d/access_tokens", githubAPI, installationID), nil)
	if err != nil {
		return "", err
	}
	request.Header.Set("Authorization", "Bearer "+appToken)
	request.Header.Set("Accept", "application/vnd.github+json")

	response, err := b.httpClient.Do(request)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusCreated {
		body, _ := io.ReadAll(io.LimitReader(response.Body, 512))
		return "", fmt.Errorf("installation token: %d %s", response.StatusCode, body)
	}

	var payload struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(response.Body).Decode(&payload); err != nil {
		return "", err
	}
	if payload.Token == "" {
		return "", errors.New("installation token missing")
	}
	return payload.Token, nil
}

func (b *githubBroker) getJSON(token, path string, dst any) error {
	request, err := http.NewRequest(http.MethodGet, githubAPI+path, nil)
	if err != nil {
		return err
	}
	request.Header.Set("Authorization", "Bearer "+token)
	request.Header.Set("Accept", "application/vnd.github+json")
	request.Header.Set("User-Agent", "6dx")

	response, err := b.httpClient.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(response.Body, 512))
		return fmt.Errorf("github %s: %d %s", path, response.StatusCode, body)
	}
	return json.NewDecoder(response.Body).Decode(dst)
}

// revokeUserToken drops the user token once ownership is proven.
func (b *githubBroker) revokeUserToken(userToken string) {
	body := strings.NewReader(`{"access_token":"` + userToken + `"}`)
	request, err := http.NewRequest(http.MethodDelete,
		fmt.Sprintf("%s/applications/%s/token", githubAPI, b.cfg.GitHubClientID), body)
	if err != nil {
		return
	}
	request.SetBasicAuth(b.cfg.GitHubClientID, b.cfg.GitHubClientSecret)
	request.Header.Set("Accept", "application/vnd.github+json")
	request.Header.Set("Content-Type", "application/json")

	response, err := b.httpClient.Do(request)
	if err != nil {
		slog.Warn("github token revocation failed", "error", err)
		return
	}
	defer response.Body.Close()
}

// --- browser legs -----------------------------------------------------------

func githubHTML(w http.ResponseWriter, message string) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = io.WriteString(w, `<!doctype html><html lang="ar" dir="rtl"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>6DX</title><style>body{font-family:system-ui,sans-serif;background:#0F1115;
color:#E8EAF0;display:flex;align-items:center;justify-content:center;height:100vh;
margin:0}div{max-width:420px;padding:28px;border-radius:16px;background:#171A21;
border:1px solid #2A2F3A;text-align:center;line-height:1.7}</style></head>
<body><div>`+message+`</div></body></html>`)
}

// GET /github/setup — GitHub's Setup URL.
func (s *Server) handleGithubSetup(w http.ResponseWriter, r *http.Request) {
	if s.github == nil {
		githubHTML(w, "تطبيق GitHub غير مُهيّأ على الخادم.")
		return
	}
	installationID, _ := strconv.ParseInt(r.URL.Query().Get("installation_id"), 10, 64)
	if installationID == 0 {
		githubHTML(w, "لم يصل معرّف التثبيت من GitHub.")
		return
	}

	// A missing state is not fatal: GitHub does not promise to echo it back.
	var next string
	if state, ok := s.github.verifyState(r.URL.Query().Get("state")); ok {
		next = s.github.signState(state.WorkspaceID, state.UserID, installationID)
	} else {
		next = s.github.signRecovery(installationID)
	}

	authorize := fmt.Sprintf("%s/authorize?client_id=%s&state=%s&redirect_uri=%s",
		githubOAuth,
		url.QueryEscape(s.cfg.GitHubClientID),
		url.QueryEscape(next),
		url.QueryEscape(s.cfg.GitHubOAuthRedirect))
	http.Redirect(w, r, authorize, http.StatusFound)
}

// GET /github/callback — the OAuth callback.
func (s *Server) handleGithubCallback(w http.ResponseWriter, r *http.Request) {
	if s.github == nil {
		githubHTML(w, "تطبيق GitHub غير مُهيّأ على الخادم.")
		return
	}
	code := r.URL.Query().Get("code")
	if code == "" {
		githubHTML(w, "لم يصل رمز التفويض من GitHub.")
		return
	}

	rawState := r.URL.Query().Get("state")
	state, stateOK := s.github.verifyState(rawState)
	var installationID int64
	if stateOK && state.InstallationID != 0 {
		installationID = state.InstallationID
	} else if recovered, ok := s.github.verifyRecovery(rawState); ok {
		installationID = recovered
	} else {
		githubHTML(w, "انتهت صلاحية الطلب — أعد المحاولة من التطبيق.")
		return
	}

	userToken, err := s.exchangeCode(r, code)
	if err != nil {
		slog.Error("github code exchange", "error", err)
		githubHTML(w, "تعذّر استبدال رمز التفويض.")
		return
	}

	var user struct {
		ID    int64  `json:"id"`
		Login string `json:"login"`
	}
	var installation struct {
		Account struct {
			ID    int64  `json:"id"`
			Type  string `json:"type"`
			Login string `json:"login"`
		} `json:"account"`
	}
	if err := s.github.getJSON(userToken, "/user", &user); err != nil {
		githubHTML(w, "تعذّر قراءة حساب GitHub.")
		return
	}
	appToken, err := s.github.appJWT()
	if err != nil {
		githubHTML(w, "تعذّر قراءة بيانات التثبيت.")
		return
	}
	if err := s.github.getJSON(appToken,
		fmt.Sprintf("/app/installations/%d", installationID), &installation); err != nil {
		githubHTML(w, "تعذّر قراءة بيانات التثبيت.")
		return
	}

	workspaceID, callerUID, ok := s.resolveGithubTarget(r, state, stateOK, user.ID)
	if !ok {
		githubHTML(w, "حساب GitHub ده مش مربوط بأي حساب 6DX. سجّل الدخول بـ GitHub في التطبيق.")
		return
	}

	if message, allowed := s.checkOwnership(r, userToken, user.ID,
		installation.Account.Type, installation.Account.Login, installation.Account.ID); !allowed {
		s.github.revokeUserToken(userToken)
		githubHTML(w, message)
		return
	}

	now := nowString()
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into github_installations
		  (id, workspace_id, installation_id, account_login, account_type,
		   created_by, created_at)
		values (?, ?, ?, ?, ?, ?, ?)
		on conflict (workspace_id, installation_id) do update set
		  account_login = excluded.account_login,
		  account_type  = excluded.account_type`,
		newID(), workspaceID, installationID, installation.Account.Login,
		installation.Account.Type, callerUID, now,
	); err != nil {
		slog.Error("store installation", "error", err)
		githubHTML(w, "تعذّر حفظ التثبيت.")
		return
	}

	s.github.revokeUserToken(userToken)
	githubHTML(w, "تم ربط تطبيق 6DX بحساب GitHub. ارجع إلى التطبيق واضغط «تحديث».")
}

func (s *Server) exchangeCode(r *http.Request, code string) (string, error) {
	form := url.Values{
		"client_id":     {s.cfg.GitHubClientID},
		"client_secret": {s.cfg.GitHubClientSecret},
		"code":          {code},
		"redirect_uri":  {s.cfg.GitHubOAuthRedirect},
	}
	request, err := http.NewRequest(http.MethodPost,
		githubOAuth+"/access_token", strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	request.Header.Set("Accept", "application/json")
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	response, err := s.github.httpClient.Do(request)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return "", fmt.Errorf("exchange: %d", response.StatusCode)
	}

	var payload struct {
		AccessToken string `json:"access_token"`
		Error       string `json:"error"`
	}
	if err := json.NewDecoder(response.Body).Decode(&payload); err != nil {
		return "", err
	}
	if payload.AccessToken == "" {
		return "", fmt.Errorf("no token: %s", payload.Error)
	}
	return payload.AccessToken, nil
}

// resolveGithubTarget maps the browser's GitHub identity to a 6DX workspace.
//
// With a signed state that is the state itself; on the recovery path the
// workspace comes from the identity stored in `users.github_id`, which is fed
// only by the verified Firebase token — never by the request.
func (s *Server) resolveGithubTarget(
	r *http.Request,
	state *statePayload,
	stateOK bool,
	githubUserID int64,
) (string, string, bool) {
	if stateOK {
		var uid string
		if err := s.store.db.QueryRowContext(r.Context(),
			`select uid from users where uid = ?`, state.UserID,
		).Scan(&uid); err != nil {
			return "", "", false
		}
		return state.WorkspaceID, state.UserID, true
	}

	var uid string
	if err := s.store.db.QueryRowContext(r.Context(),
		`select uid from users where github_id = ? limit 1`, githubUserID,
	).Scan(&uid); err != nil {
		return "", "", false
	}

	var workspaceID string
	if err := s.store.db.QueryRowContext(r.Context(), `
		select m.workspace_id
		from workspace_members m
		where m.user_uid = ?
		order by (m.role = 'owner') desc, m.created_at
		limit 1`, uid,
	).Scan(&workspaceID); err != nil {
		return "", "", false
	}
	return workspaceID, uid, true
}

// checkOwnership: `/user/installations` is too broad — a plain org member could
// attach the whole installation. The installer must own the account, or
// administer the organisation.
func (s *Server) checkOwnership(
	r *http.Request,
	userToken string,
	userID int64,
	accountType, accountLogin string,
	accountID int64,
) (string, bool) {
	switch accountType {
	case "User":
		if accountID != userID {
			return "التثبيت ده على حساب GitHub تاني — سجّل الدخول بحسابك هو.", false
		}
		return "", true
	case "Organization":
		var membership struct {
			State string `json:"state"`
			Role  string `json:"role"`
		}
		path := "/user/memberships/orgs/" + url.PathEscape(accountLogin)
		if err := s.github.getJSON(userToken, path, &membership); err != nil {
			return "تعذّر التحقق من عضويتك في " + accountLogin + ".", false
		}
		if membership.State != "active" || membership.Role != "admin" {
			return "تثبيت التطبيق على مؤسسة يحتاج صلاحية admin فيها.", false
		}
		return "", true
	}
	return "نوع الحساب ده غير مدعوم.", false
}

// --- webhook ----------------------------------------------------------------

// POST /github/webhook
func (s *Server) handleGithubWebhook(w http.ResponseWriter, r *http.Request) {
	if s.github == nil {
		writeJSON(w, http.StatusInternalServerError,
			map[string]string{"error": "webhook_not_configured"})
		return
	}

	raw, err := io.ReadAll(io.LimitReader(r.Body, 2<<20))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "unreadable_body"})
		return
	}
	expected := bhex(s.github.hmac(string(raw)))
	provided := bhex(strings.TrimPrefix(r.Header.Get("X-Hub-Signature-256"), "sha256="))
	if !hmac.Equal(expected, provided) {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid_signature"})
		return
	}

	event := r.Header.Get("X-GitHub-Event")
	if event != "pull_request" {
		writeJSON(w, http.StatusOK, map[string]string{"ignored": event})
		return
	}

	var payload struct {
		Action       string `json:"action"`
		Number       int    `json:"number"`
		Repository   struct{ FullName string `json:"full_name"` } `json:"repository"`
		Installation struct{ ID int64 `json:"id"` } `json:"installation"`
		PullRequest  struct {
			Number    int    `json:"number"`
			Title     string `json:"title"`
			State     string `json:"state"`
			Merged    bool   `json:"merged"`
			Additions int    `json:"additions"`
			Deletions int    `json:"deletions"`
			User      struct{ Login string `json:"login"` } `json:"user"`
			Head      struct {
				Ref string `json:"ref"`
				SHA string `json:"sha"`
			} `json:"head"`
			Base struct{ Ref string `json:"ref"` } `json:"base"`
		} `json:"pull_request"`
	}
	if err := json.Unmarshal(raw, &payload); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid_payload"})
		return
	}
	if payload.Installation.ID == 0 {
		writeJSON(w, http.StatusOK, map[string]bool{"ignored": true})
		return
	}

	var workspaceID string
	err = s.store.db.QueryRowContext(r.Context(),
		`select workspace_id from github_installations where installation_id = ? limit 1`,
		payload.Installation.ID).Scan(&workspaceID)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]string{"ignored": "unknown_installation"})
		return
	}

	state := payload.PullRequest.State
	if payload.PullRequest.Merged {
		state = "merged"
	}
	number := payload.PullRequest.Number
	if number == 0 {
		number = payload.Number
	}

	now := nowString()
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into pull_requests
		  (id, workspace_id, number, title, author, branch, base_branch, state,
		   additions, deletions, last_commit, created_at)
		values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		on conflict (workspace_id, number) do update set
		  title      = excluded.title,
		  author     = excluded.author,
		  branch     = excluded.branch,
		  base_branch = excluded.base_branch,
		  state      = excluded.state,
		  additions  = excluded.additions,
		  deletions  = excluded.deletions,
		  last_commit = excluded.last_commit`,
		newID(), workspaceID, number, payload.PullRequest.Title,
		payload.PullRequest.User.Login, payload.PullRequest.Head.Ref,
		payload.PullRequest.Base.Ref, state, payload.PullRequest.Additions,
		payload.PullRequest.Deletions, payload.PullRequest.Head.SHA, now,
	); err != nil {
		slog.Error("upsert pull request", "error", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "sync_failed"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"synced": number, "repository": payload.Repository.FullName,
	})
}

func bhex(value string) []byte {
	decoded, err := hex.DecodeString(value)
	if err != nil {
		return nil
	}
	return decoded
}

// --- app-facing endpoints ---------------------------------------------------

// GET /v1/github/installation
func (s *Server) handleGithubInstallation(w http.ResponseWriter, r *http.Request) {
	_, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}

	var installationID int64
	var accountLogin, accountType string
	err = s.store.db.QueryRowContext(r.Context(), `
		select installation_id, account_login, account_type
		from github_installations where workspace_id = ?
		order by created_at limit 1`, ws.ID,
	).Scan(&installationID, &accountLogin, &accountType)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]any{"installation": nil})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"installation": map[string]any{
			"installation_id": installationID,
			"account_login":   accountLogin,
			"account_type":    accountType,
		},
	})
}

// GET /v1/github/repositories
func (s *Server) handleGithubRepositories(w http.ResponseWriter, r *http.Request) {
	_, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if s.github == nil {
		writeError(w, conflict("github_not_configured", "تطبيق GitHub غير مُهيّأ."))
		return
	}

	var installationID int64
	err = s.store.db.QueryRowContext(r.Context(), `
		select installation_id from github_installations
		where workspace_id = ? order by created_at limit 1`, ws.ID).Scan(&installationID)
	if err != nil {
		writeError(w, conflict("no_installation", "لم يتم تثبيت تطبيق GitHub بعد."))
		return
	}

	token, err := s.github.installationToken(installationID)
	if err != nil {
		writeError(w, conflict("github_token_failed", "تعذّر قراءة مستودعات GitHub."))
		return
	}
	var payload struct {
		TotalCount   int               `json:"total_count"`
		Repositories []json.RawMessage `json:"repositories"`
	}
	if err := s.github.getJSON(token, "/installation/repositories?per_page=100", &payload); err != nil {
		writeError(w, conflict("github_error", "تعذّر قراءة مستودعات GitHub."))
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"total_count":  payload.TotalCount,
		"repositories": payload.Repositories,
	})
}

// POST /v1/github/install-url
func (s *Server) handleGithubInstallURL(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.requireAdmin(r.Context(), ws.ID, caller.UID); err != nil {
		writeError(w, err)
		return
	}
	if s.github == nil {
		writeError(w, conflict("github_not_configured", "تطبيق GitHub غير مُهيّأ."))
		return
	}

	state := s.github.signState(ws.ID, caller.UID, 0)
	writeJSON(w, http.StatusOK, map[string]string{
		"url": fmt.Sprintf("https://github.com/apps/%s/installations/new?state=%s",
			s.cfg.GitHubAppSlug, url.QueryEscape(state)),
	})
}

// POST /v1/github/disconnect
func (s *Server) handleGithubDisconnect(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.requireAdmin(r.Context(), ws.ID, caller.UID); err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(),
		`delete from github_installations where workspace_id = ?`, ws.ID,
	); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// nonce is unused today but kept for a future signed-upload flow.
func nonce(size int) string {
	buf := make([]byte, size)
	if _, err := rand.Read(buf); err != nil {
		return strconv.FormatInt(time.Now().UnixNano(), 36)
	}
	return base64.RawURLEncoding.EncodeToString(buf)
}

var (
	_ = crypto.SHA256
	_ = nonce
)
