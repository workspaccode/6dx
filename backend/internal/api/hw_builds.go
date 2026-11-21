package api

import (
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"strings"
)

// Builds, serialized units, test plans / results and the firmware ↔ hardware
// matrix — §7.2.

var buildStatuses = []string{"planned", "parts_ordered", "assembling", "received", "testing", "complete", "cancelled"}
var unitStatuses = []string{"untested", "passed", "failed", "rework", "scrapped"}

const maxUnitsPerRequest = 500

// GET .../hw/builds
func (s *Server) handleListBuilds(w http.ResponseWriter, r *http.Request, h *hwContext) {
	rows, err := s.store.db.QueryContext(r.Context(), `
		select b.id, b.name, b.status, b.quantity, b.cm, b.planned_at, b.phase_id, ph.name,
		       b.bom_rev_id, br.rev,
		       (select count(*) from hw_units u where u.build_id = b.id),
		       (select count(*) from hw_units u where u.build_id = b.id and u.status = 'passed'),
		       (select count(*) from hw_units u where u.build_id = b.id and u.status = 'failed')
		from hw_builds b
		left join hw_phases ph on ph.id = b.phase_id
		left join hw_bom_revs br on br.id = b.bom_rev_id
		where b.project_id = ? order by b.created_at desc`, h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	builds := make([]map[string]any, 0)
	for rows.Next() {
		var id, name, status, bomRev string
		var qty, units, passed, failed int
		var cm, planned, phaseID, phaseName, rev *string
		if err := rows.Scan(&id, &name, &status, &qty, &cm, &planned, &phaseID, &phaseName,
			&bomRev, &rev, &units, &passed, &failed); err != nil {
			writeError(w, err)
			return
		}
		builds = append(builds, map[string]any{
			"id": id, "name": name, "status": status, "quantity": qty, "cm": cm,
			"planned_at": planned, "phase_id": phaseID, "phase_name": phaseName,
			"bom_rev_id": bomRev, "bom_rev": rev,
			"units": units, "passed": passed, "failed": failed,
		})
	}
	if err := rows.Err(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"builds": builds})
}

type buildRequest struct {
	Name      *string `json:"name"`
	PhaseID   *string `json:"phase_id"`
	BOMRevID  *string `json:"bom_rev_id"`
	Quantity  *int    `json:"quantity"`
	CM        *string `json:"cm"`
	PlannedAt *string `json:"planned_at"`
	Status    *string `json:"status"`
}

// POST .../hw/builds — a build is made from a released BOM revision.
func (s *Server) handleCreateBuild(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapManageBuilds); err != nil {
		writeError(w, err)
		return
	}
	var body buildRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	name, err := requiredText(body.Name, 40, "invalid_build_name", "اسم الـ build")
	if err != nil {
		writeError(w, err)
		return
	}
	if body.Quantity == nil || *body.Quantity < 1 || *body.Quantity > 100000 {
		writeError(w, badRequest("invalid_quantity", "الكمية لازم تكون من 1 لـ 100000."))
		return
	}
	cm, err := optionalText(body.CM, 80, "cm_too_long", "المصنّع")
	if err != nil {
		writeError(w, err)
		return
	}
	planned, err := optionalText(body.PlannedAt, 40, "invalid_date", "التاريخ")
	if err != nil {
		writeError(w, err)
		return
	}
	if body.BOMRevID == nil || *body.BOMRevID == "" {
		writeError(w, badRequest("bom_required", "اختار BOM revision اتعمله release."))
		return
	}
	var bomStatus string
	err = s.store.db.QueryRowContext(r.Context(),
		`select status from hw_bom_revs where id = ? and project_id = ?`, *body.BOMRevID, h.project,
	).Scan(&bomStatus)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("bom_not_found", "الـ BOM revision مش موجود في المشروع."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if bomStatus != "released" {
		writeError(w, conflict("bom_not_released", "الـ build بيتعمل من BOM اتعمله release بس."))
		return
	}
	var phase any
	if body.PhaseID != nil && *body.PhaseID != "" {
		if err := s.store.hwOwned(r.Context(), s.store.db, "hw_phases", *body.PhaseID, h.project, "phase_not_found"); err != nil {
			writeError(w, err)
			return
		}
		phase = *body.PhaseID
	}
	id, now := newID(), nowString()
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into hw_builds (id, project_id, phase_id, name, bom_rev_id, quantity, cm, planned_at,
		                       created_by, created_at, updated_at)
		values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		id, h.project, phase, name, *body.BOMRevID, *body.Quantity, cm, planned, h.caller.UID, now, now,
	); err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			writeError(w, conflict("build_name_taken", "في build بنفس الاسم في المشروع."))
			return
		}
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"build": map[string]any{"id": id, "name": name}})
}

