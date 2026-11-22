package api

import (
	"database/sql"
	"errors"
	"net/http"
	"strings"
	"time"
)

// Certifications (project) and lab booking (group) — migration 0009.

const (
	utcLayout      = "2006-01-02T15:04:05Z"
	maxBookingSpan = 14 * 24 * time.Hour
	// Bookings are taken up to bookingAheadDays out, and the list shows the
	// same window, so no slot is ever taken where nobody can see it.
	bookingListDays  = 92
	bookingAheadDays = 90
)

var certStatuses = []string{"planned", "booked", "testing", "passed", "failed", "expired"}

// cleanDate accepts "2006-01-02" or RFC 3339 and stores the date part.
func cleanDate(v *string, code string) (*string, bool, error) {
	if v == nil {
		return nil, false, nil
	}
	t := strings.TrimSpace(*v)
	if t == "" {
		return nil, true, nil // cleared
	}
	var d time.Time
	var err error
	if strings.Contains(t, "T") {
		d, err = time.Parse(time.RFC3339, t)
	} else {
		d, err = time.Parse("2006-01-02", t)
	}
	if err != nil {
		return nil, false, badRequest(code, "التاريخ لازم يكون بالشكل YYYY-MM-DD.")
	}
	out := d.Format("2006-01-02")
	return &out, false, nil
}

// cleanTime normalises a timestamp to UTC "2006-01-02T15:04:05Z" so that
// string order is time order (overlap checks compare strings).
func cleanTime(v string, code string) (string, error) {
	t, err := time.Parse(time.RFC3339, strings.TrimSpace(v))
	if err != nil {
		return "", badRequest(code, "الوقت لازم يكون RFC 3339 (مثلًا 2026-12-01T09:00:00+02:00).")
	}
	return t.UTC().Format(utcLayout), nil
}

// --- certifications ------------------------------------------------------------

type certRequest struct {
	Standard          *string `json:"standard"`
	Region            *string `json:"region"`
	Lab               *string `json:"lab"`
	BOMRevID          *string `json:"bom_rev_id"`
	Status            *string `json:"status"`
	PlannedAt         *string `json:"planned_at"`
	DueAt             *string `json:"due_at"`
	CertifiedAt       *string `json:"certified_at"`
	ExpiresAt         *string `json:"expires_at"`
	CertificateNumber *string `json:"certificate_number"`
	Note              *string `json:"note"`
}

// GET .../hw/certs — guests (the client) see the standards, statuses and
// dates; the lab, notes and the tested revision are the team's.
func (s *Server) handleListCerts(w http.ResponseWriter, r *http.Request, h *hwContext) {
	s.writeCerts(w, r, h, http.StatusOK)
}

