package api

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"
)

// Procurement and inventory (hardware only) — §7.5, migration 0006.
//
// Group level: vendors, stock (the sum of append-only movements), the PO
// approval threshold. Project level (under .../hw/, through hwHandler):
// purchase orders, reservations, the demand of the open builds.
//
// Every quantity change runs in one transaction with its check; the single
// SQLite connection serialises them, so two requests cannot both take the
// last units.

const (
	maxPOLines        = 200
	defaultLocation   = "main"
	maxMovementQty    = 1_000_000
	movementListLimit = 200
)

// --- group level ---------------------------------------------------------------

// invGroup: a hardware group, and not a guest (the client never sees
// stock or vendors).
func (s *Server) invGroup(r *http.Request) (*authCaller, *Workspace, *groupAccess, error) {
	caller, ws, access, err := s.groupFromRequest(r)
	if err != nil {
		return nil, nil, nil, err
	}
	if access.Type != GroupHardware {
		return nil, nil, nil, conflict("group_type_mismatch", "المخزن والمشتريات لمجموعات الـ Hardware بس.")
	}
	if access.IsMember && access.GroupRole == GroupGuest {
		return nil, nil, nil, forbidden("guest_progress_only", "العميل بيشوف تقدم المشروع بس.")
	}
	return caller, ws, access, nil
}

type invSettings struct {
	ThresholdCents int64  `json:"po_approval_threshold_cents"`
	Currency       string `json:"currency"`
}

func invSettingsOf(ctx context.Context, q queryer, groupID string) (invSettings, error) {
	st := invSettings{Currency: "USD"}
	err := q.QueryRowContext(ctx,
		`select po_approval_threshold_cents, currency from inv_settings where group_id = ?`, groupID,
	).Scan(&st.ThresholdCents, &st.Currency)
	if errors.Is(err, sql.ErrNoRows) {
		return st, nil
	}
	return st, err
}

// GET /v1/groups/{gid}/inventory/settings
func (s *Server) handleGetInvSettings(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.invGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	st, err := invSettingsOf(r.Context(), s.store.db, access.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"settings": st, "can_manage": access.can(CapManageGroup)})
}

