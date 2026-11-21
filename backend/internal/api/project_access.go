package api

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"strings"
)

// Project-level overrides and private projects — docs/design/groups-and-roles.md.
//
// A project inherits its group's roles. Two things narrow or widen that for
// one project:
//
//   - visibility = 'private': only the group's lead / admins and the
//     project's own members see it (its tasks, sprints, PRs…);
//   - a project_members row: access 'read' makes a member read-only there,
//     'edit' lets them edit tasks there, and an optional functional role
//     replaces their group one (a developer who reviews on one project).

const (
	projectRead = "read"
	projectEdit = "edit"
)

// seesPrivate: the group's managers (and a workspace admin administering the
// group) see every project in it.
func (a *groupAccess) seesPrivate() bool {
	return !a.IsMember || a.GroupRole.IsManager()
}

// readOnlyCaps is what a 'read' override keeps.
var readOnlyCaps = map[Capability]bool{
	CapViewGroup: true, CapComment: true, CapClientDecide: true, CapViewFinance: true,
}

// projectAccess narrows a group access to one project of that group. It
// returns a copy; a project the caller may not see is "not found".
func (s *store) projectAccess(ctx context.Context, a *groupAccess, projectID string) (*groupAccess, error) {
	var visibility string
	var functional, accessLevel sql.NullString
	err := s.db.QueryRowContext(ctx, `
		select p.visibility, pm.functional_role, pm.access
		from projects p
		left join project_members pm on pm.project_id = p.id and pm.user_uid = ?
		where p.id = ? and p.group_id = ?`, a.UID, projectID, a.ID,
	).Scan(&visibility, &functional, &accessLevel)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, notFound("project_not_found", "المشروع مش موجود في المجموعة دي.")
	}
	if err != nil {
		return nil, err
	}
	if visibility == "private" && !accessLevel.Valid && !a.seesPrivate() {
		return nil, notFound("project_not_found", "المشروع مش موجود في المجموعة دي.")
	}

	out := *a
	out.ProjectID = projectID
	out.ProjectVisibility = visibility
	out.ProjectAccess = accessLevel.String
	if !accessLevel.Valid || !a.IsMember || a.GroupRole == GroupLead {
		// No override, or someone the override cannot narrow (the lead holds
		// everything; a workspace admin outside the group has no operational
		// powers to narrow).
		return &out, nil
	}

	caps := a.Caps
	if functional.Valid && functional.String != "" && a.GroupRole != GroupGuest &&
		validFunctionalRole(a.Type, functional.String) {
		caps = capabilitiesFor(a.Type, a.GroupRole, functional.String)
		out.FunctionalRole = functional.String
	}
	narrowed := map[Capability]bool{}
	for c, ok := range caps {
		if ok && (accessLevel.String == projectEdit || readOnlyCaps[c]) {
			narrowed[c] = true
		}
	}
	if accessLevel.String == projectEdit && a.GroupRole != GroupGuest {
		narrowed[CapEditTasks] = true
	}
	if a.IsArchived {
		// An archived group stays read-only whatever the override says.
		for c := range narrowed {
			if c != CapViewGroup && c != CapManageGroup {
				delete(narrowed, c)
			}
		}
	}
	out.Caps = narrowed
	return &out, nil
}

// projectFromRequest: caller, group access ({gid}) narrowed to {pid}.
func (s *Server) projectFromRequest(r *http.Request) (*authCaller, *Workspace, *groupAccess, *groupAccess, error) {
	caller, ws, group, err := s.groupFromRequest(r)
	if err != nil {
		return nil, nil, nil, nil, err
	}
	project, err := s.store.projectAccess(r.Context(), group, r.PathValue("pid"))
	if err != nil {
		return nil, nil, nil, nil, err
	}
	return caller, ws, group, project, nil
}

// GET /v1/groups/{gid}/projects/{pid}/me — the caller's capabilities in one
// project (the app hides buttons from it).
func (s *Server) handleProjectMe(w http.ResponseWriter, r *http.Request) {
	_, _, _, project, err := s.projectFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"project": map[string]any{
		"id":              project.ProjectID,
		"group_id":        project.ID,
		"visibility":      project.ProjectVisibility,
		"override":        nullIfEmpty(project.ProjectAccess),
		"functional_role": nullIfEmpty(project.FunctionalRole),
		"capabilities":    sortedCaps(project.Caps),
	}})
}

type updateProjectRequest struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
	Visibility  *string `json:"visibility"`
}

