package api

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
)

// Hardware MVP — docs/design/groups-and-roles.md §7, migration 0005.
//
// Everything lives under /v1/groups/{gid}/projects/{pid}/hw/... and goes
// through hwFromRequest: the group must be a hardware group, and the project
// access (private projects, read-only overrides) decides the capabilities.
// Every sub-resource is looked up together with its project id, so an id
// from another project — or another workspace — is "not found".

// hwContext is one hardware request: the caller and their access narrowed
// to the project.
type hwContext struct {
	caller  *authCaller
	ws      *Workspace
	access  *groupAccess
	project string
}

func (h *hwContext) require(c Capability) error { return h.access.require(c) }

func (h *hwContext) requireAny(cs ...Capability) error {
	for _, c := range cs {
		if h.access.can(c) {
			return nil
		}
	}
	return forbidden("missing_capability", "دورك في المشروع ده مايسمحش بالعملية دي.")
}

func (s *Server) hwFromRequest(r *http.Request) (*hwContext, error) {
	caller, ws, group, project, err := s.projectFromRequest(r)
	if err != nil {
		return nil, err
	}
	if group.Type != GroupHardware {
		return nil, conflict("group_type_mismatch", "الشاشة دي لمجموعات الـ Hardware بس.")
	}
	return &hwContext{caller: caller, ws: ws, access: project, project: project.ProjectID}, nil
}

// hwHandler wraps the prologue so each handler starts with a checked context.
//
// A guest (the client) sees the project's progress only — phases and the
// overview counters, with no names — never the BOM, prices, changes, units
// or test notes (§5.4).
func (s *Server) hwHandler(fn func(w http.ResponseWriter, r *http.Request, h *hwContext)) http.HandlerFunc {
	return s.hwRoute(false, fn)
}

// hwProgressHandler is the guest-readable part: phases and the overview.
func (s *Server) hwProgressHandler(fn func(w http.ResponseWriter, r *http.Request, h *hwContext)) http.HandlerFunc {
	return s.hwRoute(true, fn)
}

func (s *Server) hwRoute(guestOK bool, fn func(w http.ResponseWriter, r *http.Request, h *hwContext)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		h, err := s.hwFromRequest(r)
		if err != nil {
			writeError(w, err)
			return
		}
		if h.guest() && !guestOK {
			writeError(w, forbidden("guest_progress_only", "العميل بيشوف تقدم المشروع بس."))
			return
		}
		fn(w, r, h)
	}
}

func (h *hwContext) guest() bool { return h.access.IsMember && h.access.GroupRole == GroupGuest }

// hwOwned checks that id is a row of table in the project. The table names
// are constants of this file, never request input.
func (s *store) hwOwned(ctx context.Context, q queryer, table, id, projectID, missing string) error {
	var one int
	err := q.QueryRowContext(ctx,
		`select 1 from `+table+` where id = ? and project_id = ?`, id, projectID).Scan(&one)
	if errors.Is(err, sql.ErrNoRows) {
		return notFound(missing, "العنصر مش موجود في المشروع ده.")
	}
	return err
}

// --- small validation helpers -------------------------------------------------

func trimmed(v *string) *string {
	if v == nil {
		return nil
	}
	t := strings.TrimSpace(*v)
	return &t
}

func requiredText(v *string, max int, code, label string) (string, error) {
	t := trimmed(v)
	if t == nil || *t == "" || tooLong(*t, max) {
		return "", badRequest(code, fmt.Sprintf("%s لازم يكون من 1 لـ %d حرف.", label, max))
	}
	return *t, nil
}

func optionalText(v *string, max int, code, label string) (*string, error) {
	t := trimmed(v)
	if t == nil {
		return nil, nil
	}
	if *t == "" {
		return nil, nil
	}
	if tooLong(*t, max) {
		return nil, badRequest(code, fmt.Sprintf("%s أطول من %d حرف.", label, max))
	}
	return t, nil
}

// cleared: the client sent "" for a field, meaning "remove the value".
func cleared(v *string) bool { return v != nil && strings.TrimSpace(*v) == "" }

func oneOf(v string, allowed ...string) bool {
	for _, a := range allowed {
		if v == a {
			return true
		}
	}
	return false
}

// --- phase templates (group level) -------------------------------------------

type phaseTemplate struct {
	ID        string   `json:"id"`
	Name      string   `json:"name"`
	Order     int      `json:"order"`
	Checklist []string `json:"checklist"`
	Archived  bool     `json:"archived"`
}

