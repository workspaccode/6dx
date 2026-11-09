package api

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/workspaccode/6dx/backend/internal/auth"
	"github.com/workspaccode/6dx/backend/internal/httpx"
)

// Workspace is the workspace the client is currently in.
type Workspace struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Role Role   `json:"role"`
}

// resolveWorkspace is the port of `ensure_my_workspace()`: return the caller's
// workspace, creating it together with the owner membership on first sign-in.
//
// [preferred] is the workspace the client asked for (`X-Workspace-Id`). A user
// can belong to several workspaces — their own plus the ones they were invited
// to — so the active one must be selectable; falling back to "the first
// membership" would silently put an invited viewer back into their own
// workspace, where they are the owner.
func (s *store) resolveWorkspace(ctx context.Context, caller *auth.Caller, preferred string) (*Workspace, error) {
	if preferred != "" {
		var ws Workspace
		err := s.pool.QueryRow(ctx, `
			select w.id::text, w.name, m.role::text
			from workspace_members m
			join workspaces w on w.id = m.workspace_id
			where m.workspace_id = $1::uuid and m.user_uid = $2`,
			preferred, caller.UID,
		).Scan(&ws.ID, &ws.Name, &ws.Role)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, httpx.Forbidden("not_workspace_member",
				"أنت لست عضواً في مساحة العمل هذه.")
		}
		if err != nil {
			return nil, err
		}
		return &ws, nil
	}

	var ws Workspace
	err := s.pool.QueryRow(ctx, `
		select w.id::text, w.name, m.role::text
		from workspace_members m
		join workspaces w on w.id = m.workspace_id
		where m.user_uid = $1
		order by m.created_at
		limit 1`, caller.UID,
	).Scan(&ws.ID, &ws.Name, &ws.Role)
	if err == nil {
		return &ws, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, err
	}

	// First sign-in: create the workspace + membership atomically.
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	slug, err := uniqueSlug(ctx, tx, caller.UID)
	if err != nil {
		return nil, err
	}

	const defaultName = "مساحة عملي"
	if err := tx.QueryRow(ctx,
		`insert into workspaces (name, slug, owner_uid) values ($1, $2, $3)
		 returning id::text, name`,
		defaultName, slug, caller.UID,
	).Scan(&ws.ID, &ws.Name); err != nil {
		return nil, err
	}
	if _, err := tx.Exec(ctx,
		`insert into workspace_members (workspace_id, user_uid, role)
		 values ($1, $2, 'owner')`, ws.ID, caller.UID,
	); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	ws.Role = RoleOwner
	return &ws, nil
}

func uniqueSlug(ctx context.Context, tx pgx.Tx, uid string) (string, error) {
	buf := make([]byte, 4)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	suffix := hex.EncodeToString(buf)
	trimmed := uid
	if len(trimmed) > 8 {
		trimmed = trimmed[:8]
	}
	slug := fmt.Sprintf("ws-%s-%s", trimmed, suffix)

	var exists bool
	if err := tx.QueryRow(ctx,
		`select exists (select 1 from workspaces where slug = $1)`, slug,
	).Scan(&exists); err != nil {
		return "", err
	}
	if exists {
		return fmt.Sprintf("ws-%s-%s-%d", trimmed, suffix, time.Now().UnixNano()), nil
	}
	return slug, nil
}

