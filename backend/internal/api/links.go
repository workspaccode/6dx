package api

import (
	"context"
	"database/sql"
	"errors"
	"net/http"
	"strings"
)

// Project links between groups — §3.1, migration 0007.
//
// Routes hang off one side: /v1/groups/{gid}/projects/{pid}/links/... The
// caller is resolved on that side (projectFromRequest: membership, private
// projects, overrides); the other project is only ever reached through an
// active link, and only as a summary — its tasks, BOM, prices and members
// stay with its own group.

type projectLink struct {
	ID           string
	FromProject  string
	ToProject    string
	Status       string
	Note         *string
	RequestedBy  *string
	OtherProject string
	Outgoing     bool // this side asked
}

// linkOf loads a link that has {pid} on one side.
func (s *store) linkOf(ctx context.Context, linkID, projectID string) (*projectLink, error) {
	l := &projectLink{}
	err := s.db.QueryRowContext(ctx, `
		select id, from_project, to_project, status, note, requested_by from project_links
		where id = ? and (from_project = ? or to_project = ?)`, linkID, projectID, projectID,
	).Scan(&l.ID, &l.FromProject, &l.ToProject, &l.Status, &l.Note, &l.RequestedBy)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, notFound("link_not_found", "الربط مش موجود.")
	}
	if err != nil {
		return nil, err
	}
	l.Outgoing = l.FromProject == projectID
	l.OtherProject = l.ToProject
	if !l.Outgoing {
		l.OtherProject = l.FromProject
	}
	return l, nil
}

// linkSide: the caller's side of a link route — a member who is not a guest
// (the client sees no other group's work).
func (s *Server) linkSide(r *http.Request) (*authCaller, *Workspace, *groupAccess, *groupAccess, error) {
	caller, ws, group, project, err := s.projectFromRequest(r)
	if err != nil {
		return nil, nil, nil, nil, err
	}
	if group.IsMember && group.GroupRole == GroupGuest {
		return nil, nil, nil, nil, forbidden("guest_no_links", "العميل مايشوفش المشاريع المرتبطة.")
	}
	return caller, ws, group, project, nil
}

type otherProjectInfo struct {
	ID, Name, GroupID, GroupName, GroupType string
}

func (s *store) otherProject(ctx context.Context, workspaceID, projectID string) (*otherProjectInfo, error) {
	o := &otherProjectInfo{}
	err := s.db.QueryRowContext(ctx, `
		select p.id, p.name, g.id, g.name, g.type from projects p join groups g on g.id = p.group_id
		where p.id = ? and p.workspace_id = ? and p.visibility = 'group'`, projectID, workspaceID,
	).Scan(&o.ID, &o.Name, &o.GroupID, &o.GroupName, &o.GroupType)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, notFound("project_not_found", "المشروع مش موجود.")
	}
	return o, err
}