// PATCH /v1/groups/{gid}/inventory/settings — the lead / admins set the PO
// approval threshold (per group, §12) and the currency.
func (s *Server) handleUpdateInvSettings(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.invGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapManageGroup); err != nil {
		writeError(w, err)
		return
	}
	var body struct {
		ThresholdCents *int64  `json:"po_approval_threshold_cents"`
		Currency       *string `json:"currency"`
	}
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	st, err := invSettingsOf(r.Context(), s.store.db, access.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	if body.ThresholdCents != nil {
		if *body.ThresholdCents < 0 || *body.ThresholdCents > 1_000_000_000_00 {
			writeError(w, badRequest("invalid_threshold", "حد الاعتماد غير صحيح."))
			return
		}
		st.ThresholdCents = *body.ThresholdCents
	}
	if body.Currency != nil {
		c := strings.ToUpper(strings.TrimSpace(*body.Currency))
		if len(c) != 3 {
			writeError(w, badRequest("invalid_currency", "العملة لازم تكون 3 حروف (USD، EGP…)."))
			return
		}
		st.Currency = c
	}
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into inv_settings (group_id, po_approval_threshold_cents, currency, updated_at)
		values (?, ?, ?, ?)
		on conflict (group_id) do update set po_approval_threshold_cents = excluded.po_approval_threshold_cents,
		  currency = excluded.currency, updated_at = excluded.updated_at`,
		access.ID, st.ThresholdCents, st.Currency, nowString()); err != nil {
		writeError(w, err)
		return
	}
	// Raising the threshold lets bigger POs skip approval: keep a trace.
	_ = s.store.logActivity(r.Context(), access.WorkspaceID, access.UID, "po_threshold_changed",
		fmt.Sprintf("حد اعتماد أوامر الشراء: %d %s (سنت)", st.ThresholdCents, st.Currency), nil)
	writeJSON(w, http.StatusOK, map[string]any{"settings": st, "can_manage": true})
}

func (s *store) vendorsPayload(ctx context.Context, access *groupAccess) (map[string]any, error) {
	rows, err := s.db.QueryContext(ctx, `
		select id, name, contact, default_lead_days, archived from inv_vendors
		where group_id = ? order by archived, lower(name)`, access.ID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	vendors := make([]map[string]any, 0)
	for rows.Next() {
		var id, name string
		var contact *string
		var lead, archived int
		if err := rows.Scan(&id, &name, &contact, &lead, &archived); err != nil {
			return nil, err
		}
		vendors = append(vendors, map[string]any{
			"id": id, "name": name, "contact": contact, "default_lead_days": lead, "archived": archived == 1,
		})
	}
	return map[string]any{"vendors": vendors, "can_manage": access.can(CapManageVendors)}, rows.Err()
}

func (s *Server) writeVendors(w http.ResponseWriter, r *http.Request, access *groupAccess, status int) {
	payload, err := s.store.vendorsPayload(r.Context(), access)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, status, payload)
}

// GET /v1/groups/{gid}/vendors
func (s *Server) handleListVendors(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.invGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	s.writeVendors(w, r, access, http.StatusOK)
}

type vendorRequest struct {
	Name     *string `json:"name"`
	Contact  *string `json:"contact"`
	LeadDays *int    `json:"default_lead_days"`
	Archived *bool   `json:"archived"`
}

// POST /v1/groups/{gid}/vendors
func (s *Server) handleCreateVendor(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.invGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapManageVendors); err != nil {
		writeError(w, err)
		return
	}
	var body vendorRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	name, err := requiredText(body.Name, 80, "invalid_vendor_name", "اسم المورّد")
	if err != nil {
		writeError(w, err)
		return
	}
	contact, err := optionalText(body.Contact, 500, "contact_too_long", "بيانات التواصل")
	if err != nil {
		writeError(w, err)
		return
	}
	lead := 14
	if body.LeadDays != nil {
		if *body.LeadDays < 0 || *body.LeadDays > 365 {
			writeError(w, badRequest("invalid_lead_days", "مدة التوريد من 0 لـ 365 يوم."))
			return
		}
		lead = *body.LeadDays
	}
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into inv_vendors (id, group_id, name, contact, default_lead_days, created_at)
		values (?, ?, ?, ?, ?, ?)`, newID(), access.ID, name, contact, lead, nowString()); err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			writeError(w, conflict("vendor_exists", "في مورّد بنفس الاسم."))
			return
		}
		writeError(w, err)
		return
	}
	s.writeVendors(w, r, access, http.StatusCreated)
}

// PATCH /v1/groups/{gid}/vendors/{vid}
func (s *Server) handleUpdateVendor(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.invGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapManageVendors); err != nil {
		writeError(w, err)
		return
	}
	var body vendorRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	var name *string
	if body.Name != nil {
		n, err := requiredText(body.Name, 80, "invalid_vendor_name", "اسم المورّد")
		if err != nil {
			writeError(w, err)
			return
		}
		name = &n
	}
	contact, err := optionalText(body.Contact, 500, "contact_too_long", "بيانات التواصل")
	if err != nil {
		writeError(w, err)
		return
	}
	if body.LeadDays != nil && (*body.LeadDays < 0 || *body.LeadDays > 365) {
		writeError(w, badRequest("invalid_lead_days", "مدة التوريد من 0 لـ 365 يوم."))
		return
	}
	var archived any
	if body.Archived != nil {
		archived = boolInt(*body.Archived)
	}
	result, err := s.store.db.ExecContext(r.Context(), `
		update inv_vendors set name = coalesce(?, name),
		       contact = case when ? then null else coalesce(?, contact) end,
		       default_lead_days = coalesce(?, default_lead_days), archived = coalesce(?, archived)
		where id = ? and group_id = ?`,
		name, cleared(body.Contact), contact, body.LeadDays, archived, r.PathValue("vid"), access.ID)
	if err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			writeError(w, conflict("vendor_exists", "في مورّد بنفس الاسم."))
			return
		}
		writeError(w, err)
		return
	}
	if n, _ := result.RowsAffected(); n == 0 {
		writeError(w, notFound("vendor_not_found", "المورّد مش موجود في المجموعة."))
		return
	}
	s.writeVendors(w, r, access, http.StatusOK)
}

