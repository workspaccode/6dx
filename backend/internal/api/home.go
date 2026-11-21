package api

import (
	"net/http"
	"time"
)

// GET /v1/groups/{gid}/home — what the group's home screen shows, by role:
//
//   - everyone: task counts per state category and per project (a guest's
//     whole view is this: progress, no names);
//   - a member: their own open tasks and how many are overdue;
//   - the lead / admins: the team (members, pending invites), blocked and
//     unassigned work.
//
// Private projects the caller is not in are left out of every number.
func (s *Server) handleGroupHome(w http.ResponseWriter, r *http.Request) {
	_, ws, access, err := s.groupFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	scope := scopeOf(access)
	ctx := r.Context()
	filter := scope.tasks("t")
	today := time.Now().UTC().Format("2006-01-02")

	// The task's category: its state's, else what its legacy status means.
	const category = `coalesce(st.category, case t.status when 'todo' then 'backlog'
		when 'done' then 'done' else 'active' end)`

	counts := map[string]int{"backlog": 0, "active": 0, "blocked": 0, "done": 0, "cancelled": 0}
	var overdue, unassigned int
	rows, err := s.store.db.QueryContext(ctx, `
		select `+category+`, count(*),
		       coalesce(sum(t.due_at is not null and t.due_at < ?), 0),
		       coalesce(sum(t.assignee_uid is null), 0)
		from tasks t
		left join workflow_states st on st.id = t.state_id
		where t.workspace_id = ?`+filter+`
		group by 1`, append([]any{today}, scope.withArgs(ws.ID)...)...)
	if err != nil {
		writeError(w, err)
		return
	}
	for rows.Next() {
		var cat string
		var n, late, free int
		if err := rows.Scan(&cat, &n, &late, &free); err != nil {
			rows.Close()
			writeError(w, err)
			return
		}
		counts[cat] = n
		if cat != "done" && cat != "cancelled" {
			overdue += late
			unassigned += free
		}
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		writeError(w, err)
		return
	}

	projects := make([]map[string]any, 0)
	projectRows, err := s.store.db.QueryContext(ctx, `
		select p.id, p.name, p.visibility,
		       (select count(*) from tasks t left join workflow_states st on st.id = t.state_id
		         where t.project_id = p.id and `+category+` not in ('done', 'cancelled')),
		       (select count(*) from tasks t left join workflow_states st on st.id = t.state_id
		         where t.project_id = p.id and `+category+` = 'done')
		from projects p
		where p.workspace_id = ? and p.is_archived = 0`+scope.projects("p")+`
		order by p.updated_at desc limit 50`, scope.withArgs(ws.ID)...)
	if err != nil {
		writeError(w, err)
		return
	}
	for projectRows.Next() {
		var id, name, visibility string
		var open, done int
		if err := projectRows.Scan(&id, &name, &visibility, &open, &done); err != nil {
			projectRows.Close()
			writeError(w, err)
			return
		}
		projects = append(projects, map[string]any{
			"id": id, "name": name, "visibility": visibility, "open_tasks": open, "done_tasks": done,
		})
	}
	projectRows.Close()
	if err := projectRows.Err(); err != nil {
		writeError(w, err)
		return
	}

	payload := map[string]any{
		"group":    access.json(),
		"counts":   counts,
		"projects": projects,
	}

	if access.IsMember && access.GroupRole != GroupGuest {
		mine := make([]map[string]any, 0)
		var myOverdue int
		taskRows, err := s.store.db.QueryContext(ctx, `
			select t.id, t.title, t.priority, t.due_at, t.project_id, p.name,
			       t.state_id, st.name, st.color, `+category+`
			from tasks t
			left join projects p on p.id = t.project_id
			left join workflow_states st on st.id = t.state_id
			where t.workspace_id = ? and t.assignee_uid = ?`+filter+`
			  and `+category+` not in ('done', 'cancelled')
			order by t.due_at is null, t.due_at,
			         case t.priority when 'urgent' then 0 when 'high' then 1
			                         when 'medium' then 2 else 3 end,
			         t.created_at desc
			limit 20`, append([]any{ws.ID, access.UID}, scope.args()...)...)
		if err != nil {
			writeError(w, err)
			return
		}
		for taskRows.Next() {
			var id, title, priority, cat string
			var dueAt, projectID, projectName, stateID, stateName, stateColor *string
			if err := taskRows.Scan(&id, &title, &priority, &dueAt, &projectID, &projectName,
				&stateID, &stateName, &stateColor, &cat); err != nil {
				taskRows.Close()
				writeError(w, err)
				return
			}
			if dueAt != nil && *dueAt < today {
				myOverdue++
			}
			mine = append(mine, map[string]any{
				"id": id, "title": title, "priority": priority, "due_at": dueAt,
				"project_id": projectID, "project_name": projectName,
				"state_id": stateID, "state_name": stateName, "state_color": stateColor,
				"category": cat,
			})
		}
		taskRows.Close()
		if err := taskRows.Err(); err != nil {
			writeError(w, err)
			return
		}
		payload["my_tasks"] = mine
		payload["my_overdue"] = myOverdue
	}

	if access.seesPrivate() {
		var members, invites int
		if err := s.store.db.QueryRowContext(ctx, `
			select (select count(*) from group_members where group_id = ?),
			       (select count(*) from workspace_invites
			         where group_id = ? and status = 'pending')`,
			access.ID, access.ID).Scan(&members, &invites); err != nil {
			writeError(w, err)
			return
		}
		payload["team"] = map[string]any{
			"members":         members,
			"pending_invites": invites,
			"blocked":         counts["blocked"],
			"unassigned":      unassigned,
			"overdue":         overdue,
		}
	}
	writeJSON(w, http.StatusOK, payload)
}
