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
		       t.due_at, t.created_at
		from tasks t
		left join projects p on p.id = t.project_id
		where t.workspace_id = ?`
	args := []any{ws.ID}
	if access.IsDefault {
		query += ` and (t.project_id is null or t.project_id in (select id from projects where group_id = ?))`
	} else {
		query += ` and t.project_id in (select id from projects where group_id = ?)`
	}
	args = append(args, access.ID)
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
		label, branch, dueAt                   *string
		prNumber                               *int
	)
	if err := rows.Scan(&id, &title, &description, &status, &priority,
		&projectID, &projectName, &label, &branch, &prNumber, &dueAt,
		&createdAt); err != nil {
		return nil, err
	}
	return map[string]any{
		"id":           id,
		"title":        title,
		"description":  description,
		"status":       status,
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
		if err := s.requireGroupCapUnlessDefault(r.Context(), ws, caller.UID, groupID.String, CapEditTasks); err != nil {
			writeError(w, err)
			return
		}
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
		                   status, priority, points, created_at, updated_at)
		values (?, ?, ?, ?, ?, 'todo', ?, 0, ?, ?)`,
		taskID, ws.ID, body.ProjectID, body.Title, body.Description, priority, now, now,
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
		       t.due_at, t.created_at
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
	switch body.Status {
	case "todo", "in_progress", "review", "done":
	default:
		writeError(w, badRequest("invalid_status", "حالة المهمة غير معروفة."))
		return
	}

	taskID := r.PathValue("id")
	if err := s.requireTaskAccess(r, ws, caller.UID, taskID, CapEditTasks); err != nil {
		writeError(w, err)
		return
	}
	result, err := s.store.db.ExecContext(r.Context(),
		`update tasks set status = ?, updated_at = ? where id = ? and workspace_id = ?`,
		body.Status, nowString(), taskID, ws.ID)
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

	result, err := s.store.db.ExecContext(r.Context(),
		`update pull_requests set state = ?, reviewer_uid = ?
		  where workspace_id = ? and number = ?`,
		state, caller.UID, ws.ID, r.PathValue("number"))
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
