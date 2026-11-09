package api

import (
	"errors"
	"net/http"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/workspaccode/6dx/backend/internal/auth"
	"github.com/workspaccode/6dx/backend/internal/httpx"
)

type createTaskRequest struct {
	Title       string  `json:"title"`
	Description *string `json:"description"`
	ProjectID   *string `json:"project_id"`
	Priority    *string `json:"priority"`
}

type taskDTO struct {
	ID          string  `json:"id"`
	Title       string  `json:"title"`
	Description *string `json:"description"`
	Status      string  `json:"status"`
	Priority    string  `json:"priority"`
	ProjectID   *string `json:"project_id"`
	ProjectName *string `json:"project_name"`
	Label       *string `json:"label"`
	Branch      *string `json:"branch"`
	PRNumber    *int    `json:"pr_number"`
	DueAt       *string `json:"due_at"`
	CreatedAt   string  `json:"created_at"`
}

const taskSelect = `
	select t.id::text, t.title, t.description, t.status::text, t.priority::text,
	       t.project_id::text, p.name, t.label, t.branch, t.pr_number,
	       to_char(t.due_at, 'YYYY-MM-DD"T"HH24:MI:SSOF'),
	       to_char(t.created_at, 'YYYY-MM-DD"T"HH24:MI:SSOF')
	from tasks t
	left join projects p on p.id = t.project_id`

// GET /v1/tasks?project_id=
func (s *Server) handleListTasks(w http.ResponseWriter, r *http.Request) {
	_, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}

	projectID := strings.TrimSpace(r.URL.Query().Get("project_id"))
	query := taskSelect + ` where t.workspace_id = $1`
	args := []any{ws.ID}
	if projectID != "" {
		query += ` and t.project_id = $2`
		args = append(args, projectID)
	}
	query += ` order by t.created_at desc`

	rows, err := s.store.pool.Query(r.Context(), query, args...)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	defer rows.Close()

	tasks := make([]taskDTO, 0)
	for rows.Next() {
		var t taskDTO
		if err := rows.Scan(&t.ID, &t.Title, &t.Description, &t.Status, &t.Priority,
			&t.ProjectID, &t.ProjectName, &t.Label, &t.Branch, &t.PRNumber,
			&t.DueAt, &t.CreatedAt); err != nil {
			httpx.Write(w, err)
			return
		}
		tasks = append(tasks, t)
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"tasks": tasks})
}

// POST /v1/tasks
func (s *Server) handleCreateTask(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
		httpx.Write(w, err)
		return
	}

	var body createTaskRequest
	if err := httpx.Decode(r, &body); err != nil {
		httpx.Write(w, err)
		return
	}
	if strings.TrimSpace(body.Title) == "" {
		httpx.Write(w, httpx.BadRequest("title_required", "عنوان المهمة مطلوب."))
		return
	}
	priority := "medium"
	if body.Priority != nil && *body.Priority != "" {
		priority = *body.Priority
	}

	var t taskDTO
	err = s.store.pool.QueryRow(r.Context(), `
		with inserted as (
			insert into tasks (workspace_id, project_id, title, description, priority)
			values ($1, $2, $3, $4, $5::task_priority)
			returning *
		)
		select i.id::text, i.title, i.description, i.status::text, i.priority::text,
		       i.project_id::text, p.name, i.label, i.branch, i.pr_number,
		       to_char(i.due_at, 'YYYY-MM-DD"T"HH24:MI:SSOF'),
		       to_char(i.created_at, 'YYYY-MM-DD"T"HH24:MI:SSOF')
		from inserted i
		left join projects p on p.id = i.project_id`,
		ws.ID, body.ProjectID, body.Title, body.Description, priority,
	).Scan(&t.ID, &t.Title, &t.Description, &t.Status, &t.Priority,
		&t.ProjectID, &t.ProjectName, &t.Label, &t.Branch, &t.PRNumber,
		&t.DueAt, &t.CreatedAt)
	if err != nil {
		httpx.Write(w, err)
		return
	}

	httpx.JSON(w, http.StatusCreated, map[string]any{"task": t})
}

type updateStatusRequest struct {
	Status string `json:"status"`
}

// PATCH /v1/tasks/{id}/status
func (s *Server) handleUpdateTaskStatus(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
		httpx.Write(w, err)
		return
	}

	var body updateStatusRequest
	if err := httpx.Decode(r, &body); err != nil {
		httpx.Write(w, err)
		return
	}
	switch body.Status {
	case "todo", "in_progress", "review", "done":
	default:
		httpx.Write(w, httpx.BadRequest("invalid_status", "حالة المهمة غير معروفة."))
		return
	}

	id := httpx.PathValue(r, "id")
	var t taskDTO
	err = s.store.pool.QueryRow(r.Context(), `
		with updated as (
			update tasks set status = $1::task_status
			 where id = $2 and workspace_id = $3
			returning *
		)
		select u.id::text, u.title, u.description, u.status::text, u.priority::text,
		       u.project_id::text, p.name, u.label, u.branch, u.pr_number,
		       to_char(u.due_at, 'YYYY-MM-DD"T"HH24:MI:SSOF'),
		       to_char(u.created_at, 'YYYY-MM-DD"T"HH24:MI:SSOF')
		from updated u
		left join projects p on p.id = u.project_id`,
		body.Status, id, ws.ID,
	).Scan(&t.ID, &t.Title, &t.Description, &t.Status, &t.Priority,
		&t.ProjectID, &t.ProjectName, &t.Label, &t.Branch, &t.PRNumber,
		&t.DueAt, &t.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		httpx.Write(w, httpx.NotFound("task_not_found", "المهمة غير موجودة."))
		return
	}
	if err != nil {
		httpx.Write(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"task": t})
}

// DELETE /v1/tasks/{id}
func (s *Server) handleDeleteTask(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
		httpx.Write(w, err)
		return
	}
	tag, err := s.store.pool.Exec(r.Context(),
		`delete from tasks where id = $1 and workspace_id = $2`,
		httpx.PathValue(r, "id"), ws.ID)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if tag.RowsAffected() == 0 {
		httpx.Write(w, httpx.NotFound("task_not_found", "المهمة غير موجودة."))
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// POST /v1/pull-requests/{number}/review
func (s *Server) handleReviewPullRequest(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
		httpx.Write(w, err)
		return
	}

	var body struct {
		Approve bool `json:"approve"`
	}
	if err := httpx.Decode(r, &body); err != nil {
		httpx.Write(w, err)
		return
	}
	state := "changes_requested"
	if body.Approve {
		state = "approved"
	}

	tag, err := s.store.pool.Exec(r.Context(),
		`update pull_requests set state = $1, reviewer_uid = $2
		  where workspace_id = $3 and number = $4`,
		state, caller.UID, ws.ID, httpx.PathValue(r, "number"))
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if tag.RowsAffected() == 0 {
		httpx.Write(w, httpx.NotFound("pull_request_not_found", "طلب السحب غير موجود."))
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"state": state})
}

// POST /v1/time-entries/approve
func (s *Server) handleApproveTimeEntries(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
		httpx.Write(w, err)
		return
	}

	var count int
	if err := s.store.pool.QueryRow(r.Context(),
		`select count(*) from time_entries where workspace_id = $1 and user_uid = $2`,
		ws.ID, caller.UID,
	).Scan(&count); err != nil {
		httpx.Write(w, err)
		return
	}
	if err := s.store.logActivity(r.Context(), ws.ID, caller.UID, "time_approved",
		"تم اعتماد السجلات", nil); err != nil {
		httpx.Write(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]int{"approved": count})
}

var _ = auth.FromContext