// PATCH .../hw/builds/{bid} — status, CM, date.
func (s *Server) handleUpdateBuild(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapManageBuilds); err != nil {
		writeError(w, err)
		return
	}
	var body buildRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if body.Name != nil || body.BOMRevID != nil || body.Quantity != nil {
		writeError(w, badRequest("build_fixed_fields", "الاسم والـ BOM والكمية بيتحددوا وقت إنشاء الـ build."))
		return
	}
	if body.Status != nil && !oneOf(*body.Status, buildStatuses...) {
		writeError(w, badRequest("invalid_status", "حالة الـ build غير معروفة."))
		return
	}
	cm, err := optionalText(body.CM, 80, "cm_too_long", "المصنّع")
	if err != nil {
		writeError(w, err)
		return
	}
	planned, err := optionalText(body.PlannedAt, 40, "invalid_date", "التاريخ")
	if err != nil {
		writeError(w, err)
		return
	}
	result, err := s.store.db.ExecContext(r.Context(), `
		update hw_builds set status = coalesce(?, status), cm = coalesce(?, cm),
		       planned_at = coalesce(?, planned_at), updated_at = ?
		where id = ? and project_id = ?`,
		body.Status, cm, planned, nowString(), r.PathValue("bid"), h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	if n, _ := result.RowsAffected(); n == 0 {
		writeError(w, notFound("build_not_found", "الـ build مش موجود في المشروع."))
		return
	}
	s.handleListBuilds(w, r, h)
}

// GET .../hw/builds/{bid}/units
func (s *Server) handleListUnits(w http.ResponseWriter, r *http.Request, h *hwContext) {
	bid := r.PathValue("bid")
	if err := s.store.hwOwned(r.Context(), s.store.db, "hw_builds", bid, h.project, "build_not_found"); err != nil {
		writeError(w, err)
		return
	}
	rows, err := s.store.db.QueryContext(r.Context(), `
		select u.id, u.serial, u.firmware_version, u.location, u.status,
		       (select count(*) from hw_test_results t where t.unit_id = u.id)
		from hw_units u where u.build_id = ? order by u.serial`, bid)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	units := make([]map[string]any, 0)
	for rows.Next() {
		var id, serial, status string
		var fw, location *string
		var results int
		if err := rows.Scan(&id, &serial, &fw, &location, &status, &results); err != nil {
			writeError(w, err)
			return
		}
		units = append(units, map[string]any{
			"id": id, "serial": serial, "firmware_version": fw, "location": location,
			"status": status, "results": results,
		})
	}
	if err := rows.Err(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"units": units})
}

type unitsRequest struct {
	// Either explicit serials, or count + prefix (PFX-001, PFX-002…).
	Serials []string `json:"serials"`
	Count   int      `json:"count"`
	Prefix  string   `json:"prefix"`
}