// GET .../links — this project's links, both directions.
func (s *Server) handleListLinks(w http.ResponseWriter, r *http.Request) {
	_, ws, group, project, err := s.linkSide(r)
	if err != nil {
		writeError(w, err)
		return
	}
	rows, err := s.store.db.QueryContext(r.Context(), `
		select l.id, l.status, l.note, l.from_project = ?,
		       case when l.from_project = ? then l.to_project else l.from_project end,
		       l.created_at
		from project_links l
		where (l.from_project = ? or l.to_project = ?) and l.status <> 'revoked'
		order by l.status, l.created_at desc`,
		project.ProjectID, project.ProjectID, project.ProjectID, project.ProjectID)
	if err != nil {
		writeError(w, err)
		return
	}
	type row struct {
		id, status, other, created string
		note                       *string
		outgoing                   bool
	}
	list := []row{}
	for rows.Next() {
		var x row
		if err := rows.Scan(&x.id, &x.status, &x.note, &x.outgoing, &x.other, &x.created); err != nil {
			rows.Close()
			writeError(w, err)
			return
		}
		list = append(list, x)
	}
	rows.Close()
	out := make([]map[string]any, 0, len(list))
	for _, x := range list {
		other, err := s.store.otherProject(r.Context(), ws.ID, x.other)
		if err != nil {
			continue
		}
		out = append(out, map[string]any{
			"id": x.id, "status": x.status, "note": x.note, "outgoing": x.outgoing, "created_at": x.created,
			"other": map[string]any{
				"project_id": other.ID, "project_name": other.Name,
				"group_id": other.GroupID, "group_name": other.GroupName, "group_type": other.GroupType,
			},
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"links": out, "can_manage": group.can(CapManageGroup)})
}

// GET .../links/candidates — projects of other groups this project could be
// linked to: same workspace, not private, not archived. For the lead /
// admins who request links.
func (s *Server) handleLinkCandidates(w http.ResponseWriter, r *http.Request) {
	_, ws, group, project, err := s.linkSide(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := group.require(CapManageGroup); err != nil {
		writeError(w, err)
		return
	}
	rows, err := s.store.db.QueryContext(r.Context(), `
		select p.id, p.name, g.id, g.name, g.type
		from projects p join groups g on g.id = p.group_id
		where p.workspace_id = ? and g.id <> ? and g.is_archived = 0
		  and p.is_archived = 0 and p.visibility = 'group'
		  and not exists (select 1 from project_links l where l.status <> 'revoked'
		       and ((l.from_project = ? and l.to_project = p.id) or (l.to_project = ? and l.from_project = p.id)))
		order by g.name, p.name limit 200`, ws.ID, group.ID, project.ProjectID, project.ProjectID)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	out := make([]map[string]any, 0)
	for rows.Next() {
		var id, name, gid, gname, gtype string
		if err := rows.Scan(&id, &name, &gid, &gname, &gtype); err != nil {
			writeError(w, err)
			return
		}
		out = append(out, map[string]any{
			"project_id": id, "project_name": name, "group_id": gid, "group_name": gname, "group_type": gtype,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"projects": out})
}

// POST .../links {to_project_id, note} — ask the other group.
func (s *Server) handleRequestLink(w http.ResponseWriter, r *http.Request) {
	caller, ws, group, project, err := s.linkSide(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := group.require(CapManageGroup); err != nil {
		writeError(w, err)
		return
	}
	if err := s.store.linkableSide(r.Context(), group, project.ProjectID); err != nil {
		writeError(w, err)
		return
	}
	var body struct {
		ToProjectID string  `json:"to_project_id"`
		Note        *string `json:"note"`
	}
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	note, err := optionalText(body.Note, 500, "note_too_long", "الملاحظة")
	if err != nil {
		writeError(w, err)
		return
	}
	// The target: same workspace, another group, visible to the group (a
	// private project is never offered), neither archived.
	var targetGroup, visibility string
	var archived, groupArchived int
	err = s.store.db.QueryRowContext(r.Context(), `
		select p.group_id, p.visibility, p.is_archived, g.is_archived
		from projects p join groups g on g.id = p.group_id
		where p.id = ? and p.workspace_id = ?`, body.ToProjectID, ws.ID,
	).Scan(&targetGroup, &visibility, &archived, &groupArchived)
	if errors.Is(err, sql.ErrNoRows) || (err == nil && visibility == "private") {
		writeError(w, notFound("project_not_found", "المشروع مش موجود في مساحة العمل دي."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if targetGroup == group.ID {
		writeError(w, conflict("same_group", "المشروعين في نفس المجموعة. الربط بين مجموعتين بس."))
		return
	}
	if archived == 1 || groupArchived == 1 {
		writeError(w, conflict("target_archived", "المشروع التاني أو مجموعته متأرشفين."))
		return
	}
	now := nowString()
	id := newID()
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into project_links (id, from_project, to_project, note, requested_by, created_at, updated_at)
		values (?, ?, ?, ?, ?, ?, ?)`, id, project.ProjectID, body.ToProjectID, note, caller.UID, now, now); err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			writeError(w, conflict("link_exists", "في ربط أو طلب ربط بين المشروعين دول."))
			return
		}
		writeError(w, err)
		return
	}
	pid := project.ProjectID
	_ = s.store.logActivity(r.Context(), ws.ID, caller.UID, "link_requested", "طلب ربط مع مشروع في مجموعة تانية", &pid)
	writeJSON(w, http.StatusCreated, map[string]any{"link": map[string]any{"id": id, "status": "requested"}})
}

// POST .../links/{lid}/approve — the lead / an admin of the side that was
// asked.
func (s *Server) handleApproveLink(w http.ResponseWriter, r *http.Request) {
	caller, _, group, project, err := s.linkSide(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := group.require(CapManageGroup); err != nil {
		writeError(w, err)
		return
	}
	link, err := s.store.linkOf(r.Context(), r.PathValue("lid"), project.ProjectID)
	if err != nil {
		writeError(w, err)
		return
	}
	if link.Outgoing {
		writeError(w, forbidden("other_side_approves", "الموافقة من المجموعة التانية."))
		return
	}
	if err := s.store.linkableSide(r.Context(), group, project.ProjectID); err != nil {
		writeError(w, err)
		return
	}
	// The asking side may have gone private or been archived since.
	var reqArchived, reqGroupArchived int
	var reqVisibility string
	if err := s.store.db.QueryRowContext(r.Context(), `
		select p.is_archived, g.is_archived, p.visibility from projects p join groups g on g.id = p.group_id
		where p.id = ?`, link.OtherProject).Scan(&reqArchived, &reqGroupArchived, &reqVisibility); err != nil {
		writeError(w, err)
		return
	}
	if reqArchived == 1 || reqGroupArchived == 1 || reqVisibility != "group" {
		writeError(w, conflict("link_side_unavailable", "المشروع اللي طلب الربط مبقاش متاح."))
		return
	}
	result, err := s.store.db.ExecContext(r.Context(), `
		update project_links set status = 'active', approved_by = ?, updated_at = ?
		where id = ? and status = 'requested'`, caller.UID, nowString(), link.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	if n, _ := result.RowsAffected(); n == 0 {
		writeError(w, conflict("link_not_requested", "الربط مش مستني موافقة."))
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"link": map[string]any{"id": link.ID, "status": "active"}})
}

// POST .../links/{lid}/revoke — either side, any time (also declines or
// withdraws a request).
func (s *Server) handleRevokeLink(w http.ResponseWriter, r *http.Request) {
	caller, _, group, project, err := s.linkSide(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := group.require(CapManageGroup); err != nil {
		writeError(w, err)
		return
	}
	link, err := s.store.linkOf(r.Context(), r.PathValue("lid"), project.ProjectID)
	if err != nil {
		writeError(w, err)
		return
	}
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	if err := revokeLink(r.Context(), tx, link.ID, caller.UID); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"link": map[string]any{"id": link.ID, "status": "revoked"}})
}

// revokeLink ends a link and its dependencies (a later link between the
// same projects starts clean).
func revokeLink(ctx context.Context, q queryer, linkID, uid string) error {
	if _, err := q.ExecContext(ctx, `delete from link_task_deps where link_id = ?`, linkID); err != nil {
		return err
	}
	_, err := q.ExecContext(ctx, `
		update project_links set status = 'revoked', revoked_by = ?, updated_at = ?
		where id = ? and status <> 'revoked'`, uid, nowString(), linkID)
	return err
}

// revokeProjectLinks ends every live link of a project.
func revokeProjectLinks(ctx context.Context, q queryer, projectID, uid string) error {
	if _, err := q.ExecContext(ctx, `
		delete from link_task_deps where link_id in (select id from project_links
		  where (from_project = ? or to_project = ?) and status <> 'revoked')`, projectID, projectID); err != nil {
		return err
	}
	_, err := q.ExecContext(ctx, `
		update project_links set status = 'revoked', revoked_by = ?, updated_at = ?
		where (from_project = ? or to_project = ?) and status <> 'revoked'`, uid, nowString(), projectID, projectID)
	return err
}

// linkableSide: an archived group or project neither asks for nor accepts
// links.
func (s *store) linkableSide(ctx context.Context, group *groupAccess, projectID string) error {
	if group.IsArchived {
		return conflict("group_archived", "المجموعة مأرشفة.")
	}
	var archived int
	if err := s.db.QueryRowContext(ctx, `select is_archived from projects where id = ?`, projectID).Scan(&archived); err != nil {
		return err
	}
	if archived == 1 {
		return conflict("project_archived", "المشروع متأرشف.")
	}
	return nil
}

// activeLink: a link of {pid} that is active.
func (s *Server) activeLink(r *http.Request, projectID string) (*projectLink, error) {
	link, err := s.store.linkOf(r.Context(), r.PathValue("lid"), projectID)
	if err != nil {
		return nil, err
	}
	if link.Status != "active" {
		return nil, conflict("link_not_active", "الربط مش مفعّل.")
	}
	return link, nil
}

// GET .../links/{lid}/summary — what a link shows of the other project:
// hardware = phases, latest released BOM revision, firmware ↔ HW matrix;
// software = task progress. Plus the cross-project dependencies, with the
// other side's task title and status only.
func (s *Server) handleLinkSummary(w http.ResponseWriter, r *http.Request) {
	_, ws, _, project, err := s.linkSide(r)
	if err != nil {
		writeError(w, err)
		return
	}
	link, err := s.activeLink(r, project.ProjectID)
	if err != nil {
		writeError(w, err)
		return
	}
	other, err := s.store.otherProject(r.Context(), ws.ID, link.OtherProject)
	if err != nil {
		writeError(w, err)
		return
	}
	ctx := r.Context()
	summary := map[string]any{
		"project_id": other.ID, "project_name": other.Name, "group_name": other.GroupName,
		"group_type": other.GroupType,
	}
	var open, done int
	if err := s.store.db.QueryRowContext(ctx, `
		select coalesce(sum(status <> 'done'), 0), coalesce(sum(status = 'done'), 0)
		from tasks where project_id = ?`, other.ID).Scan(&open, &done); err != nil {
		writeError(w, err)
		return
	}
	summary["open_tasks"], summary["done_tasks"] = open, done

	if other.GroupType == string(GroupHardware) {
		phases := make([]map[string]any, 0)
		rows, err := s.store.db.QueryContext(ctx,
			`select name, status from hw_phases where project_id = ? order by ord, created_at`, other.ID)
		if err != nil {
			writeError(w, err)
			return
		}
		for rows.Next() {
			var name, status string
			if err := rows.Scan(&name, &status); err != nil {
				rows.Close()
				writeError(w, err)
				return
			}
			phases = append(phases, map[string]any{"name": name, "status": status})
		}
		rows.Close()
		summary["phases"] = phases
		var rev sql.NullString
		_ = s.store.db.QueryRowContext(ctx, `
			select rev from hw_bom_revs where project_id = ? and status = 'released'
			order by length(rev) desc, rev desc limit 1`, other.ID).Scan(&rev)
		summary["released_bom"] = nullString(rev)
		firmware := make([]map[string]any, 0)
		fw, err := s.store.db.QueryContext(ctx, `
			select f.firmware_tag, b.rev from hw_fw_compat f join hw_bom_revs b on b.id = f.bom_rev_id
			where f.project_id = ? and b.status = 'released' order by f.verified_at desc limit 50`, other.ID)
		if err != nil {
			writeError(w, err)
			return
		}
		for fw.Next() {
			var tag, rev string
			if err := fw.Scan(&tag, &rev); err != nil {
				fw.Close()
				writeError(w, err)
				return
			}
			firmware = append(firmware, map[string]any{"firmware_tag": tag, "bom_rev": rev})
		}
		fw.Close()
		summary["firmware"] = firmware
	}

	deps, err := s.linkDeps(ctx, link.ID, project.ProjectID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"summary": summary, "dependencies": deps, "can_edit": project.can(CapEditTasks),
	})
}

// linkDeps lists the dependencies of a link from {projectID}'s side: each
// row names the local task (full title) and the remote one (title + status).
func (s *Server) linkDeps(ctx context.Context, linkID, projectID string) ([]map[string]any, error) {
	rows, err := s.store.db.QueryContext(ctx, `
		select d.id, a.id, a.title, a.status, a.project_id = ?, b.id, b.title, b.status
		from link_task_deps d
		join tasks a on a.id = d.task_id
		join tasks b on b.id = d.depends_on
		where d.link_id = ? order by d.created_at`, projectID, linkID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]map[string]any, 0)
	for rows.Next() {
		var id, aID, aTitle, aStatus, bID, bTitle, bStatus string
		var aMine bool
		if err := rows.Scan(&id, &aID, &aTitle, &aStatus, &aMine, &bID, &bTitle, &bStatus); err != nil {
			return nil, err
		}
		out = append(out, map[string]any{
			"id":         id,
			"waiting":    map[string]any{"task_id": aID, "title": aTitle, "status": aStatus, "mine": aMine},
			"depends_on": map[string]any{"task_id": bID, "title": bTitle, "status": bStatus, "mine": !aMine},
		})
	}
	return out, rows.Err()
}

// GET .../links/{lid}/tasks — the other project's open tasks to pick a
// dependency from: id, title, status only.
func (s *Server) handleLinkTasks(w http.ResponseWriter, r *http.Request) {
	_, ws, _, project, err := s.linkSide(r)
	if err != nil {
		writeError(w, err)
		return
	}
	link, err := s.activeLink(r, project.ProjectID)
	if err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.otherProject(r.Context(), ws.ID, link.OtherProject); err != nil {
		writeError(w, err)
		return
	}
	rows, err := s.store.db.QueryContext(r.Context(), `
		select id, title, status from tasks where project_id = ? and status <> 'done'
		order by created_at desc limit 200`, link.OtherProject)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	out := make([]map[string]any, 0)
	for rows.Next() {
		var id, title, status string
		if err := rows.Scan(&id, &title, &status); err != nil {
			writeError(w, err)
			return
		}
		out = append(out, map[string]any{"task_id": id, "title": title, "status": status})
	}
	writeJSON(w, http.StatusOK, map[string]any{"tasks": out})
}

// POST .../links/{lid}/deps {task_id, depends_on} — a task of this project
// waits for a task of the other one.
func (s *Server) handleAddLinkDep(w http.ResponseWriter, r *http.Request) {
	caller, ws, _, project, err := s.linkSide(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := project.require(CapEditTasks); err != nil {
		writeError(w, err)
		return
	}
	link, err := s.activeLink(r, project.ProjectID)
	if err != nil {
		writeError(w, err)
		return
	}
	var body struct {
		TaskID    string `json:"task_id"`
		DependsOn string `json:"depends_on"`
	}
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	in := func(taskID, projectID string) bool {
		var one int
		return s.store.db.QueryRowContext(r.Context(),
			`select 1 from tasks where id = ? and project_id = ? and workspace_id = ?`,
			taskID, projectID, ws.ID).Scan(&one) == nil
	}
	if !in(body.TaskID, project.ProjectID) || !in(body.DependsOn, link.OtherProject) {
		writeError(w, notFound("task_not_found", "المهمة لازم تكون من المشروع ده، واللي بتعتمد عليها من المشروع المربوط."))
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into link_task_deps (id, link_id, task_id, depends_on, created_by, created_at)
		values (?, ?, ?, ?, ?, ?)`, newID(), link.ID, body.TaskID, body.DependsOn, caller.UID, nowString()); err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			writeError(w, conflict("dependency_exists", "الاعتماد ده موجود."))
			return
		}
		writeError(w, err)
		return
	}
	deps, err := s.linkDeps(r.Context(), link.ID, project.ProjectID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"dependencies": deps})
}

// DELETE .../links/{lid}/deps/{did} — from the side that owns the waiting
// task.
func (s *Server) handleDeleteLinkDep(w http.ResponseWriter, r *http.Request) {
	_, _, _, project, err := s.linkSide(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := project.require(CapEditTasks); err != nil {
		writeError(w, err)
		return
	}
	link, err := s.store.linkOf(r.Context(), r.PathValue("lid"), project.ProjectID)
	if err != nil {
		writeError(w, err)
		return
	}
	result, err := s.store.db.ExecContext(r.Context(), `
		delete from link_task_deps where id = ? and link_id = ?
		  and task_id in (select id from tasks where project_id = ?)`,
		r.PathValue("did"), link.ID, project.ProjectID)
	if err != nil {
		writeError(w, err)
		return
	}
	if n, _ := result.RowsAffected(); n == 0 {
		writeError(w, notFound("dependency_not_found", "الاعتماد مش موجود في المشروع ده."))
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
