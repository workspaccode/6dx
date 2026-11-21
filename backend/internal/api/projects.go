package api

import (
	"fmt"
	"net/http"
	"strings"
)

type createProjectRequest struct {
	Name               string  `json:"name"`
	Description        *string `json:"description"`
	RepositoryFullName *string `json:"repository_full_name"`
	// GroupID places the project in a group (projects.manage there). Empty =
	// the workspace's default group, for the legacy screens.
	GroupID *string `json:"group_id"`
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
	var body createProjectRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}

	var groupID string
	if body.GroupID != nil && *body.GroupID != "" {
		access, err := s.store.loadGroupAccess(r.Context(), ws, caller.UID, *body.GroupID)
		if err != nil {
			writeError(w, err)
			return
		}
		if err := access.require(CapManageProjects); err != nil {
			writeError(w, err)
			return
		}
		groupID = access.ID
	} else {
		if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
			writeError(w, err)
			return
		}
		if groupID, err = s.store.defaultGroupID(r.Context(), ws.ID); err != nil {
			writeError(w, err)
			return
		}
	}
	body.Name = strings.TrimSpace(body.Name)
	if body.Name == "" {
		writeError(w, badRequest("name_required", "اسم المشروع مطلوب."))
		return
	}
	if tooLong(body.Name, maxProjectNameLength) {
		writeError(w, badRequest("name_too_long",
			fmt.Sprintf("اسم المشروع أطول من %d حرف.", maxProjectNameLength)))
		return
	}
	if optionalTooLong(body.Description, maxProjectDescLength) {
		writeError(w, badRequest("description_too_long",
			fmt.Sprintf("وصف المشروع أطول من %d حرف.", maxProjectDescLength)))
		return
	}
	if body.RepositoryFullName != nil {
		repo := strings.TrimSpace(*body.RepositoryFullName)
		if repo != "" && (len(repo) > maxRepoNameLength || !githubRepoPattern.MatchString(repo)) {
			writeError(w, badRequest("invalid_repository", "اسم المستودع لازم يكون owner/name."))
			return
		}
		body.RepositoryFullName = &repo
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
		insert into projects (id, workspace_id, group_id, name, description, is_archived,
		                      created_by, created_at, updated_at)
		values (?, ?, ?, ?, ?, 0, ?, ?, ?)`,
		projectID, ws.ID, groupID, body.Name, body.Description, caller.UID, now, now,
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
			"group_id":             groupID,
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