// POST .../hw/builds/{bid}/units — register units; never more than the
// build's quantity.
func (s *Server) handleCreateUnits(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapManageBuilds); err != nil {
		writeError(w, err)
		return
	}
	var body unitsRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	bid := r.PathValue("bid")
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	var quantity, existing int
	err = tx.QueryRowContext(r.Context(), `
		select b.quantity, (select count(*) from hw_units u where u.build_id = b.id)
		from hw_builds b where b.id = ? and b.project_id = ?`, bid, h.project).Scan(&quantity, &existing)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("build_not_found", "الـ build مش موجود في المشروع."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	serials := []string{}
	seen := map[string]bool{}
	if len(body.Serials) > 0 {
		for _, raw := range body.Serials {
			serial := strings.TrimSpace(raw)
			if serial == "" || seen[serial] {
				continue
			}
			if tooLong(serial, 64) {
				writeError(w, badRequest("invalid_serial", "السيريال أطول من 64 حرف."))
				return
			}
			seen[serial] = true
			serials = append(serials, serial)
		}
	} else {
		prefix := strings.TrimSpace(body.Prefix)
		if prefix == "" || tooLong(prefix, 40) {
			writeError(w, badRequest("invalid_prefix", "البادئة لازم تكون من 1 لـ 40 حرف."))
			return
		}
		if body.Count < 1 || body.Count > maxUnitsPerRequest {
			writeError(w, badRequest("invalid_count", fmt.Sprintf("العدد من 1 لـ %d.", maxUnitsPerRequest)))
			return
		}
		for i := 1; i <= body.Count; i++ {
			serials = append(serials, fmt.Sprintf("%s-%03d", prefix, existing+i))
		}
	}
	if len(serials) == 0 || len(serials) > maxUnitsPerRequest {
		writeError(w, badRequest("invalid_count", fmt.Sprintf("العدد من 1 لـ %d.", maxUnitsPerRequest)))
		return
	}
	if existing+len(serials) > quantity {
		writeError(w, conflict("units_exceed_quantity",
			fmt.Sprintf("الـ build كميته %d، ومسجل فيه %d وحدة.", quantity, existing)))
		return
	}
	now := nowString()
	for _, serial := range serials {
		if _, err := tx.ExecContext(r.Context(), `
			insert into hw_units (id, build_id, serial, created_at, updated_at) values (?, ?, ?, ?, ?)`,
			newID(), bid, serial, now, now); err != nil {
			if strings.Contains(err.Error(), "UNIQUE") {
				writeError(w, conflict("serial_taken", "السيريال "+serial+" متسجل قبل كده."))
				return
			}
			writeError(w, err)
			return
		}
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.handleListUnits(w, r, h)
}

// unitOf checks a unit belongs to the project (through its build).
func (s *Server) unitOf(r *http.Request, h *hwContext) (buildID string, err error) {
	err = s.store.db.QueryRowContext(r.Context(), `
		select u.build_id from hw_units u join hw_builds b on b.id = u.build_id
		where u.id = ? and b.project_id = ?`, r.PathValue("unid"), h.project).Scan(&buildID)
	if errors.Is(err, sql.ErrNoRows) {
		return "", notFound("unit_not_found", "الوحدة مش موجودة في المشروع.")
	}
	return buildID, err
}

type unitUpdateRequest struct {
	FirmwareVersion *string `json:"firmware_version"`
	Location        *string `json:"location"`
	Status          *string `json:"status"`
}

// PATCH .../hw/units/{unid} — firmware, location, status.
func (s *Server) handleUpdateUnit(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.requireAny(CapManageBuilds, CapRecordTests); err != nil {
		writeError(w, err)
		return
	}
	var body unitUpdateRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if body.Status != nil && !oneOf(*body.Status, unitStatuses...) {
		writeError(w, badRequest("invalid_status", "حالة الوحدة غير معروفة."))
		return
	}
	fw, err := optionalText(body.FirmwareVersion, 64, "firmware_too_long", "إصدار الـ firmware")
	if err != nil {
		writeError(w, err)
		return
	}
	location, err := optionalText(body.Location, 80, "location_too_long", "المكان")
	if err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.unitOf(r, h); err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(), `
		update hw_units set firmware_version = coalesce(?, firmware_version),
		       location = coalesce(?, location), status = coalesce(?, status), updated_at = ?
		where id = ?`, fw, location, body.Status, nowString(), r.PathValue("unid")); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// --- tests -------------------------------------------------------------------

// GET .../hw/tests
func (s *Server) handleListTestPlans(w http.ResponseWriter, r *http.Request, h *hwContext) {
	rows, err := s.store.db.QueryContext(r.Context(), `
		select t.id, t.title, t.criteria, t.phase_id, ph.name, t.approved_at, t.created_by,
		       (select count(*) from hw_test_results x where x.plan_id = t.id and x.result = 'pass'),
		       (select count(*) from hw_test_results x where x.plan_id = t.id and x.result = 'fail')
		from hw_test_plans t left join hw_phases ph on ph.id = t.phase_id
		where t.project_id = ? order by t.created_at`, h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	plans := make([]map[string]any, 0)
	for rows.Next() {
		var id, title string
		var criteria, phaseID, phaseName, approved, createdBy *string
		var pass, fail int
		if err := rows.Scan(&id, &title, &criteria, &phaseID, &phaseName, &approved, &createdBy, &pass, &fail); err != nil {
			writeError(w, err)
			return
		}
		plans = append(plans, map[string]any{
			"id": id, "title": title, "criteria": criteria, "phase_id": phaseID,
			"phase_name": phaseName, "approved": approved != nil, "approved_at": approved,
			"created_by": createdBy, "passed": pass, "failed": fail,
		})
	}
	if err := rows.Err(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"plans": plans})
}

// POST .../hw/tests — a test plan (requirements + acceptance criteria).
func (s *Server) handleCreateTestPlan(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.requireAny(CapApproveTests, CapRecordTests); err != nil {
		writeError(w, err)
		return
	}
	var body struct {
		Title    *string `json:"title"`
		Criteria *string `json:"criteria"`
		PhaseID  *string `json:"phase_id"`
	}
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	title, err := requiredText(body.Title, 200, "invalid_title", "عنوان الاختبار")
	if err != nil {
		writeError(w, err)
		return
	}
	criteria, err := optionalText(body.Criteria, 5000, "criteria_too_long", "معايير القبول")
	if err != nil {
		writeError(w, err)
		return
	}
	var phase any
	if body.PhaseID != nil && *body.PhaseID != "" {
		if err := s.store.hwOwned(r.Context(), s.store.db, "hw_phases", *body.PhaseID, h.project, "phase_not_found"); err != nil {
			writeError(w, err)
			return
		}
		phase = *body.PhaseID
	}
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into hw_test_plans (id, project_id, phase_id, title, criteria, created_by, created_at)
		values (?, ?, ?, ?, ?, ?, ?)`,
		newID(), h.project, phase, title, criteria, h.caller.UID, nowString()); err != nil {
		writeError(w, err)
		return
	}
	s.handleListTestPlans(w, r, h)
}

// POST .../hw/tests/{tpid}/approve — someone other than its author.
func (s *Server) handleApproveTestPlan(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapApproveTests); err != nil {
		writeError(w, err)
		return
	}
	var author *string
	err := s.store.db.QueryRowContext(r.Context(),
		`select created_by from hw_test_plans where id = ? and project_id = ?`, r.PathValue("tpid"), h.project,
	).Scan(&author)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("test_plan_not_found", "خطة الاختبار مش موجودة في المشروع."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if author != nil && *author == h.caller.UID {
		writeError(w, forbidden("cannot_approve_own", "اللي كتب خطة الاختبار مايعتمدهاش."))
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(), `
		update hw_test_plans set approved_by = ?, approved_at = ? where id = ?`,
		h.caller.UID, nowString(), r.PathValue("tpid")); err != nil {
		writeError(w, err)
		return
	}
	s.handleListTestPlans(w, r, h)
}

// GET .../hw/units/{unid}/results
func (s *Server) handleListUnitResults(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if _, err := s.unitOf(r, h); err != nil {
		writeError(w, err)
		return
	}
	rows, err := s.store.db.QueryContext(r.Context(), `
		select x.id, x.plan_id, t.title, x.result, x.notes, x.firmware_version, x.recorded_at,
		       (select coalesce(nullif(u.display_name, ''), u.uid) from users u where u.uid = x.recorded_by)
		from hw_test_results x join hw_test_plans t on t.id = x.plan_id
		where x.unit_id = ? order by x.recorded_at desc`, r.PathValue("unid"))
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	results := make([]map[string]any, 0)
	for rows.Next() {
		var id, planID, title, result, at string
		var notes, fw, by *string
		if err := rows.Scan(&id, &planID, &title, &result, &notes, &fw, &at, &by); err != nil {
			writeError(w, err)
			return
		}
		results = append(results, map[string]any{
			"id": id, "plan_id": planID, "plan_title": title, "result": result, "notes": notes,
			"firmware_version": fw, "recorded_at": at, "recorded_by": by,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"results": results})
}

// POST .../hw/units/{unid}/results — record pass / fail. The unit takes the
// result as its status, and the firmware it ran is copied, so a failure
// names the exact hardware + firmware combination.
func (s *Server) handleRecordResult(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapRecordTests); err != nil {
		writeError(w, err)
		return
	}
	var body struct {
		PlanID string  `json:"plan_id"`
		Result string  `json:"result"`
		Notes  *string `json:"notes"`
	}
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if !oneOf(body.Result, "pass", "fail") {
		writeError(w, badRequest("invalid_result", "النتيجة لازم تكون pass أو fail."))
		return
	}
	notes, err := optionalText(body.Notes, 2000, "notes_too_long", "الملاحظات")
	if err != nil {
		writeError(w, err)
		return
	}
	if body.Result == "fail" && notes == nil {
		writeError(w, badRequest("notes_required", "اكتب إيه اللي فشل."))
		return
	}
	if _, err := s.unitOf(r, h); err != nil {
		writeError(w, err)
		return
	}
	if err := s.store.hwOwned(r.Context(), s.store.db, "hw_test_plans", body.PlanID, h.project, "test_plan_not_found"); err != nil {
		writeError(w, err)
		return
	}
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	unitID, now := r.PathValue("unid"), nowString()
	if _, err := tx.ExecContext(r.Context(), `
		insert into hw_test_results (id, plan_id, unit_id, result, notes, firmware_version, recorded_by, recorded_at)
		values (?, ?, ?, ?, ?, (select firmware_version from hw_units where id = ?), ?, ?)`,
		newID(), body.PlanID, unitID, body.Result, notes, unitID, h.caller.UID, now); err != nil {
		writeError(w, err)
		return
	}
	status := map[string]string{"pass": "passed", "fail": "failed"}[body.Result]
	if _, err := tx.ExecContext(r.Context(),
		`update hw_units set status = ?, updated_at = ? where id = ?`, status, now, unitID); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.handleListUnitResults(w, r, h)
}

// --- firmware ↔ hardware -----------------------------------------------------

// GET .../hw/firmware
func (s *Server) handleListFirmware(w http.ResponseWriter, r *http.Request, h *hwContext) {
	rows, err := s.store.db.QueryContext(r.Context(), `
		select f.firmware_tag, f.bom_rev_id, b.rev, f.note, f.verified_at,
		       (select coalesce(nullif(u.display_name, ''), u.uid) from users u where u.uid = f.verified_by)
		from hw_fw_compat f join hw_bom_revs b on b.id = f.bom_rev_id
		where f.project_id = ? order by f.verified_at desc`, h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	links := make([]map[string]any, 0)
	for rows.Next() {
		var tag, bomID, rev, at string
		var note, by *string
		if err := rows.Scan(&tag, &bomID, &rev, &note, &at, &by); err != nil {
			writeError(w, err)
			return
		}
		links = append(links, map[string]any{
			"firmware_tag": tag, "bom_rev_id": bomID, "bom_rev": rev, "note": note,
			"verified_at": at, "verified_by": by,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"links": links})
}

type firmwareRequest struct {
	FirmwareTag string  `json:"firmware_tag"`
	BOMRevID    string  `json:"bom_rev_id"`
	Note        *string `json:"note"`
}

// POST .../hw/firmware — "firmware tag X was verified on BOM revision Y".
func (s *Server) handleLinkFirmware(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapFirmwareLink); err != nil {
		writeError(w, err)
		return
	}
	var body firmwareRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	tag, err := requiredText(&body.FirmwareTag, 64, "invalid_tag", "الـ firmware tag")
	if err != nil {
		writeError(w, err)
		return
	}
	note, err := optionalText(body.Note, 500, "note_too_long", "الملاحظة")
	if err != nil {
		writeError(w, err)
		return
	}
	var status string
	err = s.store.db.QueryRowContext(r.Context(),
		`select status from hw_bom_revs where id = ? and project_id = ?`, body.BOMRevID, h.project).Scan(&status)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("bom_not_found", "الـ BOM revision مش موجود في المشروع."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if status != "released" {
		writeError(w, conflict("bom_not_released", "التوافق بيتسجل على BOM اتعمله release."))
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into hw_fw_compat (project_id, firmware_tag, bom_rev_id, note, verified_by, verified_at)
		values (?, ?, ?, ?, ?, ?)
		on conflict (project_id, firmware_tag, bom_rev_id) do update
		  set note = excluded.note, verified_by = excluded.verified_by, verified_at = excluded.verified_at`,
		h.project, tag, body.BOMRevID, note, h.caller.UID, nowString()); err != nil {
		writeError(w, err)
		return
	}
	s.handleListFirmware(w, r, h)
}

