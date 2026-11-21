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
	// UID and SeesPrivate filter private projects: only the group's
	// managers and the project's own members see one.
	UID         string
	SeesPrivate bool
}

// tasks returns the filter for `alias.project_id`; bind g.args().
func (g snapScope) tasks(alias string) string {
	col := alias + ".project_id"
	filter := ` and ` + col + ` in (select id from projects where group_id = ?)`
	if g.Default {
		filter = ` and (` + col + ` is null or ` + col + ` in (select id from projects where group_id = ?))`
	}
	if !g.SeesPrivate {
		filter += ` and (` + col + ` is null or ` + col + ` not in (` + hiddenProjects + `))`
	}
	return filter
}

// projects returns the filter for a projects row `alias`; bind g.args().
func (g snapScope) projects(alias string) string {
	filter := ` and ` + alias + `.group_id = ?`
	if !g.SeesPrivate {
		filter += ` and ` + alias + `.id not in (` + hiddenProjects + `)`
	}
	return filter
}

// args are the parameters of tasks() / projects(), in order.
func (g snapScope) args() []any {
	if g.SeesPrivate {
		return []any{g.GroupID}
	}
	return []any{g.GroupID, g.UID}
}

// hiddenProjects: the private projects the caller (one ?) is not a member of.
const hiddenProjects = `select hp.id from projects hp where hp.visibility = 'private'
	and not exists (select 1 from project_members hm where hm.project_id = hp.id and hm.user_uid = ?)`

// withArgs prepends fixed parameters to the scope's.
func (g snapScope) withArgs(first ...any) []any {
	return append(first, g.args()...)
}

func scopeOf(a *groupAccess) snapScope {
	return snapScope{GroupID: a.ID, Default: a.IsDefault, Role: legacyRoleFor(a),
		UID: a.UID, SeesPrivate: a.seesPrivate()}
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

// taskGroup returns the group and project a task lives in ("" for no
// project = the default group).
func (s *store) taskGroup(ctx context.Context, workspaceID, taskID string) (string, string, error) {
	var groupID, projectID sql.NullString
	err := s.db.QueryRowContext(ctx, `
		select p.group_id, t.project_id from tasks t left join projects p on p.id = t.project_id
		where t.id = ? and t.workspace_id = ?`, taskID, workspaceID).Scan(&groupID, &projectID)
	if errors.Is(err, sql.ErrNoRows) {
		return "", "", notFound("task_not_found", "المهمة غير موجودة.")
	}
	return groupID.String, projectID.String, err
}

// requireTaskAccess guards writes to an existing task. A task in the default
// group keeps the legacy workspace-role rule (checked by the caller); a task
// in any other group needs the capability there. Either way a private
// project hides its tasks, and a read-only project override blocks writes.
func (s *Server) requireTaskAccess(r *http.Request, ws *Workspace, uid, taskID string, c Capability) error {
	groupID, projectID, err := s.store.taskGroup(r.Context(), ws.ID, taskID)
	if err != nil {
		return err
	}
	_, err = s.requireProjectCap(r.Context(), ws, uid, groupID, projectID, c)
	return err
}

// requireProjectCap resolves the caller's access to a project (group access
// narrowed by the project override) and asks for c. In the default group the
// legacy workspace role already decided, so only the project rules apply.
func (s *Server) requireProjectCap(ctx context.Context, ws *Workspace, uid, groupID, projectID string, c Capability) (*groupAccess, error) {
	if groupID == "" {
		return nil, nil
	}
	access, err := s.store.loadGroupAccess(ctx, ws, uid, groupID)
	if err != nil {
		// Do not reveal that a task exists in a group the caller cannot see.
		var appErr *httpx.Error
		if errors.As(err, &appErr) {
			return nil, notFound("task_not_found", "المهمة غير موجودة.")
		}
		return nil, err
	}
	if projectID != "" {
		if access, err = s.store.projectAccess(ctx, access, projectID); err != nil {
			return nil, err
		}
	}
	if access.IsDefault && access.ProjectAccess != projectRead {
		return access, nil
	}
	return access, access.require(c)
}