// --- stock ---------------------------------------------------------------------

// reservedIn: active reservations of a part across the group's projects.
const reservedIn = `(select coalesce(sum(rv.qty), 0) from inv_reservations rv
	join projects rp on rp.id = rv.project_id
	where rp.group_id = ? and rv.part_number = ? and rv.status = 'active')`

func onHand(ctx context.Context, q queryer, groupID, part, location string) (int64, error) {
	var n int64
	query := `select coalesce(sum(qty), 0) from inv_movements where group_id = ? and part_number = ?`
	args := []any{groupID, part}
	if location != "" {
		query += ` and location = ?`
		args = append(args, location)
	}
	err := q.QueryRowContext(ctx, query, args...).Scan(&n)
	return n, err
}

// available = on hand (all locations) − active reservations of the group.
func available(ctx context.Context, q queryer, groupID, part string) (int64, int64, error) {
	var total, reserved int64
	err := q.QueryRowContext(ctx, `
		select (select coalesce(sum(qty), 0) from inv_movements where group_id = ? and part_number = ?), `+reservedIn,
		groupID, part, groupID, part).Scan(&total, &reserved)
	return total, reserved, err
}

// GET /v1/groups/{gid}/stock?part= — on hand per location, reserved and
// available per part.
func (s *Server) handleListStock(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.invGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	query := `
		select part_number, location, sum(qty) from inv_movements where group_id = ?`
	args := []any{access.ID}
	if part := strings.TrimSpace(r.URL.Query().Get("part")); part != "" {
		query += ` and part_number = ?`
		args = append(args, part)
	}
	query += ` group by part_number, location having sum(qty) <> 0 order by part_number, location`
	rows, err := s.store.db.QueryContext(r.Context(), query, args...)
	if err != nil {
		writeError(w, err)
		return
	}
	type entry struct {
		Part      string           `json:"part_number"`
		OnHand    int64            `json:"on_hand"`
		Reserved  int64            `json:"reserved"`
		Available int64            `json:"available"`
		Locations []map[string]any `json:"locations"`
	}
	byPart := map[string]*entry{}
	order := []string{}
	for rows.Next() {
		var part, location string
		var qty int64
		if err := rows.Scan(&part, &location, &qty); err != nil {
			rows.Close()
			writeError(w, err)
			return
		}
		e, ok := byPart[part]
		if !ok {
			e = &entry{Part: part, Locations: []map[string]any{}}
			byPart[part] = e
			order = append(order, part)
		}
		e.OnHand += qty
		e.Locations = append(e.Locations, map[string]any{"location": location, "on_hand": qty})
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		writeError(w, err)
		return
	}
	// Reserved parts with no stock at all still show (a shortage).
	// A private project's reservations are its own business: a caller who
	// cannot see the project does not see what it holds either (the API
	// still enforces the real availability when they reserve).
	scope := scopeOf(access)
	resQuery := `
		select rv.part_number, sum(rv.qty) from inv_reservations rv join projects p on p.id = rv.project_id
		where p.group_id = ? and rv.status = 'active'`
	resArgs := []any{access.ID}
	if !scope.SeesPrivate {
		resQuery += ` and rv.project_id not in (` + hiddenProjects + `)`
		resArgs = append(resArgs, scope.UID)
	}
	resRows, err := s.store.db.QueryContext(r.Context(), resQuery+` group by rv.part_number`, resArgs...)
	if err != nil {
		writeError(w, err)
		return
	}
	for resRows.Next() {
		var part string
		var qty int64
		if err := resRows.Scan(&part, &qty); err != nil {
			resRows.Close()
			writeError(w, err)
			return
		}
		e, ok := byPart[part]
		if !ok {
			if p := strings.TrimSpace(r.URL.Query().Get("part")); p != "" && p != part {
				continue
			}
			e = &entry{Part: part, Locations: []map[string]any{}}
			byPart[part] = e
			order = append(order, part)
		}
		e.Reserved = qty
	}
	resRows.Close()
	out := make([]*entry, 0, len(order))
	for _, part := range order {
		e := byPart[part]
		e.Available = e.OnHand - e.Reserved
		out = append(out, e)
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"stock":      out,
		"can_move":   access.can(CapMoveInventory),
		"can_adjust": access.can(CapManageVendors),
	})
}

