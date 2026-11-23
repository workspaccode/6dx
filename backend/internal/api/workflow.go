package api

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"strings"
)

// Editable workflow states — docs/design/groups-and-roles.md §3.
//
// A group owns its task states. Each state has a category (what reports and
// the role home count: backlog / active / blocked / done / cancelled) and the
// legacy status the classic board shows it as. Migration 0004 seeds the
// default four and keeps tasks.status and tasks.state_id in step.

const (
	maxStateNameLength = 40
	maxStatesPerEntity = 20
	defaultStateColor  = "#64748B"
)

var stateColorPattern = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)

var stateCategories = map[string]bool{
	"backlog": true, "active": true, "blocked": true, "done": true, "cancelled": true,
}

// legacyStatusFor is how a custom state shows on the classic board.
func legacyStatusFor(category string) string {
	switch category {
	case "backlog":
		return "todo"
	case "done", "cancelled":
		return "done"
	default:
		return "in_progress"
	}
}

type workflowState struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	Category     string `json:"category"`
	Color        string `json:"color"`
	LegacyStatus string `json:"legacy_status"`
	Order        int    `json:"order"`
	IsLocked     bool   `json:"is_locked"`
	Archived     bool   `json:"archived"`
	TaskCount    int    `json:"task_count"`
}

func (s *store) workflowStates(ctx context.Context, q queryer, groupID string) ([]workflowState, error) {
	rows, err := q.QueryContext(ctx, `
		select s.id, s.name, s.category, s.color, s.legacy_status, s.ord, s.is_locked,
		       s.archived, (select count(*) from tasks t where t.state_id = s.id)
		from workflow_states s
		where s.group_id = ? and s.entity = 'task'
		order by s.archived, s.ord, s.created_at`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	states := make([]workflowState, 0)
	for rows.Next() {
		var st workflowState
		var locked, archived int
		if err := rows.Scan(&st.ID, &st.Name, &st.Category, &st.Color, &st.LegacyStatus,
			&st.Order, &locked, &archived, &st.TaskCount); err != nil {
			return nil, err
		}
		st.IsLocked, st.Archived = locked == 1, archived == 1
		states = append(states, st)
	}
	return states, rows.Err()
}

// queryer is what both *sql.DB and *sql.Tx offer.
type queryer interface {
	QueryContext(context.Context, string, ...any) (*sql.Rows, error)
	QueryRowContext(context.Context, string, ...any) *sql.Row
	ExecContext(context.Context, string, ...any) (sql.Result, error)
}

// GET /v1/groups/{gid}/workflow — every member reads the states (the board
// needs them); archived ones are listed last so old tasks still show a name.
func (s *Server) handleListWorkflow(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.groupFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	states, err := s.store.workflowStates(r.Context(), s.store.db, access.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"states":     states,
		"can_manage": access.can(CapManageWorkflow),
	})
}

type stateRequest struct {
	Name     *string `json:"name"`
	Category *string `json:"category"`
	Color    *string `json:"color"`
	Archived *bool   `json:"archived"`
}

func (b *stateRequest) validate() error {
	if b.Name != nil {
		name := strings.TrimSpace(*b.Name)
		if name == "" || tooLong(name, maxStateNameLength) {
			return badRequest("invalid_state_name",
				fmt.Sprintf("اسم الحالة لازم يكون من 1 لـ %d حرف.", maxStateNameLength))
		}
		b.Name = &name
	}
	if b.Category != nil && !stateCategories[*b.Category] {
		return badRequest("invalid_category", "فئة الحالة غير معروفة.")
	}
	if b.Color != nil && !stateColorPattern.MatchString(*b.Color) {
		return badRequest("invalid_color", "اللون لازم يكون بالشكل #RRGGBB.")
	}
	return nil
}

