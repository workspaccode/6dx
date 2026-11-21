package api

import (
	"database/sql"
	"errors"
	"net/http"
)

// Workspace is the workspace the client is currently in.
type Workspace struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Role Role   `json:"role"`
}

// handleMe returns the caller's workspace (bootstrap + role).
// GET /v1/me
func (s *Server) handleMe(w http.ResponseWriter, r *http.Request) {
	caller, err := s.callerAndUpsert(r)
	if err != nil {
		writeError(w, err)
		return
	}
	ws, err := s.activeWorkspace(r, caller)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"workspace": ws,
		"user": map[string]any{
			"uid":          caller.UID,
			"email":        caller.Email,
			"display_name": caller.DisplayName,
			"photo_url":    caller.PhotoURL,
			"github_id":    caller.GitHubID,
		},
	})
}

// handleSnapshot returns the whole projection in one payload.
// GET /v1/workspace/snapshot
func (s *Server) handleSnapshot(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	// The projection of one group: ?group_id= / X-Group-Id, else the default.
	access, err := s.scopeGroup(r, ws, caller.UID)
	if err != nil {
		writeError(w, err)
		return
	}
	payload, err := s.store.snapshot(r.Context(), ws.ID, caller.UID, scopeOf(access))
	if err != nil {
		writeError(w, err)
		return
	}
	if payload == nil {
		writeError(w, notFound("workspace_not_found", "مساحة العمل غير موجودة."))
		return
	}
	writeJSON(w, http.StatusOK, payload)
}

// activeWorkspace resolves the caller's workspace (bootstrap on first sign-in).
//
// [preferred] is the workspace the client asked for (X-Workspace-Id). A user
// can belong to several workspaces — their own plus the ones they were invited
// to — so the active one must be selectable; falling back to "the first
// membership" would silently put an invited viewer back into their own
// workspace, where they are the owner.
func (s *Server) activeWorkspace(r *http.Request, caller *authCaller) (*Workspace, error) {
	preferred := r.Header.Get("X-Workspace-Id")
	if preferred != "" {
		var ws Workspace
		var role string
		err := s.store.db.QueryRowContext(r.Context(), `
			select w.id, w.name, m.role
			from workspace_members m
			join workspaces w on w.id = m.workspace_id
			where m.workspace_id = ? and m.user_uid = ?`,
			preferred, caller.UID,
		).Scan(&ws.ID, &ws.Name, &role)
		if errors.Is(err, sql.ErrNoRows) {
			return nil, forbidden("not_workspace_member",
				"أنت لست عضواً في مساحة العمل هذه.")
		}
		if err != nil {
			return nil, err
		}
		ws.Role = Role(role)
		return &ws, nil
	}

	// The first membership, or a brand-new workspace for a fresh account.
	var ws Workspace
	var role string
	err := s.store.db.QueryRowContext(r.Context(), `
		select w.id, w.name, m.role
		from workspace_members m
		join workspaces w on w.id = m.workspace_id
		where m.user_uid = ?
		order by m.created_at
		limit 1`, caller.UID,
	).Scan(&ws.ID, &ws.Name, &role)
	if err == nil {
		ws.Role = Role(role)
		return &ws, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return nil, err
	}

	// First sign-in: create the workspace + owner membership atomically.
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback() }()

	workspaceID := newID()
	slug := "ws-" + caller.UID
	if len(slug) > 24 {
		slug = slug[:24]
	}
	slug += "-" + workspaceID[:8]
	now := nowString()
	const defaultName = "مساحة عملي"

	if _, err := tx.ExecContext(r.Context(),
		`insert into workspaces (id, name, slug, owner_uid, settings, created_at, updated_at)
		 values (?, ?, ?, ?, '{}', ?, ?)`,
		workspaceID, defaultName, slug, caller.UID, now, now,
	); err != nil {
		return nil, err
	}
	if _, err := tx.ExecContext(r.Context(),
		`insert into workspace_members (workspace_id, user_uid, role, created_at)
		 values (?, ?, 'owner', ?)`, workspaceID, caller.UID, now,
	); err != nil {
		return nil, err
	}
	// Every workspace starts with one software group, led by its owner; the
	// legacy endpoints act on it.
	groupID := newID()
	if _, err := tx.ExecContext(r.Context(), `
		insert into groups (id, workspace_id, name, type, template, is_default,
		                    created_by, created_at, updated_at)
		values (?, ?, ?, 'software', 'scrum', 1, ?, ?, ?)`,
		groupID, workspaceID, defaultName, caller.UID, now, now,
	); err != nil {
		return nil, err
	}
	if err := joinGroup(r.Context(), tx, groupID, caller.UID, GroupLead,
		defaultLeadRole[GroupSoftware], now); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}

	return &Workspace{ID: workspaceID, Name: defaultName, Role: RoleOwner}, nil
}
