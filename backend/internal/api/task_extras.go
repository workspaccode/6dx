package api

import (
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"strings"
)

// Comments and subtasks of a task. The snapshot already returns both; these
// are their writes. Access follows the task: its group's rules (private
// projects, read-only overrides), and in the default group the legacy
// workspace roles.

const (
	maxCommentLength = 5000
	maxSubtaskTitle  = 200
	maxSubtasks      = 100
)

// POST /v1/tasks/{id}/comments {body} — any member who can see the task and
// comment; the client (viewer / guest) reads only.
func (s *Server) handleAddComment(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	var body struct {
		Body string `json:"body"`
	}
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	text := strings.TrimSpace(body.Body)
	if text == "" || tooLong(text, maxCommentLength) {
		writeError(w, badRequest("invalid_comment", fmt.Sprintf("التعليق لازم يكون من 1 لـ %d حرف.", maxCommentLength)))
		return
	}
	// A workspace viewer is the client: read-only, as in a group (§4.5).
	if !ws.Role.IsEditor() {
		writeError(w, forbidden("viewer_read_only", "العميل بيتابع بس."))
		return
	}
	taskID := r.PathValue("id")
	if err := s.requireTaskAccess(r, ws, caller.UID, taskID, CapComment); err != nil {
		writeError(w, err)
		return
	}
	id := newID()
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into task_comments (id, task_id, author_uid, body, created_at) values (?, ?, ?, ?, ?)`,
		id, taskID, caller.UID, text, nowString()); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"comment": map[string]any{"id": id}})
}

// POST /v1/tasks/{id}/subtasks {title}
func (s *Server) handleAddSubtask(w http.ResponseWriter, r *http.Request) {
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
		Title string `json:"title"`
	}
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	title := strings.TrimSpace(body.Title)
	if title == "" || tooLong(title, maxSubtaskTitle) {
		writeError(w, badRequest("invalid_subtask", fmt.Sprintf("المهمة الفرعية لازم تكون من 1 لـ %d حرف.", maxSubtaskTitle)))
		return
	}
	taskID := r.PathValue("id")
	if err := s.requireTaskAccess(r, ws, caller.UID, taskID, CapEditTasks); err != nil {
		writeError(w, err)
		return
	}
	var count int
	if err := s.store.db.QueryRowContext(r.Context(),
		`select count(*) from task_subtasks where task_id = ?`, taskID).Scan(&count); err != nil {
		writeError(w, err)
		return
	}
	if count >= maxSubtasks {
		writeError(w, conflict("subtask_limit", fmt.Sprintf("الحد الأقصى %d مهمة فرعية.", maxSubtasks)))
		return
	}
	id := newID()
	if _, err := s.store.db.ExecContext(r.Context(),
		`insert into task_subtasks (id, task_id, title) values (?, ?, ?)`, id, taskID, title); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"subtask": map[string]any{"id": id}})
}

// PATCH /v1/subtasks/{sid} {done} — tick / untick.
func (s *Server) handleToggleSubtask(w http.ResponseWriter, r *http.Request) {
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
		Done bool `json:"done"`
	}
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	var taskID string
	err = s.store.db.QueryRowContext(r.Context(), `
		select st.task_id from task_subtasks st join tasks t on t.id = st.task_id
		where st.id = ? and t.workspace_id = ?`, r.PathValue("sid"), ws.ID).Scan(&taskID)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("subtask_not_found", "المهمة الفرعية مش موجودة."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if err := s.requireTaskAccess(r, ws, caller.UID, taskID, CapEditTasks); err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(),
		`update task_subtasks set is_done = ? where id = ?`, boolInt(body.Done), r.PathValue("sid")); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