// POST /v1/groups/{gid}/workflow — add a state at the end.
func (s *Server) handleCreateWorkflowState(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.groupFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapManageWorkflow); err != nil {
		writeError(w, err)
		return
	}
	var body stateRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if err := body.validate(); err != nil {
		writeError(w, err)
		return
	}
	if body.Name == nil || body.Category == nil {
		writeError(w, badRequest("state_fields_required", "اسم الحالة وفئتها مطلوبين."))
		return
	}
	color := defaultStateColor
	if body.Color != nil {
		color = strings.ToUpper(*body.Color)
	}

	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()

	var live, nextOrd int
	var duplicate int
	if err := tx.QueryRowContext(r.Context(), `
		select count(*), coalesce(max(ord), -1) + 1,
		       coalesce(sum(lower(name) = lower(?)), 0)
		from workflow_states where group_id = ? and entity = 'task' and archived = 0`,
		*body.Name, access.ID).Scan(&live, &nextOrd, &duplicate); err != nil {
		writeError(w, err)
		return
	}
	if live >= maxStatesPerEntity {
		writeError(w, conflict("state_limit_reached",
			fmt.Sprintf("الحد الأقصى %d حالة في المجموعة.", maxStatesPerEntity)))
		return
	}
	if duplicate > 0 {
		writeError(w, conflict("state_name_taken", "في حالة بنفس الاسم."))
		return
	}
	id := newID()
	if _, err := tx.ExecContext(r.Context(), `
		insert into workflow_states (id, group_id, entity, name, category, color,
		                             legacy_status, ord, created_at)
		values (?, ?, 'task', ?, ?, ?, ?, ?, ?)`,
		id, access.ID, *body.Name, *body.Category, color, legacyStatusFor(*body.Category),
		nextOrd, nowString()); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.writeWorkflow(w, r, access, http.StatusCreated)
}

func (s *Server) writeWorkflow(w http.ResponseWriter, r *http.Request, access *groupAccess, status int) {
	states, err := s.store.workflowStates(r.Context(), s.store.db, access.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, status, map[string]any{
		"states":     states,
		"can_manage": access.can(CapManageWorkflow),
	})
}

// PATCH /v1/groups/{gid}/workflow/{sid} — rename, recolour, recategorise,
// archive / restore.
//
// The group must always keep a live backlog state (new tasks land there)
// and a live done state; a state that still holds tasks cannot be archived
// (move them first, the screen says how many).
func (s *Server) handleUpdateWorkflowState(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.groupFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapManageWorkflow); err != nil {
		writeError(w, err)
		return
	}
	var body stateRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if err := body.validate(); err != nil {
		writeError(w, err)
		return
	}

	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()

	var current workflowState
	var locked, archived int
	err = tx.QueryRowContext(r.Context(), `
		select id, name, category, legacy_status, is_locked, archived,
		       (select count(*) from tasks t where t.state_id = workflow_states.id)
		from workflow_states where id = ? and group_id = ? and entity = 'task'`,
		r.PathValue("sid"), access.ID,
	).Scan(&current.ID, &current.Name, &current.Category, &current.LegacyStatus,
		&locked, &archived, &current.TaskCount)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("state_not_found", "الحالة مش موجودة في المجموعة."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if locked == 1 && (body.Category != nil || body.Archived != nil) {
		writeError(w, conflict("state_locked", "الحالة دي أساسية ومينفعش تتغير فئتها أو تتأرشف."))
		return
	}

	nextCategory := current.Category
	if body.Category != nil {
		nextCategory = *body.Category
	}
	nextArchived := archived == 1
	if body.Archived != nil {
		nextArchived = *body.Archived
	}
	if nextArchived && archived == 0 && current.TaskCount > 0 {
		writeError(w, conflict("state_in_use", fmt.Sprintf(
			"الحالة فيها %d مهمة. انقلهم لحالة تانية الأول.", current.TaskCount)))
		return
	}
	nextName := current.Name
	if body.Name != nil {
		nextName = *body.Name
	}
	if !nextArchived && (body.Name != nil || archived == 1) {
		// Renaming, or restoring next to a state that took the name since.
		var duplicate int
		if err := tx.QueryRowContext(r.Context(), `
			select count(*) from workflow_states
			where group_id = ? and entity = 'task' and archived = 0 and id <> ? and lower(name) = lower(?)`,
			access.ID, current.ID, nextName).Scan(&duplicate); err != nil {
			writeError(w, err)
			return
		}
		if duplicate > 0 {
			writeError(w, conflict("state_name_taken", "في حالة بنفس الاسم."))
			return
		}
	}
	if !nextArchived && archived == 1 {
		var live int
		if err := tx.QueryRowContext(r.Context(),
			`select count(*) from workflow_states where group_id = ? and entity = 'task' and archived = 0`,
			access.ID).Scan(&live); err != nil {
			writeError(w, err)
			return
		}
		if live >= maxStatesPerEntity {
			writeError(w, conflict("state_limit_reached",
				fmt.Sprintf("الحد الأقصى %d حالة في المجموعة.", maxStatesPerEntity)))
			return
		}
	}

	// The default «مراجعة» keeps showing as review on the old board; any
	// real category change takes the category's legacy status.
	nextLegacy := current.LegacyStatus
	if nextCategory != current.Category {
		nextLegacy = legacyStatusFor(nextCategory)
	}
	var color any
	if body.Color != nil {
		color = strings.ToUpper(*body.Color)
	}
	if _, err := tx.ExecContext(r.Context(), `
		update workflow_states set
		  name = coalesce(?, name), color = coalesce(?, color),
		  category = ?, legacy_status = ?, archived = ?
		where id = ?`,
		body.Name, color, nextCategory, nextLegacy, boolInt(nextArchived), current.ID); err != nil {
		writeError(w, err)
		return
	}
	if nextLegacy != current.LegacyStatus {
		// The tasks in this state now show under its new legacy status. The
		// state's legacy status already matches, so the trigger keeps them.
		if _, err := tx.ExecContext(r.Context(),
			`update tasks set status = ?, updated_at = ? where state_id = ?`,
			nextLegacy, nowString(), current.ID); err != nil {
			writeError(w, err)
			return
		}
	}
	if err := requireCoreStates(r.Context(), tx, access.ID); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.writeWorkflow(w, r, access, http.StatusOK)
}