const (
	maxPhaseNameLength    = 40
	maxPhasesPerGroup     = 15
	maxChecklistItems     = 30
	maxChecklistItemChars = 200
)

func (s *store) phaseTemplates(ctx context.Context, groupID string) ([]phaseTemplate, error) {
	rows, err := s.db.QueryContext(ctx, `
		select id, name, ord, checklist, archived from phase_templates
		where group_id = ? order by archived, ord, created_at`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]phaseTemplate, 0)
	for rows.Next() {
		var t phaseTemplate
		var raw string
		var archived int
		if err := rows.Scan(&t.ID, &t.Name, &t.Order, &raw, &archived); err != nil {
			return nil, err
		}
		t.Archived = archived == 1
		t.Checklist = []string{}
		_ = json.Unmarshal([]byte(raw), &t.Checklist)
		out = append(out, t)
	}
	return out, rows.Err()
}

func cleanChecklist(items []string) ([]string, error) {
	if len(items) > maxChecklistItems {
		return nil, badRequest("checklist_too_long", fmt.Sprintf("الحد الأقصى %d بند.", maxChecklistItems))
	}
	out := make([]string, 0, len(items))
	for _, item := range items {
		item = strings.TrimSpace(item)
		if item == "" {
			continue
		}
		if tooLong(item, maxChecklistItemChars) {
			return nil, badRequest("checklist_item_too_long",
				fmt.Sprintf("البند أطول من %d حرف.", maxChecklistItemChars))
		}
		out = append(out, item)
	}
	return out, nil
}

// copyChecklist is a project's own copy: every item starts not done.
func copyChecklist(items []string) string {
	type item struct {
		Text string `json:"text"`
		Done bool   `json:"done"`
	}
	out := make([]item, 0, len(items))
	for _, t := range items {
		out = append(out, item{Text: t})
	}
	raw, _ := json.Marshal(out)
	return string(raw)
}

func (s *Server) hwGroup(r *http.Request) (*groupAccess, error) {
	_, _, access, err := s.groupFromRequest(r)
	if err != nil {
		return nil, err
	}
	if access.Type != GroupHardware {
		return nil, conflict("group_type_mismatch", "قوالب المراحل لمجموعات الـ Hardware بس.")
	}
	return access, nil
}

func (s *Server) writePhaseTemplates(w http.ResponseWriter, r *http.Request, access *groupAccess, status int) {
	templates, err := s.store.phaseTemplates(r.Context(), access.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, status, map[string]any{
		"phases":     templates,
		"can_manage": access.can(CapManageWorkflow),
	})
}

// GET /v1/groups/{gid}/phases
func (s *Server) handleListPhaseTemplates(w http.ResponseWriter, r *http.Request) {
	access, err := s.hwGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	s.writePhaseTemplates(w, r, access, http.StatusOK)
}

type phaseTemplateRequest struct {
	Name      *string   `json:"name"`
	Checklist *[]string `json:"checklist"`
	Archived  *bool     `json:"archived"`
}