// handleMe returns the caller's workspace (bootstrap + role).
// GET /v1/me
func (s *Server) handleMe(w http.ResponseWriter, r *http.Request) {
	caller, err := auth.FromContext(r.Context())
	if err != nil {
		httpx.Write(w, httpx.Unauthorized("سجّل الدخول أولاً."))
		return
	}
	if err := s.store.upsertUser(r.Context(), caller); err != nil {
		httpx.Write(w, err)
		return
	}
	ws, err := s.store.resolveWorkspace(r.Context(), caller, r.Header.Get("X-Workspace-Id"))
	if err != nil {
		httpx.Write(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{
		"workspace": ws,
		"user": map[string]string{
			"uid":          caller.UID,
			"email":        caller.Email,
			"display_name": caller.DisplayName,
			"photo_url":    caller.PhotoURL,
		},
	})
}

// handleSnapshot returns the whole projection in one payload.
// GET /v1/workspace/snapshot
func (s *Server) handleSnapshot(w http.ResponseWriter, r *http.Request) {
	caller, err := auth.FromContext(r.Context())
	if err != nil {
		httpx.Write(w, httpx.Unauthorized("سجّل الدخول أولاً."))
		return
	}
	ws, err := s.store.resolveWorkspace(r.Context(), caller, r.Header.Get("X-Workspace-Id"))
	if err != nil {
		httpx.Write(w, err)
		return
	}

	var payload []byte
	err = s.store.pool.QueryRow(r.Context(),
		`select get_workspace_snapshot($1::uuid, $2)`, ws.ID, caller.UID,
	).Scan(&payload)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if payload == nil {
		httpx.Write(w, httpx.NotFound("workspace_not_found", "مساحة العمل غير موجودة."))
		return
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_, _ = w.Write(payload)
}

// --- projects ---------------------------------------------------------------

type createProjectRequest struct {
	Name               string  `json:"name"`
	Description        *string `json:"description"`
	RepositoryFullName *string `json:"repository_full_name"`
}

type Project struct {
	ID                 string  `json:"id"`
	Name               string  `json:"name"`
	Description        *string `json:"description"`
	Icon               *string `json:"icon"`
	Color              *string `json:"color"`
	OpenTasks          int     `json:"open_tasks"`
	DoneTasks          int     `json:"done_tasks"`
	RepositoryFullName *string `json:"repository_full_name"`
	IsArchived         bool    `json:"is_archived"`
	UpdatedAt          string  `json:"updated_at"`
}

// GET /v1/projects
func (s *Server) handleListProjects(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	_ = caller

	rows, err := s.store.pool.Query(r.Context(), `
		select p.id::text, p.name, p.description, p.icon, p.color, p.is_archived,
		       to_char(p.updated_at, 'YYYY-MM-DD"T"HH24:MI:SSOF'),
		       (select count(*) from tasks t where t.project_id = p.id and t.status <> 'done'),
		       (select count(*) from tasks t where t.project_id = p.id and t.status = 'done'),
		       (select r.full_name from repositories r where r.project_id = p.id order by r.id limit 1)
		from projects p
		where p.workspace_id = $1
		order by p.updated_at desc`, ws.ID)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	defer rows.Close()

	projects := make([]Project, 0)
	for rows.Next() {
		var p Project
		if err := rows.Scan(&p.ID, &p.Name, &p.Description, &p.Icon, &p.Color,
			&p.IsArchived, &p.UpdatedAt, &p.OpenTasks, &p.DoneTasks,
			&p.RepositoryFullName); err != nil {
			httpx.Write(w, err)
			return
		}
		projects = append(projects, p)
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"projects": projects})
}

// POST /v1/projects
func (s *Server) handleCreateProject(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
		httpx.Write(w, err)
		return
	}

	var body createProjectRequest
	if err := httpx.Decode(r, &body); err != nil {
		httpx.Write(w, err)
		return
	}
	if body.Name == "" {
		httpx.Write(w, httpx.BadRequest("name_required", "اسم المشروع مطلوب."))
		return
	}

	tx, err := s.store.pool.Begin(r.Context())
	if err != nil {
		httpx.Write(w, err)
		return
	}
	defer func() { _ = tx.Rollback(r.Context()) }()

	var project Project
	if err := tx.QueryRow(r.Context(), `
		insert into projects (workspace_id, name, description, created_by)
		values ($1, $2, $3, $4)
		returning id::text, name, description, icon, color, is_archived,
		          to_char(updated_at, 'YYYY-MM-DD"T"HH24:MI:SSOF')`,
		ws.ID, body.Name, body.Description, caller.UID,
	).Scan(&project.ID, &project.Name, &project.Description, &project.Icon,
		&project.Color, &project.IsArchived, &project.UpdatedAt); err != nil {
		httpx.Write(w, err)
		return
	}

	if body.RepositoryFullName != nil && *body.RepositoryFullName != "" {
		if _, err := tx.Exec(r.Context(),
			`insert into repositories (project_id, full_name) values ($1, $2)`,
			project.ID, *body.RepositoryFullName,
		); err != nil {
			httpx.Write(w, err)
			return
		}
		project.RepositoryFullName = body.RepositoryFullName
	}

	if err := tx.Commit(r.Context()); err != nil {
		httpx.Write(w, err)
		return
	}
	_ = s.store.logActivity(r.Context(), ws.ID, caller.UID, "project_created",
		"تم إنشاء مشروع "+project.Name, &project.ID)

	httpx.JSON(w, http.StatusCreated, map[string]any{"project": project})
}

// POST /v1/projects/{id}/archive
func (s *Server) handleArchiveProject(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if _, err := s.store.requireEditor(r.Context(), ws.ID, caller.UID); err != nil {
		httpx.Write(w, err)
		return
	}
	id := httpx.PathValue(r, "id")

	tag, err := s.store.pool.Exec(r.Context(),
		`update projects set is_archived = true
		  where id = $1 and workspace_id = $2`, id, ws.ID)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if tag.RowsAffected() == 0 {
		httpx.Write(w, httpx.NotFound("project_not_found", "المشروع غير موجود."))
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// --- helpers ----------------------------------------------------------------

// callerAndWorkspace resolves the authenticated caller and their workspace.
//
// The workspace is the one named by the `X-Workspace-Id` header, so a user who
// belongs to several workspaces acts on the one the app is showing. Without the
// header the first membership is used (and the first sign-in bootstraps one).
func (s *Server) callerAndWorkspace(r *http.Request) (*auth.Caller, *Workspace, error) {
	caller, err := auth.FromContext(r.Context())
	if err != nil {
		return nil, nil, httpx.Unauthorized("سجّل الدخول أولاً.")
	}
	ws, err := s.store.resolveWorkspace(r.Context(), caller, r.Header.Get("X-Workspace-Id"))
	if err != nil {
		return nil, nil, err
	}
	return caller, ws, nil
}

// decodeJSON is a helper for handlers that need the raw body as a map.
func decodeJSON(r *http.Request) (map[string]any, error) {
	var body map[string]any
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		return nil, httpx.BadRequest("invalid_body", "صيغة الطلب غير صحيحة.")
	}
	return body, nil
}

// contextWithTimeout is used by the GitHub broker calls.
func contextWithTimeout(parent context.Context, d time.Duration) (context.Context, context.CancelFunc) {
	return context.WithTimeout(parent, d)
}