// GET /v1/groups/{gid}/stock/movements?part= — the latest movements. The
// project of a movement in a private project the caller cannot see is
// left out.
func (s *Server) handleListMovements(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.invGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	scope := scopeOf(access)
	query := `
		select m.id, m.part_number, m.location, m.qty, m.kind, m.project_id, m.po_id, m.note, m.at,
		       (select coalesce(nullif(u.display_name, ''), u.uid) from users u where u.uid = m.by_uid)
		from inv_movements m where m.group_id = ?`
	args := []any{access.ID}
	if !scope.SeesPrivate {
		// A private project's receipts and issues stay out of the log for
		// those who cannot see it (part, qty, note and who would tell).
		query += ` and (m.project_id is null or m.project_id not in (` + hiddenProjects + `))`
		args = append(args, scope.UID)
	}
	if part := strings.TrimSpace(r.URL.Query().Get("part")); part != "" {
		query += ` and m.part_number = ?`
		args = append(args, part)
	}
	query += fmt.Sprintf(` order by m.rowid desc limit %d`, movementListLimit)
	rows, err := s.store.db.QueryContext(r.Context(), query, args...)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	out := make([]map[string]any, 0)
	for rows.Next() {
		var id, part, location, kind, at string
		var qty int64
		var project, po, note, by *string
		if err := rows.Scan(&id, &part, &location, &qty, &kind, &project, &po, &note, &at, &by); err != nil {
			writeError(w, err)
			return
		}
		out = append(out, map[string]any{
			"id": id, "part_number": part, "location": location, "qty": qty, "kind": kind,
			"project_id": project, "po_id": po, "note": note, "at": at, "by": by,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"movements": out})
}

type movementRequest struct {
	PartNumber *string `json:"part_number"`
	Location   *string `json:"location"`
	ToLocation *string `json:"to_location"`
	Qty        int64   `json:"qty"`
	Kind       string  `json:"kind"`
	Note       *string `json:"note"`
}

func cleanLocation(v *string) (string, error) {
	if v == nil || strings.TrimSpace(*v) == "" {
		return defaultLocation, nil
	}
	l := strings.TrimSpace(*v)
	if tooLong(l, 40) {
		return "", badRequest("invalid_location", "اسم المكان أطول من 40 حرف.")
	}
	return l, nil
}

// POST /v1/groups/{gid}/stock/movements — receive / issue / adjust /
// transfer by hand.
//
//   - receive, issue: inventory.move (the technician too); qty > 0;
//   - adjust (a count correction, ±): vendors.manage (procurement, managers);
//   - transfer between locations: inventory.move.
//
// Stock never goes below zero at a location, and an issue never takes
// units another project reserved.
func (s *Server) handleCreateMovement(w http.ResponseWriter, r *http.Request) {
	caller, _, access, err := s.invGroup(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapMoveInventory); err != nil {
		writeError(w, err)
		return
	}
	var body movementRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	part, err := requiredText(body.PartNumber, 64, "invalid_part_number", "رقم القطعة")
	if err != nil {
		writeError(w, err)
		return
	}
	location, err := cleanLocation(body.Location)
	if err != nil {
		writeError(w, err)
		return
	}
	note, err := optionalText(body.Note, 500, "note_too_long", "الملاحظة")
	if err != nil {
		writeError(w, err)
		return
	}
	if body.Qty == 0 || body.Qty > maxMovementQty || body.Qty < -maxMovementQty {
		writeError(w, badRequest("invalid_quantity", "الكمية غير صحيحة."))
		return
	}
	switch body.Kind {
	case "receive", "issue", "transfer":
		if body.Qty < 0 {
			writeError(w, badRequest("invalid_quantity", "الكمية لازم تكون موجبة."))
			return
		}
	case "adjust":
		if err := access.require(CapManageVendors); err != nil {
			writeError(w, err)
			return
		}
		if note == nil {
			writeError(w, badRequest("note_required", "اكتب سبب التسوية."))
			return
		}
	default:
		writeError(w, badRequest("invalid_kind", "النوع لازم يكون receive أو issue أو adjust أو transfer."))
		return
	}

	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	now := nowString()
	insert := func(loc string, qty int64, kind string) error {
		_, err := tx.ExecContext(r.Context(), `
			insert into inv_movements (id, group_id, part_number, location, qty, kind, note, by_uid, at)
			values (?, ?, ?, ?, ?, ?, ?, ?, ?)`, newID(), access.ID, part, loc, qty, kind, note, caller.UID, now)
		return err
	}
	out := body.Qty
	if body.Kind == "issue" || body.Kind == "transfer" {
		out = -body.Qty
	}
	if out < 0 {
		here, err := onHand(r.Context(), tx, access.ID, part, location)
		if err != nil {
			writeError(w, err)
			return
		}
		if here+out < 0 {
			writeError(w, conflict("insufficient_stock",
				fmt.Sprintf("الرصيد في %s هو %d بس.", location, here)))
			return
		}
		if body.Kind != "transfer" {
			total, reserved, err := available(r.Context(), tx, access.ID, part)
			if err != nil {
				writeError(w, err)
				return
			}
			if total+out < reserved {
				writeError(w, conflict("stock_reserved", fmt.Sprintf(
					"الكمية دي محجوزة لمشاريع (المتاح %d). اصرفها من الـ build اللي حاجزها.", total-reserved)))
				return
			}
		}
	}
	if body.Kind == "transfer" {
		to, err := cleanLocation(body.ToLocation)
		if err != nil {
			writeError(w, err)
			return
		}
		if to == location {
			writeError(w, badRequest("same_location", "المكان الجديد زي القديم."))
			return
		}
		if err := insert(location, -body.Qty, "transfer"); err != nil {
			writeError(w, err)
			return
		}
		if err := insert(to, body.Qty, "transfer"); err != nil {
			writeError(w, err)
			return
		}
	} else if err := insert(location, out, body.Kind); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"ok": true})
}

