package api

import (
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"strings"
)

type createTaskRequest struct {
	Title       string  `json:"title"`
	Description *string `json:"description"`
	ProjectID   *string `json:"project_id"`
	Priority    *string `json:"priority"`
	// StateID puts the task in one of its group's states (default: the
	// group's first backlog state).
	StateID *string `json:"state_id"`
}

// GET /v1/tasks?project_id=
func (s *Server) handleListTasks(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	access, err := s.scopeGroup(r, ws, caller.UID)
	if err != nil {
		writeError(w, err)
		return
	}

	query := `
		select t.id, t.title, t.description, t.status, t.priority,
		       t.project_id, p.name, t.label, t.branch, t.pr_number,
		       t.due_at, t.created_at, t.state_id
		from tasks t
		left join projects p on p.id = t.project_id
		where t.workspace_id = ?`
	// The group's tasks, minus private projects the caller is not in.
	scope := scopeOf(access)
	query += scope.tasks("t")
	args := scope.withArgs(ws.ID)
	if projectID := strings.TrimSpace(r.URL.Query().Get("project_id")); projectID != "" {
		query += ` and t.project_id = ?`
		args = append(args, projectID)
	}
	query += ` order by t.created_at desc`

	rows, err := s.store.db.QueryContext(r.Context(), query, args...)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()

	tasks := make([]map[string]any, 0)
	for rows.Next() {
		task, err := scanTask(rows)
		if err != nil {
			writeError(w, err)
			return
		}
		tasks = append(tasks, task)
	}
	writeJSON(w, http.StatusOK, map[string]any{"tasks": tasks})
}

func scanTask(rows interface {
	Scan(dest ...any) error
}) (map[string]any, error) {
	var (
		id, title, status, priority, createdAt string
		description, projectID, projectName    *string
		label, branch, dueAt, stateID          *string
		prNumber                               *int
	)
	if err := rows.Scan(&id, &title, &description, &status, &priority,
		&projectID, &projectName, &label, &branch, &prNumber, &dueAt,
		&createdAt, &stateID); err != nil {
		return nil, err
	}
	return map[string]any{
		"id":           id,
		"title":        title,
		"description":  description,
		"status":       status,
		"state_id":     stateID,
		"priority":     priority,
		"project_id":   projectID,
		"project_name": projectName,
		"label":        label,
		"branch":       branch,
		"pr_number":    prNumber,
		"due_at":       dueAt,
		"created_at":   createdAt,
	}, nil
}