func (s *Server) writeCerts(w http.ResponseWriter, r *http.Request, h *hwContext, status int) {
	rows, err := s.store.db.QueryContext(r.Context(), `
		select c.id, c.standard, c.region, c.lab, c.bom_rev_id, b.rev, c.status, c.planned_at, c.due_at,
		       c.certified_at, c.expires_at, c.certificate_number, c.note
		from hw_certs c left join hw_bom_revs b on b.id = c.bom_rev_id
		where c.project_id = ? order by c.due_at is null, c.due_at, c.standard`, h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	today := time.Now().UTC().Format("2006-01-02")
	soon := time.Now().UTC().AddDate(0, 0, 60).Format("2006-01-02")
	guest := h.guest()
	out := make([]map[string]any, 0)
	for rows.Next() {
		var id, standard, status string
		var region, lab, bomID, rev, planned, due, certified, expires, number, note *string
		if err := rows.Scan(&id, &standard, &region, &lab, &bomID, &rev, &status, &planned, &due,
			&certified, &expires, &number, &note); err != nil {
			writeError(w, err)
			return
		}
		open := status != "passed" && status != "expired"
		cert := map[string]any{
			"id": id, "standard": standard, "region": region, "status": status,
			"planned_at": planned, "due_at": due, "certified_at": certified, "expires_at": expires,
			"overdue":  open && due != nil && *due < today,
			"expiring": status == "passed" && expires != nil && *expires <= soon,
		}
		if !guest {
			cert["lab"], cert["bom_rev_id"], cert["bom_rev"] = lab, bomID, rev
			cert["certificate_number"], cert["note"] = number, note
		}
		out = append(out, cert)
	}
	writeJSON(w, status, map[string]any{"certs": out, "can_manage": h.access.can(CapManageCerts)})
}

func (b *certRequest) clean(create bool) (map[string]any, error) {
	vals := map[string]any{}
	if create || b.Standard != nil {
		v, err := requiredText(b.Standard, 40, "invalid_standard", "الشهادة")
		if err != nil {
			return nil, err
		}
		vals["standard"] = strings.ToUpper(v)
	}
	for key, spec := range map[string]struct {
		v   *string
		max int
	}{
		"region": {b.Region, 40}, "lab": {b.Lab, 80}, "certificate_number": {b.CertificateNumber, 80},
		"note": {b.Note, 2000},
	} {
		if spec.v == nil {
			continue
		}
		v, err := optionalText(spec.v, spec.max, key+"_too_long", key)
		if err != nil {
			return nil, err
		}
		if v == nil {
			vals[key] = nil
		} else {
			vals[key] = *v
		}
	}
	for key, v := range map[string]*string{
		"planned_at": b.PlannedAt, "due_at": b.DueAt, "certified_at": b.CertifiedAt, "expires_at": b.ExpiresAt,
	} {
		d, clear, err := cleanDate(v, "invalid_date")
		if err != nil {
			return nil, err
		}
		if d != nil {
			vals[key] = *d
		} else if clear {
			vals[key] = nil
		}
	}
	if b.Status != nil {
		if !oneOf(*b.Status, certStatuses...) {
			return nil, badRequest("invalid_status", "حالة الشهادة غير معروفة.")
		}
		vals["status"] = *b.Status
	}
	return vals, nil
}

// requireReleasedRev: a certification is for a released BOM revision.
func (s *Server) requireReleasedRev(r *http.Request, h *hwContext, revID string) error {
	var status string
	err := s.store.db.QueryRowContext(r.Context(),
		`select status from hw_bom_revs where id = ? and project_id = ?`, revID, h.project).Scan(&status)
	if errors.Is(err, sql.ErrNoRows) {
		return notFound("bom_not_found", "الـ BOM revision مش موجود في المشروع.")
	}
	if err != nil {
		return err
	}
	if status != "released" {
		return conflict("bom_not_released", "الشهادة بتتعمل على BOM اتعمله release.")
	}
	return nil
}

// POST .../hw/certs
func (s *Server) handleCreateCert(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapManageCerts); err != nil {
		writeError(w, err)
		return
	}
	var body certRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	vals, err := body.clean(true)
	if err != nil {
		writeError(w, err)
		return
	}
	var rev any
	if body.BOMRevID != nil && *body.BOMRevID != "" {
		if err := s.requireReleasedRev(r, h, *body.BOMRevID); err != nil {
			writeError(w, err)
			return
		}
		rev = *body.BOMRevID
	}
	status := "planned"
	if v, ok := vals["status"].(string); ok {
		status = v
	}
	if status == "passed" && vals["certified_at"] == nil {
		writeError(w, badRequest("certified_at_required", "حدد تاريخ الاعتماد."))
		return
	}
	now := nowString()
	id := newID()
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into hw_certs (id, project_id, standard, region, lab, bom_rev_id, status, planned_at, due_at,
		                      certified_at, expires_at, certificate_number, note, created_by, created_at, updated_at)
		values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		id, h.project, vals["standard"], vals["region"], vals["lab"], rev, status, vals["planned_at"],
		vals["due_at"], vals["certified_at"], vals["expires_at"], vals["certificate_number"], vals["note"],
		h.caller.UID, now, now); err != nil {
		writeError(w, err)
		return
	}
	s.writeCerts(w, r, h, http.StatusCreated)
}

