package api

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/workspaccode/6dx/backend/internal/auth"
	"github.com/workspaccode/6dx/backend/internal/db"
	"github.com/workspaccode/6dx/backend/internal/httpx"
)

// Role mirrors the `member_role` values. The capabilities are the ones the
// Postgres RLS policies enforced:
//
//	owner     — everything, including deleting the workspace and transfers
//	admin     — writes + manages developer/reviewer/viewer, never `owner`
//	developer — writes
//	reviewer  — writes
//	viewer    — read-only (the external client)
type Role string

const (
	RoleOwner     Role = "owner"
	RoleAdmin     Role = "admin"
	RoleDeveloper Role = "developer"
	RoleReviewer  Role = "reviewer"
	RoleViewer    Role = "viewer"
)

func (r Role) IsAdmin() bool  { return r == RoleOwner || r == RoleAdmin }
func (r Role) IsEditor() bool { return r != "" && r != RoleViewer }

// store is the thin data-access layer every handler shares.
type store struct {
	db *db.DB
}

// RoleIn returns the caller's role, or "" when they are not a member.
func (s *store) RoleIn(ctx context.Context, workspaceID, uid string) (Role, error) {
	var role string
	err := s.db.QueryRowContext(ctx,
		`select role from workspace_members where workspace_id = ? and user_uid = ?`,
		workspaceID, uid,
	).Scan(&role)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return Role(role), nil
}

// requireMember is `is_workspace_member()`.
func (s *store) requireMember(ctx context.Context, workspaceID, uid string) (Role, error) {
	role, err := s.RoleIn(ctx, workspaceID, uid)
	if err != nil {
		return "", err
	}
	if role == "" {
		return "", httpx.Forbidden("not_workspace_member", "أنت لست عضواً في مساحة العمل.")
	}
	return role, nil
}

// requireAdmin is `is_workspace_admin()`.
func (s *store) requireAdmin(ctx context.Context, workspaceID, uid string) (Role, error) {
	role, err := s.requireMember(ctx, workspaceID, uid)
	if err != nil {
		return "", err
	}
	if !role.IsAdmin() {
		return "", httpx.Forbidden("not_workspace_admin", "الأمر يحتاج صلاحية مدير في مساحة العمل.")
	}
	return role, nil
}

// requireEditor is `is_workspace_editor()`: viewers are read-only.
func (s *store) requireEditor(ctx context.Context, workspaceID, uid string) (Role, error) {
	role, err := s.requireMember(ctx, workspaceID, uid)
	if err != nil {
		return "", err
	}
	if !role.IsEditor() {
		return "", httpx.Forbidden("viewer_read_only", "حسابك للقراءة فقط في مساحة العمل هذه.")
	}
	return role, nil
}

// requireOwner guards deletion and transfer.
func (s *store) requireOwner(ctx context.Context, workspaceID, uid string) (Role, error) {
	role, err := s.requireMember(ctx, workspaceID, uid)
	if err != nil {
		return "", err
	}
	if role != RoleOwner {
		return "", httpx.Forbidden("not_workspace_owner", "الأمر خاص بمالك مساحة العمل.")
	}
	return role, nil
}

// upsertUser mirrors the caller into `users`. The uid is the identity the whole
// schema keys on, so callers resolve it from `github_id` first (see
// `withStoredIdentity`) instead of assuming one.
func (s *store) upsertUser(ctx context.Context, caller *auth.Caller) error {
	now := nowString()
	_, err := s.db.ExecContext(ctx, `
		insert into users (uid, email, display_name, photo_url, github_id, created_at, updated_at)
		values (?, nullif(?, ''), nullif(?, ''), nullif(?, ''), ?, ?, ?)
		on conflict (uid) do update set
			email        = coalesce(nullif(excluded.email, ''), users.email),
			display_name = coalesce(nullif(excluded.display_name, ''), users.display_name),
			photo_url    = coalesce(nullif(excluded.photo_url, ''), users.photo_url),
			github_id    = coalesce(excluded.github_id, users.github_id),
			updated_at   = excluded.updated_at`,
		caller.UID, caller.Email, caller.DisplayName, caller.PhotoURL,
		caller.GitHubID, now, now)
	return err
}

// logActivity appends to activity_events. The actor is always the caller — the
// old policy allowed an anonymous row, this does not.
func (s *store) logActivity(ctx context.Context, workspaceID, actorUID, kind, text string, projectID *string) error {
	_, err := s.db.ExecContext(ctx,
		`insert into activity_events (id, workspace_id, project_id, type, text, actor_uid, created_at)
		 values (?, ?, ?, ?, ?, ?, ?)`,
		newID(), workspaceID, projectID, kind, text, actorUID, nowString())
	return err
}

// --- small utilities --------------------------------------------------------

// newID returns a UUID v4 string. SQLite has no uuid type, and generating the
// id in Go keeps it identical on every engine.
func newID() string {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return fmt.Sprintf("fallback-%d", time.Now().UnixNano())
	}
	buf[6] = (buf[6] & 0x0f) | 0x40 // version 4
	buf[8] = (buf[8] & 0x3f) | 0x80 // variant 10
	return fmt.Sprintf("%s-%s-%s-%s-%s",
		hex.EncodeToString(buf[0:4]),
		hex.EncodeToString(buf[4:6]),
		hex.EncodeToString(buf[6:8]),
		hex.EncodeToString(buf[8:10]),
		hex.EncodeToString(buf[10:16]),
	)
}

// nowString is the single timestamp format the schema stores: RFC3339 in UTC,
// so string ordering and comparison are chronological.
func nowString() string { return time.Now().UTC().Format(time.RFC3339Nano) }

// timeAhead returns now+ttl in the same format.
func timeAhead(ttl time.Duration) string {
	return time.Now().UTC().Add(ttl).Format(time.RFC3339Nano)
}
