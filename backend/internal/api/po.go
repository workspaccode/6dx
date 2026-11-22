package api

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"strings"
)

// Purchase orders — project level (§7.5).
//
//	draft → (submit) → pending_approval → (approve) → ordered
//	                 ↘ ordered (total under the group's threshold)
//	ordered → partially_received → received → closed     · cancelled
//
// Engineers (po.request) open a draft; procurement / managers (po.create)
// complete and submit it. A PO at or above the group's threshold waits for
// po.approve, never from whoever wrote or submitted it. Receiving
// (inventory.move) adds stock and reserves it for the project — for the
// PO's build when it has one.

func poCode(n int) string { return fmt.Sprintf("PO-%03d", n) }

func (s *store) poPayload(ctx context.Context, q queryer, projectID, poID string, prices bool) (map[string]any, error) {
	var id, vendorID, vendorName, status, currency, created, updated string
	var number int
	var build, buildName, note, createdBy, submittedBy, approvedBy, orderedAt, expectedAt *string
	err := q.QueryRowContext(ctx, `
		select po.id, po.number, po.vendor_id, v.name, po.build_id, b.name, po.status, po.currency, po.note,
		       po.created_by, po.submitted_by, po.approved_by, po.ordered_at, po.expected_at,
		       po.created_at, po.updated_at
		from inv_pos po join inv_vendors v on v.id = po.vendor_id
		left join hw_builds b on b.id = po.build_id
		where po.id = ? and po.project_id = ?`, poID, projectID,
	).Scan(&id, &number, &vendorID, &vendorName, &build, &buildName, &status, &currency, &note,
		&createdBy, &submittedBy, &approvedBy, &orderedAt, &expectedAt, &created, &updated)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, notFound("po_not_found", "أمر الشراء مش موجود في المشروع.")
	}
	if err != nil {
		return nil, err
	}
	rows, err := q.QueryContext(ctx, `
		select part_number, qty, unit_cost_cents, received_qty from inv_po_lines
		where po_id = ? order by part_number`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	lines := make([]map[string]any, 0)
	var total int64
	for rows.Next() {
		var part string
		var qty, cost, received int64
		if err := rows.Scan(&part, &qty, &cost, &received); err != nil {
			return nil, err
		}
		line := map[string]any{"part_number": part, "qty": qty, "received_qty": received}
		if prices {
			line["unit_cost_cents"] = cost
		}
		total += qty * cost
		lines = append(lines, line)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	out := map[string]any{
		"id": id, "number": number, "code": poCode(number), "vendor_id": vendorID, "vendor": vendorName,
		"build_id": build, "build_name": buildName, "status": status, "currency": currency, "note": note,
		"created_by": createdBy, "submitted_by": submittedBy, "approved_by": approvedBy,
		"ordered_at": orderedAt, "expected_at": expectedAt, "created_at": created, "updated_at": updated,
		"lines": lines,
	}
	if prices {
		out["total_cents"] = total
	}
	return out, nil
}

func poTotal(ctx context.Context, q queryer, poID string) (int64, error) {
	var total int64
	err := q.QueryRowContext(ctx,
		`select coalesce(sum(qty * unit_cost_cents), 0) from inv_po_lines where po_id = ?`, poID).Scan(&total)
	return total, err
}

func (s *Server) writePO(w http.ResponseWriter, r *http.Request, h *hwContext, poID string, status int) {
	po, err := s.store.poPayload(r.Context(), s.store.db, h.project, poID, h.access.can(CapViewPrices))
	if err != nil {
		writeError(w, err)
		return
	}
	po["can_approve"] = s.poCanApprove(h, po)
	writeJSON(w, status, map[string]any{"po": po})
}

func (s *Server) poCanApprove(h *hwContext, po map[string]any) bool {
	if po["status"] != "pending_approval" || !h.access.can(CapApprovePO) {
		return false
	}
	for _, k := range []string{"created_by", "submitted_by"} {
		if who, _ := po[k].(*string); who != nil && *who == h.caller.UID {
			return false
		}
	}
	return true
}

// GET .../hw/pos
func (s *Server) handleListPOs(w http.ResponseWriter, r *http.Request, h *hwContext) {
	prices := h.access.can(CapViewPrices)
	rows, err := s.store.db.QueryContext(r.Context(), `
		select po.id, po.number, v.name, po.status, po.currency, po.expected_at, b.name,
		       (select coalesce(sum(qty * unit_cost_cents), 0) from inv_po_lines l where l.po_id = po.id),
		       (select count(*) from inv_po_lines l where l.po_id = po.id)
		from inv_pos po join inv_vendors v on v.id = po.vendor_id
		left join hw_builds b on b.id = po.build_id
		where po.project_id = ? order by po.number desc`, h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	out := make([]map[string]any, 0)
	for rows.Next() {
		var id, vendor, status, currency string
		var number, lines int
		var total int64
		var expected, build *string
		if err := rows.Scan(&id, &number, &vendor, &status, &currency, &expected, &build, &total, &lines); err != nil {
			writeError(w, err)
			return
		}
		po := map[string]any{
			"id": id, "number": number, "code": poCode(number), "vendor": vendor, "status": status,
			"currency": currency, "expected_at": expected, "build_name": build, "lines": lines,
		}
		if prices {
			po["total_cents"] = total
		}
		out = append(out, po)
	}
	writeJSON(w, http.StatusOK, map[string]any{"pos": out})
}

// GET .../hw/pos/{poid}
func (s *Server) handleGetPO(w http.ResponseWriter, r *http.Request, h *hwContext) {
	s.writePO(w, r, h, r.PathValue("poid"), http.StatusOK)
}

type poRequest struct {
	VendorID   string  `json:"vendor_id"`
	BuildID    *string `json:"build_id"`
	Note       *string `json:"note"`
	ExpectedAt *string `json:"expected_at"`
}

// POST .../hw/pos — a draft (po.request or po.create).
func (s *Server) handleCreatePO(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.requireAny(CapCreatePO, CapRequestPO); err != nil {
		writeError(w, err)
		return
	}
	var body poRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	note, err := optionalText(body.Note, 2000, "note_too_long", "الملاحظة")
	if err != nil {
		writeError(w, err)
		return
	}
	expected, err := optionalText(body.ExpectedAt, 40, "invalid_date", "التاريخ")
	if err != nil {
		writeError(w, err)
		return
	}
	var archived int
	err = s.store.db.QueryRowContext(r.Context(),
		`select archived from inv_vendors where id = ? and group_id = ?`, body.VendorID, h.group()).Scan(&archived)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("vendor_not_found", "المورّد مش موجود في المجموعة."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if archived == 1 {
		writeError(w, conflict("vendor_archived", "المورّد ده متأرشف."))
		return
	}
	var build any
	if body.BuildID != nil && *body.BuildID != "" {
		if err := s.store.hwOwned(r.Context(), s.store.db, "hw_builds", *body.BuildID, h.project, "build_not_found"); err != nil {
			writeError(w, err)
			return
		}
		build = *body.BuildID
	}
	st, err := invSettingsOf(r.Context(), s.store.db, h.group())
	if err != nil {
		writeError(w, err)
		return
	}
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	var next int
	if err := tx.QueryRowContext(r.Context(),
		`select coalesce(max(number), 0) + 1 from inv_pos where project_id = ?`, h.project).Scan(&next); err != nil {
		writeError(w, err)
		return
	}
	id, now := newID(), nowString()
	if _, err := tx.ExecContext(r.Context(), `
		insert into inv_pos (id, project_id, vendor_id, number, build_id, currency, note, expected_at,
		                     created_by, created_at, updated_at)
		values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		id, h.project, body.VendorID, next, build, st.Currency, note, expected, h.caller.UID, now, now); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.writePO(w, r, h, id, http.StatusCreated)
}

// poDraft loads a draft the caller may edit: its author (still holding a
// PO capability) or procurement (po.create).
func (s *Server) poDraft(r *http.Request, h *hwContext) (string, error) {
	if err := h.requireAny(CapCreatePO, CapRequestPO); err != nil {
		return "", err
	}
	var status string
	var author *string
	err := s.store.db.QueryRowContext(r.Context(),
		`select status, created_by from inv_pos where id = ? and project_id = ?`, r.PathValue("poid"), h.project,
	).Scan(&status, &author)
	if errors.Is(err, sql.ErrNoRows) {
		return "", notFound("po_not_found", "أمر الشراء مش موجود في المشروع.")
	}
	if err != nil {
		return "", err
	}
	if status != "draft" {
		return "", conflict("po_not_draft", "أمر الشراء اتقدّم ومش بيتعدّل.")
	}
	if (author == nil || *author != h.caller.UID) && !h.access.can(CapCreatePO) {
		return "", forbidden("missing_capability", "دورك مايسمحش بتعديل أمر الشراء ده.")
	}
	return r.PathValue("poid"), nil
}

// PUT .../hw/pos/{poid}/lines/{part}
func (s *Server) handleSetPOLine(w http.ResponseWriter, r *http.Request, h *hwContext) {
	poID, err := s.poDraft(r, h)
	if err != nil {
		writeError(w, err)
		return
	}
	var body struct {
		Qty           int64  `json:"qty"`
		UnitCostCents *int64 `json:"unit_cost_cents"`
	}
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	part := strings.TrimSpace(r.PathValue("part"))
	if part == "" || tooLong(part, 64) {
		writeError(w, badRequest("invalid_part_number", "رقم القطعة غير صحيح."))
		return
	}
	if body.Qty < 1 || body.Qty > maxMovementQty {
		writeError(w, badRequest("invalid_quantity", "الكمية غير صحيحة."))
		return
	}
	if body.UnitCostCents != nil {
		if !h.access.can(CapViewPrices) {
			writeError(w, forbidden("prices_hidden", "دورك مايشوفش الأسعار، فمايقدرش يحددها."))
			return
		}
		if *body.UnitCostCents < 0 || *body.UnitCostCents > 1_000_000_000 {
			writeError(w, badRequest("invalid_cost", "السعر غير صحيح."))
			return
		}
	}
	var count int
	if err := s.store.db.QueryRowContext(r.Context(),
		`select count(*) from inv_po_lines where po_id = ? and part_number <> ?`, poID, part).Scan(&count); err != nil {
		writeError(w, err)
		return
	}
	if count >= maxPOLines {
		writeError(w, conflict("po_line_limit", fmt.Sprintf("الحد الأقصى %d سطر في أمر الشراء.", maxPOLines)))
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into inv_po_lines (po_id, part_number, qty, unit_cost_cents) values (?, ?, ?, coalesce(?, 0))
		on conflict (po_id, part_number) do update set qty = excluded.qty,
		  unit_cost_cents = coalesce(?, inv_po_lines.unit_cost_cents)`,
		poID, part, body.Qty, body.UnitCostCents, body.UnitCostCents); err != nil {
		writeError(w, err)
		return
	}
	s.writePO(w, r, h, poID, http.StatusOK)
}

// DELETE .../hw/pos/{poid}/lines/{part}
func (s *Server) handleDeletePOLine(w http.ResponseWriter, r *http.Request, h *hwContext) {
	poID, err := s.poDraft(r, h)
	if err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(),
		`delete from inv_po_lines where po_id = ? and part_number = ?`, poID, r.PathValue("part")); err != nil {
		writeError(w, err)
		return
	}
	s.writePO(w, r, h, poID, http.StatusOK)
}

// POST .../hw/pos/{poid}/submit — po.create. Under the threshold it is
// ordered right away; at or above it waits for approval.
func (s *Server) handleSubmitPO(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapCreatePO); err != nil {
		writeError(w, err)
		return
	}
	poID, err := s.poDraft(r, h)
	if err != nil {
		writeError(w, err)
		return
	}
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	var lines int
	if err := tx.QueryRowContext(r.Context(),
		`select count(*) from inv_po_lines where po_id = ?`, poID).Scan(&lines); err != nil {
		writeError(w, err)
		return
	}
	if lines == 0 {
		writeError(w, conflict("po_empty", "أمر الشراء فاضي."))
		return
	}
	var unpriced int
	if err := tx.QueryRowContext(r.Context(),
		`select count(*) from inv_po_lines where po_id = ? and unit_cost_cents = 0`, poID).Scan(&unpriced); err != nil {
		writeError(w, err)
		return
	}
	if unpriced > 0 {
		writeError(w, conflict("po_unpriced", "في سطور من غير سعر. حدد السعر قبل التقديم."))
		return
	}
	total, err := poTotal(r.Context(), tx, poID)
	if err != nil {
		writeError(w, err)
		return
	}
	st, err := invSettingsOf(r.Context(), tx, h.group())
	if err != nil {
		writeError(w, err)
		return
	}
	now := nowString()
	next, orderedAt := "ordered", any(now)
	if total >= st.ThresholdCents {
		next, orderedAt = "pending_approval", nil
	}
	result, err := tx.ExecContext(r.Context(), `
		update inv_pos set status = ?, submitted_by = ?, ordered_at = ?, updated_at = ?
		where id = ? and status = 'draft'`, next, h.caller.UID, orderedAt, now, poID)
	if err != nil {
		writeError(w, err)
		return
	}
	if n, _ := result.RowsAffected(); n == 0 {
		writeError(w, conflict("po_changed", "أمر الشراء اتغيّر. حدّث الشاشة."))
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.writePO(w, r, h, poID, http.StatusOK)
}

// POST .../hw/pos/{poid}/approve — po.approve, not its author or submitter.
func (s *Server) handleApprovePO(w http.ResponseWriter, r *http.Request, h *hwContext) {
	po, err := s.store.poPayload(r.Context(), s.store.db, h.project, r.PathValue("poid"), false)
	if err != nil {
		writeError(w, err)
		return
	}
	if po["status"] != "pending_approval" {
		writeError(w, conflict("po_not_pending", "أمر الشراء مش مستني اعتماد."))
		return
	}
	if !s.poCanApprove(h, po) {
		writeError(w, forbidden("cannot_approve", "الاعتماد محتاج po.approve، واللي كتب أو قدّم الأمر مايعتمدوش."))
		return
	}
	now := nowString()
	result, err := s.store.db.ExecContext(r.Context(), `
		update inv_pos set status = 'ordered', approved_by = ?, ordered_at = ?, updated_at = ?
		where id = ? and status = 'pending_approval'`, h.caller.UID, now, now, po["id"])
	if err != nil {
		writeError(w, err)
		return
	}
	if n, _ := result.RowsAffected(); n == 0 {
		writeError(w, conflict("po_changed", "أمر الشراء اتغيّر. حدّث الشاشة."))
		return
	}
	s.writePO(w, r, h, po["id"].(string), http.StatusOK)
}

type receiveRequest struct {
	Location *string `json:"location"`
	Lines    []struct {
		PartNumber string `json:"part_number"`
		Qty        int64  `json:"qty"`
	} `json:"lines"`
}

// POST .../hw/pos/{poid}/receive — what arrived. Stock goes up and is
// reserved for this project (and the PO's build); the PO becomes
// partially received or received.
func (s *Server) handleReceivePO(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapMoveInventory); err != nil {
		writeError(w, err)
		return
	}
	var body receiveRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	location, err := cleanLocation(body.Location)
	if err != nil {
		writeError(w, err)
		return
	}
	if len(body.Lines) == 0 || len(body.Lines) > maxPOLines {
		writeError(w, badRequest("invalid_lines", "حدد اللي وصل."))
		return
	}
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	var poID, status string
	var build *string
	err = tx.QueryRowContext(r.Context(),
		`select id, status, build_id from inv_pos where id = ? and project_id = ?`, r.PathValue("poid"), h.project,
	).Scan(&poID, &status, &build)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("po_not_found", "أمر الشراء مش موجود في المشروع."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if status != "ordered" && status != "partially_received" {
		writeError(w, conflict("po_not_ordered", "الاستلام بيكون لأمر شراء اتطلب بس."))
		return
	}
	now := nowString()
	seen := map[string]bool{}
	for _, line := range body.Lines {
		part := strings.TrimSpace(line.PartNumber)
		if seen[part] {
			writeError(w, badRequest("duplicate_line", "القطعة "+part+" متكررة."))
			return
		}
		seen[part] = true
		var qty, received int64
		err := tx.QueryRowContext(r.Context(),
			`select qty, received_qty from inv_po_lines where po_id = ? and part_number = ?`, poID, part,
		).Scan(&qty, &received)
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, badRequest("not_on_po", "القطعة "+part+" مش في أمر الشراء."))
			return
		}
		if err != nil {
			writeError(w, err)
			return
		}
		if line.Qty < 1 || received+line.Qty > qty {
			writeError(w, conflict("over_receipt", fmt.Sprintf(
				"%s: المطلوب %d، واتستلم %d قبل كده.", part, qty, received)))
			return
		}
		if _, err := tx.ExecContext(r.Context(),
			`update inv_po_lines set received_qty = received_qty + ? where po_id = ? and part_number = ?`,
			line.Qty, poID, part); err != nil {
			writeError(w, err)
			return
		}
		if _, err := tx.ExecContext(r.Context(), `
			insert into inv_movements (id, group_id, part_number, location, qty, kind, project_id, build_id,
			                           po_id, by_uid, at)
			values (?, ?, ?, ?, ?, 'receive', ?, ?, ?, ?, ?)`,
			newID(), h.group(), part, location, line.Qty, h.project, build, poID, h.caller.UID, now); err != nil {
			writeError(w, err)
			return
		}
		if _, err := tx.ExecContext(r.Context(), `
			insert into inv_reservations (id, project_id, build_id, part_number, qty, po_id, created_by,
			                              created_at, updated_at)
			values (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
			newID(), h.project, build, part, line.Qty, poID, h.caller.UID, now, now); err != nil {
			writeError(w, err)
			return
		}
	}
	var open int64
	if err := tx.QueryRowContext(r.Context(),
		`select coalesce(sum(qty - received_qty), 0) from inv_po_lines where po_id = ?`, poID).Scan(&open); err != nil {
		writeError(w, err)
		return
	}
	next := "partially_received"
	if open == 0 {
		next = "received"
	}
	if _, err := tx.ExecContext(r.Context(),
		`update inv_pos set status = ?, updated_at = ? where id = ?`, next, now, poID); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.writePO(w, r, h, poID, http.StatusOK)
}

// POST .../hw/pos/{poid}/close | cancel — po.create. Close ends a PO that
// received something (the rest will not come); cancel drops one that
// received nothing.
func (s *Server) handlePOStatus(to string) func(http.ResponseWriter, *http.Request, *hwContext) {
	return func(w http.ResponseWriter, r *http.Request, h *hwContext) {
		if err := h.require(CapCreatePO); err != nil {
			writeError(w, err)
			return
		}
		from := map[string]string{
			"closed":    `('partially_received', 'received')`,
			"cancelled": `('draft', 'pending_approval', 'ordered')`,
		}[to]
		result, err := s.store.db.ExecContext(r.Context(), `
			update inv_pos set status = ?, updated_at = ?
			where id = ? and project_id = ? and status in `+from,
			to, nowString(), r.PathValue("poid"), h.project)
		if err != nil {
			writeError(w, err)
			return
		}
		if n, _ := result.RowsAffected(); n == 0 {
			writeError(w, conflict("invalid_po_transition", "مينفعش من الحالة الحالية لأمر الشراء."))
			return
		}
		s.writePO(w, r, h, r.PathValue("poid"), http.StatusOK)
	}
}