// requireCoreStates: a group always has a live backlog state and a live done
// state, or creating and finishing tasks would have nowhere to go.
//
// (Until v15.0 every legacy board column also had to keep a state; the
// board now shows the group's states by state_id, and a status-only write
// from old code lands in the first state of the matching category.)
func requireCoreStates(ctx context.Context, q queryer, groupID string) error {
	var backlog, done int
	if err := q.QueryRowContext(ctx, `
		select coalesce(sum(category = 'backlog'), 0), coalesce(sum(category = 'done'), 0)
		from workflow_states where group_id = ? and entity = 'task' and archived = 0`,
		groupID).Scan(&backlog, &done); err != nil {
		return err
	}
	if backlog == 0 || done == 0 {
		return conflict("core_state_required",
			"لازم يفضل في المجموعة حالة واحدة على الأقل من فئة «قائمة الانتظار» وواحدة من فئة «تم».")
	}
	return nil
}

type reorderStatesRequest struct {
	IDs []string `json:"ids"`
}

// PUT /v1/groups/{gid}/workflow/order — the full list of live state ids in
// their new order.
func (s *Server) handleReorderWorkflow(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.groupFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapManageWorkflow); err != nil {
		writeError(w, err)
		return
	}
	var body reorderStatesRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if len(body.IDs) == 0 || len(body.IDs) > maxStatesPerEntity {
		writeError(w, badRequest("invalid_order", "ترتيب الحالات غير صحيح."))
		return
	}

	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()

	var live int
	if err := tx.QueryRowContext(r.Context(),
		`select count(*) from workflow_states where group_id = ? and entity = 'task' and archived = 0`,
		access.ID).Scan(&live); err != nil {
		writeError(w, err)
		return
	}
	seen := map[string]bool{}
	for _, id := range body.IDs {
		if seen[id] {
			writeError(w, badRequest("invalid_order", "ترتيب الحالات فيه تكرار."))
			return
		}
		seen[id] = true
	}
	if len(body.IDs) != live {
		writeError(w, badRequest("invalid_order", "لازم الترتيب يشمل كل الحالات الحالية."))
		return
	}
	for i, id := range body.IDs {
		result, err := tx.ExecContext(r.Context(), `
			update workflow_states set ord = ?
			where id = ? and group_id = ? and entity = 'task' and archived = 0`,
			i, id, access.ID)
		if err != nil {
			writeError(w, err)
			return
		}
		if n, _ := result.RowsAffected(); n == 0 {
			writeError(w, badRequest("invalid_order", "حالة مش موجودة في المجموعة."))
			return
		}
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.writeWorkflow(w, r, access, http.StatusOK)
}

// stateForTask checks that stateID is a live task state of groupID and
// returns its legacy status.
func (s *store) stateForTask(ctx context.Context, groupID, stateID string) (string, error) {
	var legacy string
	err := s.db.QueryRowContext(ctx, `
		select legacy_status from workflow_states
		where id = ? and group_id = ? and entity = 'task' and archived = 0`,
		stateID, groupID).Scan(&legacy)
	if errors.Is(err, sql.ErrNoRows) {
		return "", badRequest("invalid_state", "الحالة دي مش من حالات المجموعة.")
	}
	return legacy, err
}