// --- project level: reservations and issue ---------------------------------------

// GET .../hw/reservations
func (s *Server) handleListReservations(w http.ResponseWriter, r *http.Request, h *hwContext) {
	rows, err := s.store.db.QueryContext(r.Context(), `
		select rv.id, rv.part_number, rv.qty, rv.status, rv.build_id, b.name, rv.po_id, rv.created_at
		from inv_reservations rv left join hw_builds b on b.id = rv.build_id
		where rv.project_id = ? order by rv.status, rv.created_at desc`, h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	out := make([]map[string]any, 0)
	for rows.Next() {
		var id, part, status, at string
		var qty int64
		var build, buildName, po *string
		if err := rows.Scan(&id, &part, &qty, &status, &build, &buildName, &po, &at); err != nil {
			writeError(w, err)
			return
		}
		out = append(out, map[string]any{
			"id": id, "part_number": part, "qty": qty, "status": status, "build_id": build,
			"build_name": buildName, "po_id": po, "created_at": at,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"reservations": out})
}

// projectGroup: the group of the hardware project (stock lives there).
func (h *hwContext) group() string { return h.access.ID }

// POST .../hw/reservations — reserve available stock for a build.
func (s *Server) handleCreateReservation(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapManageBuilds); err != nil {
		writeError(w, err)
		return
	}
	var body struct {
		BuildID    *string `json:"build_id"`
		PartNumber *string `json:"part_number"`
		Qty        int64   `json:"qty"`
	}
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	part, err := requiredText(body.PartNumber, 64, "invalid_part_number", "رقم القطعة")
	if err != nil {
		writeError(w, err)
		return
	}
	if body.Qty < 1 || body.Qty > maxMovementQty {
		writeError(w, badRequest("invalid_quantity", "الكمية غير صحيحة."))
		return
	}
	var build any
	if body.BuildID != nil && *body.BuildID != "" {
		if err := s.requireOpenBuild(r, h, *body.BuildID); err != nil {
			writeError(w, err)
			return
		}
		build = *body.BuildID
	}
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	total, reserved, err := available(r.Context(), tx, h.group(), part)
	if err != nil {
		writeError(w, err)
		return
	}
	if total-reserved < body.Qty {
		writeError(w, conflict("insufficient_stock", "المتاح من "+part+" مش كفاية للحجز ده."))
		return
	}
	now := nowString()
	if _, err := tx.ExecContext(r.Context(), `
		insert into inv_reservations (id, project_id, build_id, part_number, qty, created_by, created_at, updated_at)
		values (?, ?, ?, ?, ?, ?, ?, ?)`, newID(), h.project, build, part, body.Qty, h.caller.UID, now, now); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.handleListReservations(w, r, h)
}

// DELETE .../hw/reservations/{rsid} — give the units back.
func (s *Server) handleReleaseReservation(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapManageBuilds); err != nil {
		writeError(w, err)
		return
	}
	result, err := s.store.db.ExecContext(r.Context(), `
		update inv_reservations set status = 'released', updated_at = ?
		where id = ? and project_id = ? and status = 'active'`, nowString(), r.PathValue("rsid"), h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	if n, _ := result.RowsAffected(); n == 0 {
		writeError(w, notFound("reservation_not_found", "الحجز مش موجود أو اتصرف."))
		return
	}
	s.handleListReservations(w, r, h)
}

// POST .../hw/builds/{bid}/issue — the build starts assembly: every active
// reservation of it is issued from stock (largest location first) in one
// transaction. Not enough on the shelf = nothing moves.
func (s *Server) handleIssueBuild(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.requireAny(CapMoveInventory, CapManageBuilds); err != nil {
		writeError(w, err)
		return
	}
	bid := r.PathValue("bid")
	if err := s.requireOpenBuild(r, h, bid); err != nil {
		writeError(w, err)
		return
	}
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	rows, err := tx.QueryContext(r.Context(), `
		select id, part_number, qty from inv_reservations
		where build_id = ? and project_id = ? and status = 'active'`, bid, h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	type res struct {
		id, part string
		qty      int64
	}
	list := []res{}
	for rows.Next() {
		var x res
		if err := rows.Scan(&x.id, &x.part, &x.qty); err != nil {
			rows.Close()
			writeError(w, err)
			return
		}
		list = append(list, x)
	}
	rows.Close()
	if len(list) == 0 {
		writeError(w, conflict("nothing_reserved", "مفيش قطع محجوزة للـ build ده."))
		return
	}
	now := nowString()
	issued := 0
	for _, x := range list {
		locRows, err := tx.QueryContext(r.Context(), `
			select location, sum(qty) from inv_movements where group_id = ? and part_number = ?
			group by location having sum(qty) > 0 order by sum(qty) desc`, h.group(), x.part)
		if err != nil {
			writeError(w, err)
			return
		}
		type loc struct {
			name string
			qty  int64
		}
		locs := []loc{}
		for locRows.Next() {
			var l loc
			if err := locRows.Scan(&l.name, &l.qty); err != nil {
				locRows.Close()
				writeError(w, err)
				return
			}
			locs = append(locs, l)
		}
		locRows.Close()
		need := x.qty
		for _, l := range locs {
			if need == 0 {
				break
			}
			take := l.qty
			if take > need {
				take = need
			}
			if _, err := tx.ExecContext(r.Context(), `
				insert into inv_movements (id, group_id, part_number, location, qty, kind, project_id, build_id,
				                           by_uid, at)
				values (?, ?, ?, ?, ?, 'issue', ?, ?, ?, ?)`,
				newID(), h.group(), x.part, l.name, -take, h.project, bid, h.caller.UID, now); err != nil {
				writeError(w, err)
				return
			}
			need -= take
		}
		if need > 0 {
			writeError(w, conflict("insufficient_stock", fmt.Sprintf(
				"%s: الرصيد على الرف أقل من المحجوز بـ %d. سجّل الاستلام أو اعمل تسوية.", x.part, need)))
			return
		}
		if _, err := tx.ExecContext(r.Context(),
			`update inv_reservations set status = 'issued', updated_at = ? where id = ?`, now, x.id); err != nil {
			writeError(w, err)
			return
		}
		issued++
	}
	if _, err := tx.ExecContext(r.Context(), `
		update hw_builds set status = 'assembling', updated_at = ?
		where id = ? and status in ('planned', 'parts_ordered')`, now, bid); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"issued": issued})
}