// PATCH /v1/groups/{gid}/projects/{pid} — rename, describe, make private.
func (s *Server) handleUpdateGroupProject(w http.ResponseWriter, r *http.Request) {
	caller, ws, group, _, err := s.projectFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := group.require(CapManageProjects); err != nil {
		writeError(w, err)
		return
	}
	var body updateProjectRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if body.Name != nil {
		name := strings.TrimSpace(*body.Name)
		if name == "" || tooLong(name, maxProjectNameLength) {
			writeError(w, badRequest("invalid_name",
				fmt.Sprintf("اسم المشروع لازم يكون من 1 لـ %d حرف.", maxProjectNameLength)))
			return
		}
		body.Name = &name
	}
	if optionalTooLong(body.Description, maxProjectDescLength) {
		writeError(w, badRequest("description_too_long",
			fmt.Sprintf("وصف المشروع أطول من %d حرف.", maxProjectDescLength)))
		return
	}
	if body.Visibility != nil && *body.Visibility != "group" && *body.Visibility != "private" {
		writeError(w, badRequest("invalid_visibility", "الظهور لازم يكون group أو private."))
		return
	}
	// Who sees a project is the group's call (lead / admins), not a
	// functional role's: a tech lead with an override could otherwise flip a
	// private project open.
	if body.Visibility != nil {
		if err := group.require(CapManageGroup); err != nil {
			writeError(w, err)
			return
		}
	}
	pid := r.PathValue("pid")
	if _, err := s.store.db.ExecContext(r.Context(), `
		update projects set name = coalesce(?, name), description = coalesce(?, description),
		       visibility = coalesce(?, visibility), updated_at = ?
		where id = ? and group_id = ? and workspace_id = ?`,
		body.Name, body.Description, body.Visibility, nowString(), pid, group.ID, ws.ID); err != nil {
		writeError(w, err)
		return
	}
	if body.Visibility != nil {
		_ = s.store.logActivity(r.Context(), ws.ID, caller.UID, "project_visibility",
			"ظهور المشروع: "+*body.Visibility, &pid)
	}
	project, err := s.store.projectAccess(r.Context(), group, pid)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"project": map[string]any{
		"id": pid, "group_id": group.ID, "visibility": project.ProjectVisibility,
	}})
}

// GET /v1/groups/{gid}/projects/{pid}/members — the overrides on a project,
// for the group's lead / admins (a guest does not learn who is on a project).
func (s *Server) handleListProjectMembers(w http.ResponseWriter, r *http.Request) {
	_, _, group, _, err := s.projectFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := group.require(CapManageGroup); err != nil {
		writeError(w, err)
		return
	}
	rows, err := s.store.db.QueryContext(r.Context(), `
		select pm.user_uid, u.display_name, u.photo_url, pm.access, pm.functional_role,
		       gm.group_role, gm.functional_role
		from project_members pm
		join group_members gm on gm.group_id = ? and gm.user_uid = pm.user_uid
		left join users u on u.uid = pm.user_uid
		where pm.project_id = ?
		order by pm.created_at`, group.ID, r.PathValue("pid"))
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	members := make([]map[string]any, 0)
	for rows.Next() {
		var uid, access, groupRole, groupFunctional string
		var name, photo, functional *string
		if err := rows.Scan(&uid, &name, &photo, &access, &functional, &groupRole, &groupFunctional); err != nil {
			writeError(w, err)
			return
		}
		members = append(members, map[string]any{
			"uid":                   uid,
			"name":                  firstNonEmpty(name, &uid),
			"avatar_url":            photo,
			"access":                access,
			"functional_role":       functional,
			"group_role":            groupRole,
			"group_functional_role": groupFunctional,
		})
	}
	if err := rows.Err(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"members": members})
}

type projectMemberRequest struct {
	Access         string  `json:"access"`
	FunctionalRole *string `json:"functional_role"`
}

// PUT /v1/groups/{gid}/projects/{pid}/members/{uid} — set an override. The
// person must already be in the group: a project never lets an outsider in.
func (s *Server) handleSetProjectMember(w http.ResponseWriter, r *http.Request) {
	_, _, group, _, err := s.projectFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := group.require(CapManageGroup); err != nil {
		writeError(w, err)
		return
	}
	var body projectMemberRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if body.Access != projectRead && body.Access != projectEdit {
		writeError(w, badRequest("invalid_access", "الصلاحية لازم تكون edit أو read."))
		return
	}
	target := r.PathValue("uid")
	var targetRole string
	err = s.store.db.QueryRowContext(r.Context(),
		`select group_role from group_members where group_id = ? and user_uid = ?`,
		group.ID, target).Scan(&targetRole)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("member_not_found", "الشخص ده مش عضو في المجموعة."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if GroupRole(targetRole) == GroupLead {
		writeError(w, conflict("lead_not_overridable", "قائد المجموعة صلاحياته كاملة في كل المشاريع."))
		return
	}
	var functional any
	if body.FunctionalRole != nil && *body.FunctionalRole != "" {
		role := *body.FunctionalRole
		switch {
		case GroupRole(targetRole) == GroupGuest:
			writeError(w, badRequest("guest_role_fixed", "الضيف دوره ثابت (عميل)."))
			return
		case role == "client":
			writeError(w, badRequest("client_is_guest", "دور العميل لازم يكون ضيف."))
			return
		case !validFunctionalRole(group.Type, role):
			writeError(w, badRequest("invalid_functional_role", "الدور الوظيفي مش متاح لنوع المجموعة."))
			return
		}
		functional = role
	}
	if GroupRole(targetRole) == GroupGuest && body.Access == projectEdit {
		writeError(w, badRequest("guest_read_only", "الضيف صلاحيته قراءة بس."))
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into project_members (project_id, user_uid, functional_role, access, created_at)
		values (?, ?, ?, ?, ?)
		on conflict (project_id, user_uid) do update
		  set functional_role = excluded.functional_role, access = excluded.access`,
		r.PathValue("pid"), target, functional, body.Access, nowString()); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"uid": target, "access": body.Access, "functional_role": functional,
	})
}

// DELETE /v1/groups/{gid}/projects/{pid}/members/{uid} — back to the group
// roles (and out of a private project).
func (s *Server) handleRemoveProjectMember(w http.ResponseWriter, r *http.Request) {
	_, _, group, _, err := s.projectFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := group.require(CapManageGroup); err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(),
		`delete from project_members where project_id = ? and user_uid = ?`,
		r.PathValue("pid"), r.PathValue("uid")); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