// PATCH .../hw/certs/{cid}
func (s *Server) handleUpdateCert(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapManageCerts); err != nil {
		writeError(w, err)
		return
	}
	var body certRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	vals, err := body.clean(false)
	if err != nil {
		writeError(w, err)
		return
	}
	cid := r.PathValue("cid")
	var currentCertified *string
	var currentStatus string
	err = s.store.db.QueryRowContext(r.Context(),
		`select certified_at, status from hw_certs where id = ? and project_id = ?`, cid, h.project,
	).Scan(&currentCertified, &currentStatus)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("cert_not_found", "الشهادة مش موجودة في المشروع."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if body.BOMRevID != nil {
		if *body.BOMRevID == "" {
			vals["bom_rev_id"] = nil
		} else {
			if err := s.requireReleasedRev(r, h, *body.BOMRevID); err != nil {
				writeError(w, err)
				return
			}
			vals["bom_rev_id"] = *body.BOMRevID
		}
	}
	// What the row will be after the update: a passed certification always
	// has its date (clearing it, or passing without it, is refused).
	status := currentStatus
	if v, ok := vals["status"].(string); ok {
		status = v
	}
	hasDate := currentCertified != nil
	if v, ok := vals["certified_at"]; ok {
		hasDate = v != nil
	}
	if status == "passed" && !hasDate {
		writeError(w, badRequest("certified_at_required", "حدد تاريخ الاعتماد."))
		return
	}
	if len(vals) == 0 {
		s.handleListCerts(w, r, h)
		return
	}
	// Column names come from the fixed keys of clean(), never from input.
	sets := []string{}
	args := []any{}
	for _, col := range []string{"standard", "region", "lab", "bom_rev_id", "status", "planned_at", "due_at",
		"certified_at", "expires_at", "certificate_number", "note"} {
		if v, ok := vals[col]; ok {
			sets = append(sets, col+" = ?")
			args = append(args, v)
		}
	}
	args = append(args, nowString(), cid, h.project)
	if _, err := s.store.db.ExecContext(r.Context(),
		`update hw_certs set `+strings.Join(sets, ", ")+`, updated_at = ? where id = ? and project_id = ?`,
		args...); err != nil {
		writeError(w, err)
		return
	}
	s.handleListCerts(w, r, h)
}

// --- lab equipment and booking (group level) ---------------------------------------

// GET /v1/groups/{gid}/lab/assets
func (s *Server) handleListLabAssets(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.invGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	s.writeLabAssets(w, r, access, http.StatusOK)
}

