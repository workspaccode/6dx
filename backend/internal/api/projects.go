package api

import (
	"net/http"
	"strings"
)

type createProjectRequest struct {
	Name               string  `json:"name"`
	Description        *string `json:"description"`
	RepositoryFullName *string `json:"repository_full_name"`
}

// GET /v1/projects
func (s *Server) handleListProjects(w http.ResponseWriter, r *http.Request) {
	_, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}

	rows, err := s.store.db.QueryContext(r.Context(), `
		select p.id, p.name, p.description, p.icon, p.color, p.is_archived,
		       p.updated_at,
		       (select count(*) from tasks t where t.project_id = p.id and t.status <> 'done'),
		       (select count(*) from tasks t where t.project_id = p.id and t.status = 'done'),
		       (select r.full_name from repositories r where r.project_id = p.id order by r.id limit 1)
		from projects p
		where p.workspace_id = ?
		order by p.updated_at desc`, ws.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()

	projects := make([]map[string]any, 0)
	for rows.Next() {
		project, err := scanProject(rows)
		if err != nil {
			writeError(w, err)
			return
		}
		projects = append(projects, project)
	}
	writeJSON(w, http.StatusOK, map[string]any{"projects": projects})
}

func scanProject(rows interface {
	Scan(dest ...any) error
}) (map[string]any, error) {
	var (
		id, name, updatedAt string
		description, icon   *string
		color               *string
		isArchived          int
		openTasks, doneTasks int
		repositoryFullName  *string
	)
	if err := rows.Scan(&id, &name, &description, &icon, &color, &isArchived,
		&updatedAt, &openTasks, &doneTasks, &repositoryFullName); err != nil {
		return nil, err
	}
	return map[string]any{
		"id":                   id,
		"name":                 name,
		"description":          description,
		"icon":                 icon,
		"color":                color,
		"open_tasks":           openTasks,
		"done_tasks":           doneTasks,
		"repository_full_name": repositoryFullName,
		"is_archived":          isArchived != 0,
		"updated_at":           updatedAt,
	}, nil
}

// POST /v1/projects
func (s *Server) handleCreateProject(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
		writeError(w, err)
		return
	}

	var body createProjectRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if strings.TrimSpace(body.Name) == "" {
		writeError(w, badRequest("name_required", "اسم المشروع مطلوب."))
		return
	}

	projectID := newID()
	now := nowString()
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()

	if _, err := tx.ExecContext(r.Context(), `
		insert into projects (id, workspace_id, name, description, is_archived,
		                      created_by, created_at, updated_at)
		values (?, ?, ?, ?, 0, ?, ?, ?)`,
		projectID, ws.ID, body.Name, body.Description, caller.UID, now, now,
	); err != nil {
		writeError(w, err)
		return
	}

	var repositoryFullName *string
	if body.RepositoryFullName != nil && *body.RepositoryFullName != "" {
		if _, err := tx.ExecContext(r.Context(),
			`insert into repositories (id, project_id, full_name) values (?, ?, ?)`,
			newID(), projectID, *body.RepositoryFullName,
		); err != nil {
			writeError(w, err)
			return
		}
		repositoryFullName = body.RepositoryFullName
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}

	_ = s.store.logActivity(r.Context(), ws.ID, caller.UID, "project_created",
		"تم إنشاء مشروع "+body.Name, &projectID)

	writeJSON(w, http.StatusCreated, map[string]any{
		"project": map[string]any{
			"id":                   projectID,
			"name":                 body.Name,
			"description":          body.Description,
			"icon":                 nil,
			"color":                nil,
			"open_tasks":           0,
			"done_tasks":           0,
			"repository_full_name": repositoryFullName,
			"is_archived":          false,
			"updated_at":           now,
		},
	})
}

// POST /v1/projects/{id}/archive
func (s *Server) handleArchiveProject(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
		writeError(w, err)
		return
	}

	result, err := s.store.db.ExecContext(r.Context(),
		`update projects set is_archived = 1, updated_at = ?
		  where id = ? and workspace_id = ?`,
		nowString(), r.PathValue("id"), ws.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		writeError(w, notFound("project_not_found", "المشروع غير موجود."))
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