// POST /v1/groups/{gid}/phases — a new phase at the end of the template. It
// is added (not started) to every project of the group that has not been
// killed or finished: the design doc's "suggest it to projects past that
// point" becomes "it lands last", which is where an added phase goes.
func (s *Server) handleCreatePhaseTemplate(w http.ResponseWriter, r *http.Request) {
	access, err := s.hwGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapManageWorkflow); err != nil {
		writeError(w, err)
		return
	}
	var body phaseTemplateRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	name, err := requiredText(body.Name, maxPhaseNameLength, "invalid_phase_name", "اسم المرحلة")
	if err != nil {
		writeError(w, err)
		return
	}
	checklist := []string{}
	if body.Checklist != nil {
		if checklist, err = cleanChecklist(*body.Checklist); err != nil {
			writeError(w, err)
			return
		}
	}
	rawChecklist, _ := json.Marshal(checklist)

	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	var live, nextOrd, duplicate int
	if err := tx.QueryRowContext(r.Context(), `
		select count(*), coalesce(max(ord), -1) + 1, coalesce(sum(lower(name) = lower(?)), 0)
		from phase_templates where group_id = ? and archived = 0`, name, access.ID,
	).Scan(&live, &nextOrd, &duplicate); err != nil {
		writeError(w, err)
		return
	}
	if live >= maxPhasesPerGroup {
		writeError(w, conflict("phase_limit_reached", fmt.Sprintf("الحد الأقصى %d مرحلة.", maxPhasesPerGroup)))
		return
	}
	if duplicate > 0 {
		writeError(w, conflict("phase_name_taken", "في مرحلة بنفس الاسم."))
		return
	}
	id, now := newID(), nowString()
	if _, err := tx.ExecContext(r.Context(), `
		insert into phase_templates (id, group_id, name, ord, checklist, created_at)
		values (?, ?, ?, ?, ?, ?)`, id, access.ID, name, nextOrd, string(rawChecklist), now); err != nil {
		writeError(w, err)
		return
	}
	if _, err := tx.ExecContext(r.Context(), `
		insert into hw_phases (id, project_id, template_id, name, ord, status, checklist, created_at)
		select p.id || ':' || ?, p.id, ?, ?,
		       coalesce((select max(x.ord) from hw_phases x where x.project_id = p.id), -1) + 1,
		       'not_started', ?, ?
		from projects p
		where p.group_id = ?
		  and not exists (select 1 from hw_phases k where k.project_id = p.id and k.status = 'killed')`,
		id, id, name, copyChecklist(checklist), now, access.ID); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.writePhaseTemplates(w, r, access, http.StatusCreated)
}

