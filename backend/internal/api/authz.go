package api

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/workspaccode/6dx/backend/internal/auth"
	"github.com/workspaccode/6dx/backend/internal/httpx"
)

// Role mirrors the `member_role` enum. The values and their capabilities are
// the ones the Postgres RLS policies enforced:
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
	pool *pgxpool.Pool
}

// RoleIn returns the caller's role, or "" when they are not a member.
func (s *store) RoleIn(ctx context.Context, workspaceID, uid string) (Role, error) {
	var role string
	err := s.pool.QueryRow(ctx,
		`select role::text from workspace_members
		  where workspace_id = $1 and user_uid = $2`,
		workspaceID, uid,
	).Scan(&role)
	if errors.Is(err, pgx.ErrNoRows) {
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

// requireEditor is `is_workspace_editor()` (0004): viewers are read-only.
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

// upsertUser keeps the local mirror of the Firebase identity fresh. The email,
// name, avatar and GitHub id come from the verified token, never from the
// request body.
func (s *store) upsertUser(ctx context.Context, caller *auth.Caller) error {
	_, err := s.pool.Exec(ctx, `
		insert into users (uid, email, display_name, photo_url, github_id)
		values ($1, nullif($2, ''), nullif($3, ''), nullif($4, ''), $5)
		on conflict (uid) do update
		  set email        = coalesce(nullif(excluded.email, ''), users.email),
		      display_name = coalesce(nullif(excluded.display_name, ''), users.display_name),
		      photo_url    = coalesce(nullif(excluded.photo_url, ''), users.photo_url),
		      github_id    = coalesce(excluded.github_id, users.github_id),
		      updated_at   = now()`,
		caller.UID, caller.Email, caller.DisplayName, caller.PhotoURL, caller.GitHubID)
	return err
}

// logActivity appends to activity_events. The actor is always the caller —
// the old `activity_insert` policy allowed an anonymous row, this does not.
func (s *store) logActivity(ctx context.Context, workspaceID, actorUID, kind, text string, projectID *string) error {
	_, err := s.pool.Exec(ctx,
		`insert into activity_events (workspace_id, project_id, type, text, actor_uid)
		 values ($1, $2, $3, $4, $5)`,
		workspaceID, projectID, kind, text, actorUID)
	return err
}