// POST /v1/tasks
func (s *Server) handleCreateTask(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
		writeError(w, err)
		return
	}

	var body createTaskRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	body.Title = strings.TrimSpace(body.Title)
	if body.Title == "" {
		writeError(w, badRequest("title_required", "عنوان المهمة مطلوب."))
		return
	}
	if tooLong(body.Title, maxTaskTitleLength) {
		writeError(w, badRequest("title_too_long",
			fmt.Sprintf("عنوان المهمة أطول من %d حرف.", maxTaskTitleLength)))
		return
	}
	if optionalTooLong(body.Description, maxTaskDescLength) {
		writeError(w, badRequest("description_too_long",
			fmt.Sprintf("وصف المهمة أطول من %d حرف.", maxTaskDescLength)))
		return
	}
	// The project must belong to this workspace: the foreign key only checks
	// that it exists somewhere (docs/review/04-backend.md).
	var taskGroupID string
	if body.ProjectID != nil && *body.ProjectID != "" {
		var groupID sql.NullString
		err := s.store.db.QueryRowContext(r.Context(),
			`select group_id from projects where id = ? and workspace_id = ?`,
			*body.ProjectID, ws.ID).Scan(&groupID)
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, notFound("project_not_found", "المشروع مش موجود في مساحة العمل دي."))
			return
		}
		if err != nil {
			writeError(w, err)
			return
		}
		if _, err := s.requireProjectCap(r.Context(), ws, caller.UID, groupID.String, *body.ProjectID, CapEditTasks); err != nil {
			writeError(w, err)
			return
		}
		taskGroupID = groupID.String
	}
	if taskGroupID == "" {
		if taskGroupID, err = s.store.defaultGroupID(r.Context(), ws.ID); err != nil {
			writeError(w, err)
			return
		}
	}
	status := "todo"
	if body.StateID != nil && *body.StateID != "" {
		if status, err = s.store.stateForTask(r.Context(), taskGroupID, *body.StateID); err != nil {
			writeError(w, err)
			return
		}
	} else {
		body.StateID = nil // the trigger picks the group's first backlog state
	}
	priority := "medium"
	if body.Priority != nil && *body.Priority != "" {
		switch *body.Priority {
		case "low", "medium", "high", "urgent":
			priority = *body.Priority
		default:
			writeError(w, badRequest("invalid_priority", "أولوية المهمة غير معروفة."))
			return
		}
	}

	taskID := newID()
	now := nowString()
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into tasks (id, workspace_id, project_id, title, description,
		                   status, state_id, priority, points, created_at, updated_at)
		values (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)`,
		taskID, ws.ID, body.ProjectID, body.Title, body.Description, status, body.StateID,
		priority, now, now,
	); err != nil {
		writeError(w, err)
		return
	}

	task, err := s.taskByID(r, taskID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"task": task})
}

func (s *Server) taskByID(r *http.Request, taskID string) (map[string]any, error) {
	row := s.store.db.QueryRowContext(r.Context(), `
		select t.id, t.title, t.description, t.status, t.priority,
		       t.project_id, p.name, t.label, t.branch, t.pr_number,
		       t.due_at, t.created_at, t.state_id
		from tasks t
		left join projects p on p.id = t.project_id
		where t.id = ?`, taskID)
	task, err := scanTask(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, notFound("task_not_found", "المهمة غير موجودة.")
	}
	return task, err
}

type updateStatusRequest struct {
	Status string `json:"status"`
	// StateID moves the task to one of its group's states; status then
	// follows the state's legacy status. Either field may be sent.
	StateID string `json:"state_id"`
}

// PATCH /v1/tasks/{id}/status
func (s *Server) handleUpdateTaskStatus(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
		writeError(w, err)
		return
	}

	var body updateStatusRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	taskID := r.PathValue("id")
	if err := s.requireTaskAccess(r, ws, caller.UID, taskID, CapEditTasks); err != nil {
		writeError(w, err)
		return
	}
	var stateID any
	if body.StateID != "" {
		groupID, _, err := s.store.taskGroup(r.Context(), ws.ID, taskID)
		if err != nil {
			writeError(w, err)
			return
		}
		if groupID == "" {
			if groupID, err = s.store.defaultGroupID(r.Context(), ws.ID); err != nil {
				writeError(w, err)
				return
			}
		}
		if body.Status, err = s.store.stateForTask(r.Context(), groupID, body.StateID); err != nil {
			writeError(w, err)
			return
		}
		stateID = body.StateID
	}
	switch body.Status {
	case "todo", "in_progress", "review", "done":
	default:
		writeError(w, badRequest("invalid_status", "حالة المهمة غير معروفة."))
		return
	}
	// With a status only, state_id stays and the trigger re-picks it when
	// its legacy status no longer matches.
	result, err := s.store.db.ExecContext(r.Context(),
		`update tasks set status = ?, state_id = coalesce(?, state_id), updated_at = ?
		  where id = ? and workspace_id = ?`,
		body.Status, stateID, nowString(), taskID, ws.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		writeError(w, notFound("task_not_found", "المهمة غير موجودة."))
		return
	}

	task, err := s.taskByID(r, taskID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"task": task})
}

// DELETE /v1/tasks/{id}
func (s *Server) handleDeleteTask(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
		writeError(w, err)
		return
	}

	if err := s.requireTaskAccess(r, ws, caller.UID, r.PathValue("id"), CapEditTasks); err != nil {
		writeError(w, err)
		return
	}
	result, err := s.store.db.ExecContext(r.Context(),
		`delete from tasks where id = ? and workspace_id = ?`, r.PathValue("id"), ws.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		writeError(w, notFound("task_not_found", "المهمة غير موجودة."))
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// POST /v1/pull-requests/{number}/review
func (s *Server) handleReviewPullRequest(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
		writeError(w, err)
		return
	}

	var body struct {
		Approve bool `json:"approve"`
	}
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	state := "changes_requested"
	if body.Approve {
		state = "approved"
	}
	// A PR number is only unique per workspace: review it only if it belongs
	// to the active group (X-Group-Id), and with the caller's rights on the
	// PR's project (a read-only override cannot approve; a project role can).
	access, err := s.scopeGroup(r, ws, caller.UID)
	if err != nil {
		writeError(w, err)
		return
	}
	scope := scopeOf(access)
	var prID string
	var projectID, prGroup sql.NullString
	err = s.store.db.QueryRowContext(r.Context(), `
		select pull_requests.id, pull_requests.project_id, p.group_id
		from pull_requests left join projects p on p.id = pull_requests.project_id
		where pull_requests.workspace_id = ? and pull_requests.number = ?`+scope.tasks("pull_requests"),
		scope.withArgs(ws.ID, r.PathValue("number"))...).Scan(&prID, &projectID, &prGroup)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("pull_request_not_found", "طلب السحب غير موجود."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if projectID.Valid {
		if _, err := s.requireProjectCap(r.Context(), ws, caller.UID, prGroup.String,
			projectID.String, CapReviewPR); err != nil {
			writeError(w, err)
			return
		}
	} else if !access.IsDefault {
		if err := access.require(CapReviewPR); err != nil {
			writeError(w, err)
			return
		}
	}
	result, err := s.store.db.ExecContext(r.Context(),
		`update pull_requests set state = ?, reviewer_uid = ? where id = ?`,
		state, caller.UID, prID)
	if err != nil {
		writeError(w, err)
		return
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		writeError(w, notFound("pull_request_not_found", "طلب السحب غير موجود."))
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"state": state})
}

// POST /v1/time-entries/approve
func (s *Server) handleApproveTimeEntries(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
		writeError(w, err)
		return
	}

	var count int
	if err := s.store.db.QueryRowContext(r.Context(),
		`select count(*) from time_entries where workspace_id = ? and user_uid = ?`,
		ws.ID, caller.UID,
	).Scan(&count); err != nil {
		writeError(w, err)
		return
	}
	if err := s.store.logActivity(r.Context(), ws.ID, caller.UID, "time_approved",
		"تم اعتماد السجلات", nil); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]int{"approved": count})
}
