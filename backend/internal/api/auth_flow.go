package api

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"

	"github.com/workspaccode/6dx/backend/internal/httpx"
)

// The GitHub OAuth **device flow**, proxied for the app.
//
// github.com/login/device/code and /login/oauth/access_token send no CORS
// headers, so a Flutter **web** build cannot call them straight from the
// browser. Routing the two calls through this API makes the sign-in identical
// on every platform the app ships (Android, iOS, macOS, Windows, Linux, web)
// and keeps the OAuth client id on the server instead of in the bundle.

const (
	githubDeviceCodePath = "/login/device/code"
	githubOAuthTokenPath = "/login/oauth/access_token"

	// identityScopes are the only permissions the sign-in asks for: enough to
	// read the profile and the verified e-mail. Repository access is granted
	// separately through the GitHub App.
	identityScopes = "read:user user:email"
)

// handleGithubDeviceCode asks GitHub for the code the user types on
// github.com.
func (s *Server) handleGithubDeviceCode(w http.ResponseWriter, r *http.Request) {
	if strings.TrimSpace(s.cfg.GitHubClientID) == "" {
		writeError(w, httpx.Unavailable(
			"github_login_not_configured",
			"تسجيل الدخول بجيت هب غير مُهيأ — اضبط GITHUB_CLIENT_ID في إعدادات الـ backend.",
		))
		return
	}
	s.forwardForm(w, r, githubDeviceCodePath, url.Values{
		"client_id": {s.cfg.GitHubClientID},
		"scope":     {identityScopes},
	})
}

// handleGithubDeviceToken polls GitHub for the token behind a device code.
// `authorization_pending` and `slow_down` are normal answers of the flow, so
// the response body is passed through untouched (with its `error` field).
func (s *Server) handleGithubDeviceToken(w http.ResponseWriter, r *http.Request) {
	if strings.TrimSpace(s.cfg.GitHubClientID) == "" {
		writeError(w, httpx.Unavailable(
			"github_login_not_configured",
			"تسجيل الدخول بجيت هب غير مُهيأ — اضبط GITHUB_CLIENT_ID في إعدادات الـ backend.",
		))
		return
	}

	var body struct {
		DeviceCode string `json:"device_code"`
	}
	// Public endpoint: cap the body before decoding it.
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4<<10)).Decode(&body); err != nil {
		writeError(w, httpx.BadRequest("invalid_body", "جسم الطلب غير صالح."))
		return
	}
	if len(body.DeviceCode) > 256 {
		writeError(w, httpx.BadRequest("invalid_device_code", "رمز الجهاز غير صالح."))
		return
	}
	if strings.TrimSpace(body.DeviceCode) == "" {
		writeError(w, httpx.BadRequest("missing_device_code", "رمز الجهاز مطلوب."))
		return
	}

	s.forwardForm(w, r, githubOAuthTokenPath, url.Values{
		"client_id":   {s.cfg.GitHubClientID},
		"device_code": {body.DeviceCode},
		"grant_type":  {"urn:ietf:params:oauth:grant-type:device_code"},
	})
}

// forwardForm POSTs a form-encoded body to the GitHub OAuth host and copies the
// answer back verbatim.
func (s *Server) forwardForm(
	w http.ResponseWriter,
	r *http.Request,
	path string,
	form url.Values,
) {
	endpoint := s.githubOAuthBase + path
	request, err := http.NewRequestWithContext(
		r.Context(),
		http.MethodPost,
		endpoint,
		strings.NewReader(form.Encode()),
	)
	if err != nil {
		writeError(w, httpx.Internal("github_request", "تعذّر تجهيز طلب GitHub."))
		return
	}
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	request.Header.Set("Accept", "application/json")

	response, err := s.httpClient.Do(request)
	if err != nil {
		slog.Error("github device flow", "path", path, "error", err)
		writeError(w, httpx.BadGateway(
			"github_unreachable",
			"تعذّر الاتصال بـ GitHub، حاول مرة أخرى.",
		))
		return
	}
	defer func() { _ = response.Body.Close() }()

	body, err := io.ReadAll(io.LimitReader(response.Body, 1<<20))
	if err != nil {
		writeError(w, httpx.BadGateway(
			"github_read_failed",
			"تعذّر قراءة رد GitHub.",
		))
		return
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(response.StatusCode)
	_, _ = w.Write(body)
}