// requireOpenBuild: parts are reserved for and issued to a build that has not
// started assembly (planned / parts ordered) — not one that is done or
// cancelled.
func (s *Server) requireOpenBuild(r *http.Request, h *hwContext, buildID string) error {
	var status string
	err := s.store.db.QueryRowContext(r.Context(),
		`select status from hw_builds where id = ? and project_id = ?`, buildID, h.project).Scan(&status)
	if errors.Is(err, sql.ErrNoRows) {
		return notFound("build_not_found", "الـ build مش موجود في المشروع.")
	}
	if err != nil {
		return err
	}
	if status != "planned" && status != "parts_ordered" {
		return conflict("build_not_open", "الحجز والصرف لـ build لسه مابدأش التجميع بس.")
	}
	return nil
}

// --- demand ------------------------------------------------------------------------

// GET .../hw/demand — what the open builds need (BOM lines × build
// quantity), what this project reserved, what the group has available, the
// shortage, and "order now" when the lead time no longer fits before the
// build date.
func (s *Server) handleDemand(w http.ResponseWriter, r *http.Request, h *hwContext) {
	rows, err := s.store.db.QueryContext(r.Context(), `
		select p.part_number, sum(l.quantity * b.quantity), min(b.planned_at),
		       max(v.default_lead_days)
		from hw_builds b
		join hw_bom_lines l on l.bom_rev_id = b.bom_rev_id
		join hw_parts p on p.id = l.part_id
		left join inv_vendors v on v.group_id = ? and lower(v.name) = lower(p.vendor) and v.archived = 0
		where b.project_id = ? and b.status in ('planned', 'parts_ordered')
		group by p.part_number order by p.part_number`, h.group(), h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	type line struct {
		part    string
		need    int64
		planned *string
		lead    *int
	}
	lines := []line{}
	for rows.Next() {
		var l line
		if err := rows.Scan(&l.part, &l.need, &l.planned, &l.lead); err != nil {
			rows.Close()
			writeError(w, err)
			return
		}
		lines = append(lines, l)
	}
	rows.Close()
	today := time.Now().UTC()
	out := make([]map[string]any, 0, len(lines))
	for _, l := range lines {
		var mine, onOrder int64
		if err := s.store.db.QueryRowContext(r.Context(), `
			select
			  (select coalesce(sum(qty), 0) from inv_reservations
			    where project_id = ? and part_number = ? and status = 'active'),
			  (select coalesce(sum(pl.qty - pl.received_qty), 0) from inv_po_lines pl join inv_pos po on po.id = pl.po_id
			    where po.project_id = ? and pl.part_number = ?
			      and po.status in ('pending_approval', 'ordered', 'partially_received'))`,
			h.project, l.part, h.project, l.part).Scan(&mine, &onOrder); err != nil {
			writeError(w, err)
			return
		}
		total, reserved, err := available(r.Context(), s.store.db, h.group(), l.part)
		if err != nil {
			writeError(w, err)
			return
		}
		free := total - reserved
		shortage := l.need - mine - onOrder - max(free, 0)
		if shortage < 0 {
			shortage = 0
		}
		orderNow := false
		var orderBy any
		if l.planned != nil && l.lead != nil {
			if when, err := time.Parse("2006-01-02", strings.SplitN(*l.planned, "T", 2)[0]); err == nil {
				deadline := when.AddDate(0, 0, -*l.lead)
				orderBy = deadline.Format("2006-01-02")
				orderNow = shortage > 0 && !deadline.After(today)
			}
		}
		out = append(out, map[string]any{
			"part_number": l.part, "needed": l.need, "reserved": mine, "on_order": onOrder,
			"available": free, "shortage": shortage, "lead_days": l.lead, "build_date": l.planned,
			"order_by": orderBy, "order_now": orderNow,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"demand": out})
}