// PATCH /v1/groups/{gid}/phases/{tid} — rename, edit the checklist, archive.
//
// Changes reach the projects' phases that have not started; a phase that
// started or had a gate is history and stays as it was. Archiving removes
// the not-started copies that nothing points at yet.
func (s *Server) handleUpdatePhaseTemplate(w http.ResponseWriter, r *http.Request) {
	access, err := s.hwGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapManageWorkflow); err != nil {
		writeError(w, err)
		return
	}
	var body phaseTemplateRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	var name *string
	if body.Name != nil {
		n, err := requiredText(body.Name, maxPhaseNameLength, "invalid_phase_name", "اسم المرحلة")
		if err != nil {
			writeError(w, err)
			return
		}
		name = &n
	}
	var checklist *string
	var checklistCopy *string
	if body.Checklist != nil {
		items, err := cleanChecklist(*body.Checklist)
		if err != nil {
			writeError(w, err)
			return
		}
		raw, _ := json.Marshal(items)
		c, cp := string(raw), copyChecklist(items)
		checklist, checklistCopy = &c, &cp
	}
	tid := r.PathValue("tid")

	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	var currentName string
	var archived int
	err = tx.QueryRowContext(r.Context(),
		`select name, archived from phase_templates where id = ? and group_id = ?`, tid, access.ID,
	).Scan(&currentName, &archived)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("phase_not_found", "المرحلة مش موجودة في القالب."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	nextArchived := archived == 1
	if body.Archived != nil {
		nextArchived = *body.Archived
	}
	if !nextArchived {
		checkName := currentName
		if name != nil {
			checkName = *name
		}
		var duplicate int
		if err := tx.QueryRowContext(r.Context(), `
			select count(*) from phase_templates
			where group_id = ? and archived = 0 and id <> ? and lower(name) = lower(?)`,
			access.ID, tid, checkName).Scan(&duplicate); err != nil {
			writeError(w, err)
			return
		}
		if duplicate > 0 {
			writeError(w, conflict("phase_name_taken", "في مرحلة بنفس الاسم."))
			return
		}
	}
	if nextArchived && archived == 0 {
		var live int
		if err := tx.QueryRowContext(r.Context(),
			`select count(*) from phase_templates where group_id = ? and archived = 0`, access.ID,
		).Scan(&live); err != nil {
			writeError(w, err)
			return
		}
		if live <= 1 {
			writeError(w, conflict("last_phase", "لازم يفضل في القالب مرحلة واحدة على الأقل."))
			return
		}
	}
	if _, err := tx.ExecContext(r.Context(), `
		update phase_templates set name = coalesce(?, name), checklist = coalesce(?, checklist),
		       archived = ? where id = ?`, name, checklist, boolInt(nextArchived), tid); err != nil {
		writeError(w, err)
		return
	}
	if _, err := tx.ExecContext(r.Context(), `
		update hw_phases set name = coalesce(?, name), checklist = coalesce(?, checklist)
		where template_id = ? and status = 'not_started'`, name, checklistCopy, tid); err != nil {
		writeError(w, err)
		return
	}
	if !nextArchived && archived == 1 {
		var live int
		if err := tx.QueryRowContext(r.Context(),
			`select count(*) from phase_templates where group_id = ? and archived = 0`, access.ID,
		).Scan(&live); err != nil {
			writeError(w, err)
			return
		}
		if live >= maxPhasesPerGroup {
			writeError(w, conflict("phase_limit_reached", fmt.Sprintf("الحد الأقصى %d مرحلة.", maxPhasesPerGroup)))
			return
		}
		// Restored: projects that lost their not-started copy get it back,
		// last (where an added phase goes).
		var tName, tChecklist string
		if err := tx.QueryRowContext(r.Context(),
			`select name, checklist from phase_templates where id = ?`, tid).Scan(&tName, &tChecklist); err != nil {
			writeError(w, err)
			return
		}
		items := []string{}
		_ = json.Unmarshal([]byte(tChecklist), &items)
		if _, err := tx.ExecContext(r.Context(), `
			insert into hw_phases (id, project_id, template_id, name, ord, status, checklist, created_at)
			select p.id || ':' || ? || ':' || ?, p.id, ?, ?,
			       coalesce((select max(x.ord) from hw_phases x where x.project_id = p.id), -1) + 1,
			       'not_started', ?, ?
			from projects p
			where p.group_id = ?
			  and not exists (select 1 from hw_phases k where k.project_id = p.id and k.template_id = ?)
			  and not exists (select 1 from hw_phases k where k.project_id = p.id and k.status = 'killed')`,
			tid, newID(), tid, tName, copyChecklist(items), nowString(), access.ID, tid); err != nil {
			writeError(w, err)
			return
		}
	}
	if nextArchived {
		if _, err := tx.ExecContext(r.Context(), `
			delete from hw_phases
			where template_id = ? and status = 'not_started'
			  and not exists (select 1 from hw_gate_decisions d where d.phase_id = hw_phases.id)
			  and not exists (select 1 from hw_builds b where b.phase_id = hw_phases.id)
			  and not exists (select 1 from hw_test_plans t where t.phase_id = hw_phases.id)`, tid); err != nil {
			writeError(w, err)
			return
		}
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.writePhaseTemplates(w, r, access, http.StatusOK)
}

// PUT /v1/groups/{gid}/phases/order — every live template id, in order.
// Projects follow for the phases they have not started.
func (s *Server) handleReorderPhaseTemplates(w http.ResponseWriter, r *http.Request) {
	access, err := s.hwGroup(r)
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
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	var live int
	if err := tx.QueryRowContext(r.Context(),
		`select count(*) from phase_templates where group_id = ? and archived = 0`, access.ID,
	).Scan(&live); err != nil {
		writeError(w, err)
		return
	}
	seen := map[string]bool{}
	for _, id := range body.IDs {
		if seen[id] {
			writeError(w, badRequest("invalid_order", "الترتيب فيه تكرار."))
			return
		}
		seen[id] = true
	}
	if len(body.IDs) != live {
		writeError(w, badRequest("invalid_order", "لازم الترتيب يشمل كل المراحل الحالية."))
		return
	}
	for i, id := range body.IDs {
		result, err := tx.ExecContext(r.Context(),
			`update phase_templates set ord = ? where id = ? and group_id = ? and archived = 0`,
			i, id, access.ID)
		if err != nil {
			writeError(w, err)
			return
		}
		if n, _ := result.RowsAffected(); n == 0 {
			writeError(w, badRequest("invalid_order", "مرحلة مش موجودة في القالب."))
			return
		}
	}
	// Not-started phases take the template order, after every phase the
	// project already started (history keeps its place).
	if _, err := tx.ExecContext(r.Context(), `
		update hw_phases set ord = 1000 + (select t.ord from phase_templates t where t.id = hw_phases.template_id)
		where status = 'not_started'
		  and template_id in (select id from phase_templates where group_id = ?)`, access.ID); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.writePhaseTemplates(w, r, access, http.StatusOK)
}

// --- project phases and gates -------------------------------------------------

type checklistItem struct {
	Text string `json:"text"`
	Done bool   `json:"done"`
}

func (s *store) hwPhases(ctx context.Context, projectID string) ([]map[string]any, error) {
	rows, err := s.db.QueryContext(ctx, `
		select p.id, p.name, p.status, p.checklist, p.started_at, p.gate_due_at,
		       (select count(*) from hw_builds b where b.phase_id = p.id)
		from hw_phases p where p.project_id = ? order by p.ord, p.created_at`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	phases := make([]map[string]any, 0)
	ids := []string{}
	for rows.Next() {
		var id, name, status, raw string
		var started, due *string
		var builds int
		if err := rows.Scan(&id, &name, &status, &raw, &started, &due, &builds); err != nil {
			return nil, err
		}
		items := []checklistItem{}
		_ = json.Unmarshal([]byte(raw), &items)
		phases = append(phases, map[string]any{
			"id": id, "name": name, "status": status, "checklist": items,
			"started_at": started, "gate_due_at": due, "builds": builds,
			"decisions": []map[string]any{},
		})
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	rows.Close()

	decisions, err := s.db.QueryContext(ctx, `
		select d.phase_id, d.decision, d.note, d.decided_at,
		       (select coalesce(nullif(u.display_name, ''), u.uid) from users u where u.uid = d.decided_by)
		from hw_gate_decisions d join hw_phases p on p.id = d.phase_id
		where p.project_id = ? order by d.decided_at`, projectID)
	if err != nil {
		return nil, err
	}
	defer decisions.Close()
	index := map[string]int{}
	for i, id := range ids {
		index[id] = i
	}
	for decisions.Next() {
		var phaseID, decision, at string
		var note, by *string
		if err := decisions.Scan(&phaseID, &decision, &note, &at, &by); err != nil {
			return nil, err
		}
		if i, ok := index[phaseID]; ok {
			phases[i]["decisions"] = append(phases[i]["decisions"].([]map[string]any),
				map[string]any{"decision": decision, "note": note, "at": at, "by": by})
		}
	}
	return phases, decisions.Err()
}

// GET .../hw/phases
func (s *Server) handleListPhases(w http.ResponseWriter, r *http.Request, h *hwContext) {
	phases, err := s.hwPhasesFor(r, h)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"phases": phases})
}

// hwPhasesFor drops who decided each gate (and the notes) for a guest.
func (s *Server) hwPhasesFor(r *http.Request, h *hwContext) ([]map[string]any, error) {
	phases, err := s.store.hwPhases(r.Context(), h.project)
	if err != nil || !h.guest() {
		return phases, err
	}
	for _, p := range phases {
		for _, d := range p["decisions"].([]map[string]any) {
			delete(d, "by")
			delete(d, "note")
		}
	}
	return phases, nil
}

type phaseUpdateRequest struct {
	Status    *string `json:"status"`
	GateDueAt *string `json:"gate_due_at"`
	// Check toggles one checklist item: {"index": 2, "done": true}.
	Check *struct {
		Index int  `json:"index"`
		Done  bool `json:"done"`
	} `json:"check"`
}

// PATCH .../hw/phases/{phid} — start, send to gate review, set the gate
// date, tick a checklist item. Gate decisions have their own endpoint.
func (s *Server) handleUpdatePhase(w http.ResponseWriter, r *http.Request, h *hwContext) {
	var body phaseUpdateRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	phaseID := r.PathValue("phid")
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	var status, raw string
	err = tx.QueryRowContext(r.Context(),
		`select status, checklist from hw_phases where id = ? and project_id = ?`, phaseID, h.project,
	).Scan(&status, &raw)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("phase_not_found", "المرحلة مش موجودة في المشروع."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if status == "passed" || status == "killed" {
		writeError(w, conflict("phase_closed", "المرحلة دي اتقفلت بقرار gate."))
		return
	}

	if body.Check != nil {
		if err := h.requireAny(CapEditTasks, CapManageBuilds, CapGateDecision); err != nil {
			writeError(w, err)
			return
		}
		// A not-started phase still follows the template, which would
		// overwrite the ticks.
		if status == "not_started" {
			writeError(w, conflict("phase_not_started", "ابدأ المرحلة الأول وبعدين علّم على الـ checklist."))
			return
		}
		items := []checklistItem{}
		_ = json.Unmarshal([]byte(raw), &items)
		if body.Check.Index < 0 || body.Check.Index >= len(items) {
			writeError(w, badRequest("invalid_checklist_item", "البند مش موجود."))
			return
		}
		items[body.Check.Index].Done = body.Check.Done
		encoded, _ := json.Marshal(items)
		if _, err := tx.ExecContext(r.Context(),
			`update hw_phases set checklist = ? where id = ?`, string(encoded), phaseID); err != nil {
			writeError(w, err)
			return
		}
	}
	if body.Status != nil || body.GateDueAt != nil {
		if err := h.requireAny(CapManageBuilds, CapGateDecision); err != nil {
			writeError(w, err)
			return
		}
	}
	if body.Status != nil {
		next := *body.Status
		allowed := map[string][]string{
			"not_started":      {"in_progress"},
			"in_progress":      {"ready_for_review"},
			"ready_for_review": {"in_progress"},
			"on_hold":          {"in_progress"},
		}
		if !oneOf(next, allowed[status]...) {
			writeError(w, conflict("invalid_phase_transition",
				fmt.Sprintf("مينفعش تنقل المرحلة من %s لـ %s.", status, next)))
			return
		}
		if _, err := tx.ExecContext(r.Context(), `
			update hw_phases set status = ?, started_at = coalesce(started_at, ?) where id = ?`,
			next, nowString(), phaseID); err != nil {
			writeError(w, err)
			return
		}
	}
	if body.GateDueAt != nil {
		var due any
		if d := strings.TrimSpace(*body.GateDueAt); d != "" {
			if len(d) > 40 {
				writeError(w, badRequest("invalid_date", "التاريخ غير صحيح."))
				return
			}
			due = d
		}
		if _, err := tx.ExecContext(r.Context(),
			`update hw_phases set gate_due_at = ? where id = ?`, due, phaseID); err != nil {
			writeError(w, err)
			return
		}
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.handleListPhases(w, r, h)
}

type gateRequest struct {
	Decision string  `json:"decision"`
	Note     *string `json:"note"`
}

// POST .../hw/phases/{phid}/gate — Go / Recycle / Hold / Kill.
//
//   - go: the phase passes and the next phase starts;
//   - recycle: another round in the same phase (EVT2), it stays in progress;
//   - hold: paused until someone resumes it;
//   - kill: the phase and every phase after it end.
func (s *Server) handleGateDecision(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapGateDecision); err != nil {
		writeError(w, err)
		return
	}
	var body gateRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if !oneOf(body.Decision, "go", "recycle", "hold", "kill") {
		writeError(w, badRequest("invalid_decision", "القرار لازم يكون go أو recycle أو hold أو kill."))
		return
	}
	note, err := optionalText(body.Note, 2000, "note_too_long", "الملاحظة")
	if err != nil {
		writeError(w, err)
		return
	}
	phaseID := r.PathValue("phid")
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	var status string
	var ord int
	err = tx.QueryRowContext(r.Context(),
		`select status, ord from hw_phases where id = ? and project_id = ?`, phaseID, h.project,
	).Scan(&status, &ord)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("phase_not_found", "المرحلة مش موجودة في المشروع."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if !oneOf(status, "in_progress", "ready_for_review", "on_hold") {
		writeError(w, conflict("phase_not_active", "الـ gate بيتعمل لمرحلة شغالة بس."))
		return
	}
	now := nowString()
	next := map[string]string{"go": "passed", "recycle": "in_progress", "hold": "on_hold", "kill": "killed"}[body.Decision]
	if _, err := tx.ExecContext(r.Context(),
		`update hw_phases set status = ? where id = ?`, next, phaseID); err != nil {
		writeError(w, err)
		return
	}
	switch body.Decision {
	case "go":
		if _, err := tx.ExecContext(r.Context(), `
			update hw_phases set status = 'in_progress', started_at = ?
			where id = (select id from hw_phases where project_id = ? and status = 'not_started'
			             order by ord, created_at limit 1)`, now, h.project); err != nil {
			writeError(w, err)
			return
		}
	case "kill":
		if _, err := tx.ExecContext(r.Context(), `
			update hw_phases set status = 'killed'
			where project_id = ? and status = 'not_started'`, h.project); err != nil {
			writeError(w, err)
			return
		}
	}
	if _, err := tx.ExecContext(r.Context(), `
		insert into hw_gate_decisions (id, phase_id, decision, note, decided_by, decided_at)
		values (?, ?, ?, ?, ?, ?)`, newID(), phaseID, body.Decision, note, h.caller.UID, now); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	pid := h.project
	_ = s.store.logActivity(r.Context(), h.ws.ID, h.caller.UID, "gate_decided",
		"قرار gate: "+body.Decision, &pid)
	s.handleListPhases(w, r, h)
}
