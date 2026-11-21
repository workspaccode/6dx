package api

import (
	"context"
	"database/sql"
	"errors"
	"net/http"

	"github.com/workspaccode/6dx/backend/internal/httpx"
)

// Group scoping for the pre-group endpoints.
//
// /v1/projects, /v1/tasks and the snapshot predate groups. They show the
// workspace's default group only (tasks without a project belong to it).
// Anything inside another group is reached through that group, after a
// membership check — otherwise every workspace member would see every
// private hardware project.

// snapScope is the group a projection reads. Rows carry a project_id; a row
// belongs to the group through its project, and rows with no project belong
// to the default group.
type snapScope struct {
	GroupID string
	Default bool
	// Role is the caller's group role in workspace-role vocabulary, for the
	// existing screens (owner = lead, viewer = guest).
	Role Role
}

// tasks returns the filter for `alias.project_id` (one ? = GroupID).
func (g snapScope) tasks(alias string) string {
	if g.Default {
		return ` and (` + alias + `.project_id is null or ` + alias +
			`.project_id in (select id from projects where group_id = ?))`
	}
	return ` and ` + alias + `.project_id in (select id from projects where group_id = ?)`
}

func scopeOf(a *groupAccess) snapScope {
	return snapScope{GroupID: a.ID, Default: a.IsDefault, Role: legacyRoleFor(a)}
}

// legacyRoleFor expresses a group role in the workspace-role vocabulary.
func legacyRoleFor(a *groupAccess) Role {
	switch {
	case !a.IsMember:
		return RoleAdmin // workspace owner/admin administering the group
	case a.GroupRole == GroupLead:
		return RoleOwner
	case a.GroupRole == GroupAdmin:
		return RoleAdmin
	case a.GroupRole == GroupGuest:
		return RoleViewer
	case a.FunctionalRole == "reviewer":
		return RoleReviewer
	default:
		return RoleDeveloper
	}
}

// scopeGroup resolves the group a list request reads: ?group_id= (after an
// access check) or the default group.
func (s *Server) scopeGroup(r *http.Request, ws *Workspace, uid string) (*groupAccess, error) {
	// ?group_id= wins; X-Group-Id is the app's "active group" (sent on
	// every request, like X-Workspace-Id).
	gid := r.URL.Query().Get("group_id")
	if gid == "" {
		gid = r.Header.Get("X-Group-Id")
	}
	if gid == "" {
		var err error
		if gid, err = s.store.defaultGroupID(r.Context(), ws.ID); err != nil {
			return nil, err
		}
	}
	return s.store.loadGroupAccess(r.Context(), ws, uid, gid)
}

// taskGroup returns the group a task lives in ("" for no project = default).
func (s *store) taskGroup(ctx context.Context, workspaceID, taskID string) (string, error) {
	var groupID sql.NullString
	err := s.db.QueryRowContext(ctx, `
		select p.group_id from tasks t left join projects p on p.id = t.project_id
		where t.id = ? and t.workspace_id = ?`, taskID, workspaceID).Scan(&groupID)
	if errors.Is(err, sql.ErrNoRows) {
		return "", notFound("task_not_found", "المهمة غير موجودة.")
	}
	return groupID.String, err
}

// requireTaskAccess guards writes to an existing task. A task in the default
// group keeps the legacy workspace-role rule (checked by the caller); a task
// in any other group needs the capability there.
func (s *Server) requireTaskAccess(r *http.Request, ws *Workspace, uid, taskID string, c Capability) error {
	groupID, err := s.store.taskGroup(r.Context(), ws.ID, taskID)
	if err != nil {
		return err
	}
	return s.requireGroupCapUnlessDefault(r.Context(), ws, uid, groupID, c)
}

func (s *Server) requireGroupCapUnlessDefault(ctx context.Context, ws *Workspace, uid, groupID string, c Capability) error {
	if groupID == "" {
		return nil
	}
	access, err := s.store.loadGroupAccess(ctx, ws, uid, groupID)
	if err != nil {
		// Do not reveal that a task exists in a group the caller cannot see.
		var appErr *httpx.Error
		if errors.As(err, &appErr) {
			return notFound("task_not_found", "المهمة غير موجودة.")
		}
		return err
	}
	if access.IsDefault {
		return nil
	}
	return access.require(c)
}
