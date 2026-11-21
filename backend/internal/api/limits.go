package api

import (
	"net/mail"
	"regexp"
	"strings"
	"unicode/utf8"
)

// Input limits. One place, so the numbers in docs/limits.md and the API agree.
const (
	maxInvitesPerRequest   = 50  // e-mails in one POST /v1/invites
	maxPendingInvitesPerWS = 500 // pending invites a workspace may hold
	maxEmailLength         = 254 // RFC 5321

	maxProjectNameLength = 80
	maxProjectDescLength = 2000
	maxTaskTitleLength   = 200
	maxTaskDescLength    = 10000
	maxRepoNameLength    = 140 // "owner/name" on GitHub is at most 39 + 1 + 100
)

// githubRepoPattern is GitHub's "owner/name" shape.
var githubRepoPattern = regexp.MustCompile(`^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})/[A-Za-z0-9._-]{1,100}$`)

// tooLong reports whether s has more than max characters (not bytes: Arabic
// text is two bytes per letter).
func tooLong(s string, max int) bool { return utf8.RuneCountInString(s) > max }

func optionalTooLong(s *string, max int) bool { return s != nil && tooLong(*s, max) }

// normalizeEmail returns the lower-cased bare address, or "" when raw is not a
// single valid address.
func normalizeEmail(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" || len(raw) > maxEmailLength {
		return ""
	}
	parsed, err := mail.ParseAddress(raw)
	if err != nil || parsed.Name != "" || parsed.Address != raw {
		return ""
	}
	return strings.ToLower(parsed.Address)
}

// truncate shortens s to max characters for echoing user input in a message.
func truncate(s string, max int) string {
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) <= max {
		return s
	}
	return string([]rune(s)[:max]) + "…"
}