// DELETE .../hw/firmware?tag=&bom_rev_id=
func (s *Server) handleUnlinkFirmware(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapFirmwareLink); err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(), `
		delete from hw_fw_compat where project_id = ? and firmware_tag = ? and bom_rev_id = ?`,
		h.project, r.URL.Query().Get("tag"), r.URL.Query().Get("bom_rev_id")); err != nil {
		writeError(w, err)
		return
	}
	s.handleListFirmware(w, r, h)
}

// --- overview ----------------------------------------------------------------

// GET .../hw/overview — the project's hardware home: phases, the current
// BOM, open changes, builds and test numbers, plus the caller's
// capabilities so the app knows which buttons to show.
func (s *Server) handleHWOverview(w http.ResponseWriter, r *http.Request, h *hwContext) {
	phases, err := s.store.hwPhases(r.Context(), h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	var released, draft sql.NullString
	var openECOs, reviewECOs, builds, units, passed, failed, plans, firmware int
	if err := s.store.db.QueryRowContext(r.Context(), `
		select
		  (select rev from hw_bom_revs where project_id = ?1 and status = 'released'
		    order by length(rev) desc, rev desc limit 1),
		  (select rev from hw_bom_revs where project_id = ?1 and status = 'draft'),
		  (select count(*) from hw_ecos where project_id = ?1
		    and status in ('draft', 'design_review', 'production_review', 'approved')),
		  (select count(*) from hw_ecos where project_id = ?1
		    and status in ('design_review', 'production_review')),
		  (select count(*) from hw_builds where project_id = ?1),
		  (select count(*) from hw_units u join hw_builds b on b.id = u.build_id where b.project_id = ?1),
		  (select count(*) from hw_units u join hw_builds b on b.id = u.build_id
		    where b.project_id = ?1 and u.status = 'passed'),
		  (select count(*) from hw_units u join hw_builds b on b.id = u.build_id
		    where b.project_id = ?1 and u.status = 'failed'),
		  (select count(*) from hw_test_plans where project_id = ?1),
		  (select count(*) from hw_fw_compat where project_id = ?1)`, h.project,
	).Scan(&released, &draft, &openECOs, &reviewECOs, &builds, &units, &passed, &failed, &plans, &firmware); err != nil {
		writeError(w, err)
		return
	}
	var current any
	for _, p := range phases {
		if oneOf(p["status"].(string), "in_progress", "ready_for_review", "on_hold") {
			current = p["id"]
			break
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"phases":           phases,
		"current_phase_id": current,
		"bom":              map[string]any{"released": nullString(released), "draft": nullString(draft)},
		"ecos":             map[string]any{"open": openECOs, "in_review": reviewECOs},
		"builds":           map[string]any{"count": builds, "units": units, "passed": passed, "failed": failed},
		"tests":            map[string]any{"plans": plans},
		"firmware_links":   firmware,
		"capabilities":     sortedCaps(h.access.Caps),
	})
}

func nullString(v sql.NullString) any {
	if !v.Valid {
		return nil
	}
	return v.String
}
