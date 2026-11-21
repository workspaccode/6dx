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

// SQL fragments, appended after a `where` on the given alias. They need no
// extra parameter: the default group is found from the row's workspace.
const (
	legacyTaskScope = ` and (t.project_id is null or t.project_id in (
		select p2.id from projects p2 join groups g2 on g2.id = p2.group_id
		where g2.workspace_id = t.workspace_id and g2.is_default = 1))`
	legacyProjectScope = ` and p.group_id in (
		select g2.id from groups g2 where g2.workspace_id = p.workspace_id and g2.is_default = 1)`
	legacyPRScope = ` and (pr.project_id is null or pr.project_id in (
		select p2.id from projects p2 join groups g2 on g2.id = p2.group_id
		where g2.workspace_id = pr.workspace_id and g2.is_default = 1))`
)

// scopeGroup resolves the group a list request reads: ?group_id= (after an
// access check) or the default group.
func (s *Server) scopeGroup(r *http.Request, ws *Workspace, uid string) (*groupAccess, error) {
	gid := r.URL.Query().Get("group_id")
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