func (s *Server) writeLabAssets(w http.ResponseWriter, r *http.Request, access *groupAccess, status int) {
	rows, err := s.store.db.QueryContext(r.Context(), `
		select id, name, kind, location, archived from lab_assets where group_id = ?
		order by archived, lower(name)`, access.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	out := make([]map[string]any, 0)
	for rows.Next() {
		var id, name string
		var kind, location *string
		var archived int
		if err := rows.Scan(&id, &name, &kind, &location, &archived); err != nil {
			writeError(w, err)
			return
		}
		out = append(out, map[string]any{
			"id": id, "name": name, "kind": kind, "location": location, "archived": archived == 1,
		})
	}
	writeJSON(w, status, map[string]any{
		"assets": out, "can_manage": access.can(CapManageLab), "can_book": canBookLab(access),
	})
}

func canBookLab(a *groupAccess) bool {
	return a.can(CapRecordTests) || a.can(CapManageBuilds) || a.can(CapManageLab)
}

type labAssetRequest struct {
	Name     *string `json:"name"`
	Kind     *string `json:"kind"`
	Location *string `json:"location"`
	Archived *bool   `json:"archived"`
}

// POST /v1/groups/{gid}/lab/assets
func (s *Server) handleCreateLabAsset(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.invGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapManageLab); err != nil {
		writeError(w, err)
		return
	}
	var body labAssetRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	name, err := requiredText(body.Name, 80, "invalid_name", "اسم الجهاز")
	if err != nil {
		writeError(w, err)
		return
	}
	kind, err := optionalText(body.Kind, 40, "kind_too_long", "النوع")
	if err != nil {
		writeError(w, err)
		return
	}
	location, err := optionalText(body.Location, 80, "location_too_long", "المكان")
	if err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into lab_assets (id, group_id, name, kind, location, created_at) values (?, ?, ?, ?, ?, ?)`,
		newID(), access.ID, name, kind, location, nowString()); err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			writeError(w, conflict("asset_exists", "في جهاز بنفس الاسم."))
			return
		}
		writeError(w, err)
		return
	}
	s.writeLabAssets(w, r, access, http.StatusCreated)
}

// PATCH /v1/groups/{gid}/lab/assets/{aid} — rename, move, archive.
// Archiving cancels the asset's future bookings.
func (s *Server) handleUpdateLabAsset(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.invGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapManageLab); err != nil {
		writeError(w, err)
		return
	}
	var body labAssetRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	var name any
	if body.Name != nil {
		n, err := requiredText(body.Name, 80, "invalid_name", "اسم الجهاز")
		if err != nil {
			writeError(w, err)
			return
		}
		name = n
	}
	kind, err := optionalText(body.Kind, 40, "kind_too_long", "النوع")
	if err != nil {
		writeError(w, err)
		return
	}
	location, err := optionalText(body.Location, 80, "location_too_long", "المكان")
	if err != nil {
		writeError(w, err)
		return
	}
	var archived any
	if body.Archived != nil {
		archived = boolInt(*body.Archived)
	}
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	aid := r.PathValue("aid")
	result, err := tx.ExecContext(r.Context(), `
		update lab_assets set name = coalesce(?, name),
		       kind = case when ? then null else coalesce(?, kind) end,
		       location = case when ? then null else coalesce(?, location) end,
		       archived = coalesce(?, archived)
		where id = ? and group_id = ?`,
		name, cleared(body.Kind), kind, cleared(body.Location), location, archived, aid, access.ID)
	if err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			writeError(w, conflict("asset_exists", "في جهاز بنفس الاسم."))
			return
		}
		writeError(w, err)
		return
	}
	if n, _ := result.RowsAffected(); n == 0 {
		writeError(w, notFound("asset_not_found", "الجهاز مش موجود في المجموعة."))
		return
	}
	if body.Archived != nil && *body.Archived {
		if _, err := tx.ExecContext(r.Context(), `
			update lab_bookings set status = 'cancelled'
			where asset_id = ? and status = 'active' and ends_at > ?`,
			aid, time.Now().UTC().Format(utcLayout)); err != nil {
			writeError(w, err)
			return
		}
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.writeLabAssets(w, r, access, http.StatusOK)
}

// GET /v1/groups/{gid}/lab/bookings?asset=&from= — active bookings from
// `from` (default now) for 31 days. A booking for a private project the
// caller cannot see shows as "busy": no project, no purpose.
func (s *Server) handleListLabBookings(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.invGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	from := time.Now().UTC().Add(-24 * time.Hour)
	if v := r.URL.Query().Get("from"); v != "" {
		if t, err := time.Parse(time.RFC3339, v); err == nil {
			from = t.UTC()
		} else if d, err := time.Parse("2006-01-02", v); err == nil {
			from = d
		} else {
			writeError(w, badRequest("invalid_from", "from لازم يكون YYYY-MM-DD أو RFC 3339 (و + تتكتب %2B)."))
			return
		}
	}
	to := from.AddDate(0, 0, bookingListDays)
	scope := scopeOf(access)
	hidden := `0`
	args := []any{}
	if !scope.SeesPrivate {
		hidden = `(b.project_id is not null and b.project_id in (` + hiddenProjects + `))`
		args = append(args, scope.UID)
	}
	query := `
		select b.id, b.asset_id, a.name, b.project_id, p.name, b.user_uid,
		       (select coalesce(nullif(u.display_name, ''), u.uid) from users u where u.uid = b.user_uid),
		       b.starts_at, b.ends_at, b.purpose, ` + hidden + `
		from lab_bookings b join lab_assets a on a.id = b.asset_id
		left join projects p on p.id = b.project_id
		where a.group_id = ? and b.status = 'active' and b.ends_at > ? and b.starts_at < ?`
	args = append(args, access.ID, from.Format(utcLayout), to.Format(utcLayout))
	if asset := r.URL.Query().Get("asset"); asset != "" {
		query += ` and b.asset_id = ?`
		args = append(args, asset)
	}
	rows, err := s.store.db.QueryContext(r.Context(), query+` order by b.starts_at`, args...)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	out := make([]map[string]any, 0)
	for rows.Next() {
		var id, assetID, assetName, starts, ends string
		var project, projectName, uid, by, purpose *string
		var isHidden bool
		if err := rows.Scan(&id, &assetID, &assetName, &project, &projectName, &uid, &by, &starts, &ends,
			&purpose, &isHidden); err != nil {
			writeError(w, err)
			return
		}
		if isHidden {
			project, projectName, purpose = nil, nil, nil
		}
		out = append(out, map[string]any{
			"id": id, "asset_id": assetID, "asset_name": assetName, "project_id": project,
			"project_name": projectName, "by": by, "mine": uid != nil && *uid == access.UID,
			"starts_at": starts, "ends_at": ends, "purpose": purpose, "private": isHidden,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"bookings": out, "can_book": canBookLab(access),
		"can_manage": access.can(CapManageLab)})
}

type bookingRequest struct {
	AssetID   string  `json:"asset_id"`
	ProjectID *string `json:"project_id"`
	StartsAt  string  `json:"starts_at"`
	EndsAt    string  `json:"ends_at"`
	Purpose   *string `json:"purpose"`
}

// POST /v1/groups/{gid}/lab/bookings — one slot of one asset, ≤ 14 days,
// in the future, never overlapping another active booking of it.
func (s *Server) handleCreateLabBooking(w http.ResponseWriter, r *http.Request) {
	caller, _, access, err := s.invGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if !canBookLab(access) {
		writeError(w, forbidden("missing_capability", "الحجز للي بيختبر أو بيدير الـ builds أو المعمل."))
		return
	}
	var body bookingRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	starts, err := cleanTime(body.StartsAt, "invalid_start")
	if err != nil {
		writeError(w, err)
		return
	}
	ends, err := cleanTime(body.EndsAt, "invalid_end")
	if err != nil {
		writeError(w, err)
		return
	}
	st, _ := time.Parse(utcLayout, starts)
	en, _ := time.Parse(utcLayout, ends)
	switch {
	case !en.After(st):
		writeError(w, badRequest("invalid_range", "النهاية لازم تكون بعد البداية."))
		return
	case en.Sub(st) > maxBookingSpan:
		writeError(w, badRequest("booking_too_long", "الحجز الواحد مايعدّيش 14 يوم."))
		return
	case st.Before(time.Now().UTC().Add(-5 * time.Minute)):
		writeError(w, badRequest("booking_in_past", "الحجز لوقت فات."))
		return
	case st.After(time.Now().UTC().AddDate(0, 0, bookingAheadDays)):
		writeError(w, badRequest("booking_too_far", "الحجز لحد 90 يوم قدام بس."))
		return
	}
	purpose, err := optionalText(body.Purpose, 200, "purpose_too_long", "الغرض")
	if err != nil {
		writeError(w, err)
		return
	}
	var project any
	if body.ProjectID != nil && *body.ProjectID != "" {
		// The project is one of this group's that the caller can see.
		pa, err := s.store.projectAccess(r.Context(), access, *body.ProjectID)
		if err != nil {
			writeError(w, err)
			return
		}
		// A read-only override on the project: no booking in its name.
		if !canBookLab(pa) {
			writeError(w, forbidden("missing_capability", "صلاحيتك على المشروع ده قراءة بس."))
			return
		}
		project = *body.ProjectID
	}
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	var archived int
	err = tx.QueryRowContext(r.Context(),
		`select archived from lab_assets where id = ? and group_id = ?`, body.AssetID, access.ID).Scan(&archived)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("asset_not_found", "الجهاز مش موجود في المجموعة."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if archived == 1 {
		writeError(w, conflict("asset_archived", "الجهاز متأرشف."))
		return
	}
	var clash int
	if err := tx.QueryRowContext(r.Context(), `
		select count(*) from lab_bookings
		where asset_id = ? and status = 'active' and starts_at < ? and ends_at > ?`,
		body.AssetID, ends, starts).Scan(&clash); err != nil {
		writeError(w, err)
		return
	}
	if clash > 0 {
		writeError(w, conflict("slot_taken", "الجهاز محجوز في جزء من الوقت ده."))
		return
	}
	id := newID()
	if _, err := tx.ExecContext(r.Context(), `
		insert into lab_bookings (id, asset_id, project_id, user_uid, starts_at, ends_at, purpose, created_at)
		values (?, ?, ?, ?, ?, ?, ?, ?)`,
		id, body.AssetID, project, caller.UID, starts, ends, purpose, nowString()); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"booking": map[string]any{
		"id": id, "starts_at": starts, "ends_at": ends,
	}})
}

// POST /v1/groups/{gid}/lab/bookings/{bkid}/cancel — the person who booked,
// or lab.manage.
func (s *Server) handleCancelLabBooking(w http.ResponseWriter, r *http.Request) {
	caller, _, access, err := s.invGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	var owner *string
	err = s.store.db.QueryRowContext(r.Context(), `
		select b.user_uid from lab_bookings b join lab_assets a on a.id = b.asset_id
		where b.id = ? and a.group_id = ? and b.status = 'active'`, r.PathValue("bkid"), access.ID).Scan(&owner)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("booking_not_found", "الحجز مش موجود."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if (owner == nil || *owner != caller.UID) && !access.can(CapManageLab) {
		writeError(w, forbidden("not_your_booking", "الحجز ده مش بتاعك."))
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(),
		`update lab_bookings set status = 'cancelled' where id = ?`, r.PathValue("bkid")); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
