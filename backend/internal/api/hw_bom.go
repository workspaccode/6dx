package api

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"strings"
)

// Parts and the single-level BOM. A part number + revision is unique in a
// project (a form/fit/function change is a new part number, a small change a
// new revision). A BOM revision is a draft until it is released; a released
// revision is a fixed snapshot (the database refuses to touch its lines).

const maxPartsPerProject = 5000

var partLifecycles = []string{"draft", "prototype", "production", "obsolete"}

type partRequest struct {
	PartNumber    *string `json:"part_number"`
	Revision      *string `json:"revision"`
	Description   *string `json:"description"`
	Category      *string `json:"category"`
	Lifecycle     *string `json:"lifecycle"`
	MPN           *string `json:"mpn"`
	Vendor        *string `json:"vendor"`
	UnitCostCents *int64  `json:"unit_cost_cents"`
}

func scanPart(row interface{ Scan(...any) error }, prices bool) (map[string]any, error) {
	var id, number, revision, description, lifecycle, updated string
	var category, mpn, vendor *string
	var cost *int64
	if err := row.Scan(&id, &number, &revision, &description, &category, &lifecycle,
		&mpn, &vendor, &cost, &updated); err != nil {
		return nil, err
	}
	part := map[string]any{
		"id": id, "part_number": number, "revision": revision, "description": description,
		"category": category, "lifecycle": lifecycle, "mpn": mpn, "vendor": vendor,
		"updated_at": updated,
	}
	// Prices are for whoever may see them (§7.5): a technician or the
	// client never gets the field.
	if prices {
		part["unit_cost_cents"] = cost
	}
	return part, nil
}

const partColumns = `id, part_number, revision, description, category, lifecycle, mpn, vendor,
	unit_cost_cents, updated_at`

// GET .../hw/parts
func (s *Server) handleListParts(w http.ResponseWriter, r *http.Request, h *hwContext) {
	rows, err := s.store.db.QueryContext(r.Context(),
		`select `+partColumns+` from hw_parts where project_id = ? order by part_number, revision`,
		h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	prices := h.access.can(CapViewPrices)
	parts := make([]map[string]any, 0)
	for rows.Next() {
		part, err := scanPart(rows, prices)
		if err != nil {
			writeError(w, err)
			return
		}
		parts = append(parts, part)
	}
	if err := rows.Err(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"parts": parts, "prices": prices})
}

func (b *partRequest) clean(create bool) error {
	var err error
	if create || b.PartNumber != nil {
		var v string
		if v, err = requiredText(b.PartNumber, 64, "invalid_part_number", "رقم القطعة"); err != nil {
			return err
		}
		b.PartNumber = &v
	}
	if create || b.Description != nil {
		var v string
		if v, err = requiredText(b.Description, 200, "invalid_description", "وصف القطعة"); err != nil {
			return err
		}
		b.Description = &v
	}
	if b.Revision != nil || create {
		rev := "A"
		if b.Revision != nil && strings.TrimSpace(*b.Revision) != "" {
			rev = strings.ToUpper(strings.TrimSpace(*b.Revision))
		}
		if tooLong(rev, 8) {
			return badRequest("invalid_revision", "الـ revision أطول من 8 حروف.")
		}
		b.Revision = &rev
	}
	if b.Lifecycle != nil && !oneOf(*b.Lifecycle, partLifecycles...) {
		return badRequest("invalid_lifecycle", "حالة القطعة غير معروفة.")
	}
	if b.Category, err = optionalText(b.Category, 40, "category_too_long", "الفئة"); err != nil {
		return err
	}
	if b.MPN, err = optionalText(b.MPN, 80, "mpn_too_long", "الـ MPN"); err != nil {
		return err
	}
	if b.Vendor, err = optionalText(b.Vendor, 80, "vendor_too_long", "المورّد"); err != nil {
		return err
	}
	if b.UnitCostCents != nil && (*b.UnitCostCents < 0 || *b.UnitCostCents > 1_000_000_000) {
		return badRequest("invalid_cost", "التكلفة غير صحيحة.")
	}
	return nil
}

// POST .../hw/parts
func (s *Server) handleCreatePart(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapEditBOM); err != nil {
		writeError(w, err)
		return
	}
	var body partRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if err := body.clean(true); err != nil {
		writeError(w, err)
		return
	}
	if body.UnitCostCents != nil && !h.access.can(CapViewPrices) {
		writeError(w, forbidden("prices_hidden", "دورك مايشوفش الأسعار، فمايقدرش يحددها."))
		return
	}
	var count int
	if err := s.store.db.QueryRowContext(r.Context(),
		`select count(*) from hw_parts where project_id = ?`, h.project).Scan(&count); err != nil {
		writeError(w, err)
		return
	}
	if count >= maxPartsPerProject {
		writeError(w, conflict("part_limit_reached", fmt.Sprintf("الحد الأقصى %d قطعة في المشروع.", maxPartsPerProject)))
		return
	}
	lifecycle := "draft"
	if body.Lifecycle != nil {
		lifecycle = *body.Lifecycle
	}
	id, now := newID(), nowString()
	_, err := s.store.db.ExecContext(r.Context(), `
		insert into hw_parts (id, project_id, part_number, revision, description, category,
		                      lifecycle, mpn, vendor, unit_cost_cents, created_at, updated_at)
		values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		id, h.project, *body.PartNumber, *body.Revision, *body.Description, body.Category,
		lifecycle, body.MPN, body.Vendor, body.UnitCostCents, now, now)
	if err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			writeError(w, conflict("part_exists", "القطعة دي بنفس الـ revision موجودة."))
			return
		}
		writeError(w, err)
		return
	}
	part, err := scanPart(s.store.db.QueryRowContext(r.Context(),
		`select `+partColumns+` from hw_parts where id = ?`, id), h.access.can(CapViewPrices))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"part": part})
}

// PATCH .../hw/parts/{partid} — the descriptive fields. The number and the
// revision identify the part; a new revision is a new part.
func (s *Server) handleUpdatePart(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapEditBOM); err != nil {
		writeError(w, err)
		return
	}
	var body partRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if body.PartNumber != nil || body.Revision != nil {
		writeError(w, badRequest("part_identity_fixed", "رقم القطعة والـ revision مش بيتغيروا. اعمل revision جديد."))
		return
	}
	// "" clears a field; clean() turns it into nil, so remember it first.
	rawCleared := []bool{cleared(body.Category), cleared(body.MPN), cleared(body.Vendor)}
	if err := body.clean(false); err != nil {
		writeError(w, err)
		return
	}
	if body.UnitCostCents != nil && !h.access.can(CapViewPrices) {
		writeError(w, forbidden("prices_hidden", "دورك مايشوفش الأسعار، فمايقدرش يحددها."))
		return
	}
	id := r.PathValue("partid")
	// An assembly in production keeps its structure: going back to draft
	// would reopen its children. A changed assembly is a new revision.
	if body.Lifecycle != nil && (*body.Lifecycle == "draft" || *body.Lifecycle == "prototype") {
		var current string
		var assembly bool
		if err := s.store.db.QueryRowContext(r.Context(), `
			select lifecycle, exists (select 1 from hw_part_children c where c.parent_part_id = hw_parts.id)
			from hw_parts where id = ? and project_id = ?`, id, h.project).Scan(&current, &assembly); err == nil &&
			assembly && (current == "production" || current == "obsolete") {
			writeError(w, conflict("assembly_frozen", "الـ assembly في الإنتاج مش بيرجع draft. اعمل revision جديد."))
			return
		}
	}
	result, err := s.store.db.ExecContext(r.Context(), `
		update hw_parts set description = coalesce(?, description),
		       category = case when ? then null else coalesce(?, category) end,
		       lifecycle = coalesce(?, lifecycle),
		       mpn = case when ? then null else coalesce(?, mpn) end,
		       vendor = case when ? then null else coalesce(?, vendor) end,
		       unit_cost_cents = coalesce(?, unit_cost_cents), updated_at = ?
		where id = ? and project_id = ?`,
		body.Description, rawCleared[0], body.Category, body.Lifecycle, rawCleared[1], body.MPN,
		rawCleared[2], body.Vendor, body.UnitCostCents, nowString(), id, h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	if n, _ := result.RowsAffected(); n == 0 {
		writeError(w, notFound("part_not_found", "القطعة مش موجودة في المشروع."))
		return
	}
	part, err := scanPart(s.store.db.QueryRowContext(r.Context(),
		`select `+partColumns+` from hw_parts where id = ?`, id), h.access.can(CapViewPrices))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"part": part})
}

// --- BOM ---------------------------------------------------------------------

// revLetter: 0 → A, 25 → Z, 26 → AA.
func revLetter(n int) string {
	out := ""
	for n >= 0 {
		out = string(rune('A'+n%26)) + out
		n = n/26 - 1
	}
	return out
}

// GET .../hw/bom — every revision, newest first.
func (s *Server) handleListBOM(w http.ResponseWriter, r *http.Request, h *hwContext) {
	rows, err := s.store.db.QueryContext(r.Context(), `
		select b.id, b.rev, b.status, b.note, b.eco_id, b.released_at, b.created_at,
		       (select count(*) from hw_bom_lines l where l.bom_rev_id = b.id),
		       (select coalesce(sum(l.quantity), 0) from hw_bom_lines l where l.bom_rev_id = b.id)
		from hw_bom_revs b where b.project_id = ?
		order by length(b.rev) desc, b.rev desc`, h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	revs := make([]map[string]any, 0)
	for rows.Next() {
		var id, rev, status, created string
		var note, eco, released *string
		var lines, qty int
		if err := rows.Scan(&id, &rev, &status, &note, &eco, &released, &created, &lines, &qty); err != nil {
			writeError(w, err)
			return
		}
		revs = append(revs, map[string]any{
			"id": id, "rev": rev, "status": status, "note": note, "eco_id": eco,
			"released_at": released, "created_at": created, "lines": lines, "quantity": qty,
		})
	}
	if err := rows.Err(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"revisions": revs})
}

func (s *store) bomRevision(ctx context.Context, projectID, revID string, prices bool) (map[string]any, error) {
	var rev, status string
	var note, eco, released *string
	err := s.db.QueryRowContext(ctx, `
		select rev, status, note, eco_id, released_at from hw_bom_revs where id = ? and project_id = ?`,
		revID, projectID).Scan(&rev, &status, &note, &eco, &released)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, notFound("bom_not_found", "الـ BOM revision مش موجود في المشروع.")
	}
	if err != nil {
		return nil, err
	}
	rows, err := s.db.QueryContext(ctx, `
		select l.part_id, l.quantity, l.ref_designators, p.part_number, p.revision, p.description,
		       p.lifecycle, p.unit_cost_cents,
		       exists (select 1 from hw_part_children x where x.parent_part_id = l.part_id)
		from hw_bom_lines l join hw_parts p on p.id = l.part_id
		where l.bom_rev_id = ? order by p.part_number`, revID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	lines := make([]map[string]any, 0)
	for rows.Next() {
		var partID, number, partRev, description, lifecycle string
		var qty int64
		var refs *string
		var cost *int64
		var assembly bool
		if err := rows.Scan(&partID, &qty, &refs, &number, &partRev, &description, &lifecycle, &cost, &assembly); err != nil {
			return nil, err
		}
		line := map[string]any{
			"part_id": partID, "quantity": qty, "ref_designators": refs, "part_number": number,
			"revision": partRev, "description": description, "lifecycle": lifecycle,
			"is_assembly": assembly,
		}
		if prices {
			line["unit_cost_cents"] = cost
		}
		lines = append(lines, line)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	rows.Close()
	// The cost of one unit: the leaves of the exploded tree (an assembly's
	// own price is its children's).
	var total *int64
	if prices {
		var sum float64
		var count int
		if err := s.db.QueryRowContext(ctx, explodeCTE+`
			select (select count(*) from ex),
			       coalesce(total(ex.qty * coalesce(p.unit_cost_cents, 0)), 0)
			from ex join hw_parts p on p.id = ex.part_id
			where not exists (select 1 from hw_part_children x where x.parent_part_id = ex.part_id)`,
			revID).Scan(&count, &sum); err != nil {
			return nil, err
		}
		// Too large to explode, or beyond int64: no number rather than a
		// wrong one.
		if count <= maxExplodedNodes && sum < 9e15 {
			t := int64(sum)
			total = &t
		}
	}
	out := map[string]any{
		"id": revID, "rev": rev, "status": status, "note": note, "eco_id": eco,
		"released_at": released, "lines": lines,
	}
	if prices {
		out["total_cost_cents"] = total
	}
	return out, nil
}

// GET .../hw/bom/{rid}
func (s *Server) handleGetBOM(w http.ResponseWriter, r *http.Request, h *hwContext) {
	bom, err := s.store.bomRevision(r.Context(), h.project, r.PathValue("rid"), h.access.can(CapViewPrices))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"bom": bom})
}

// newBOMDraft inserts the next revision as a draft with base's lines (base
// "" = empty). The single-draft index turns a second draft into a conflict.
func newBOMDraft(ctx context.Context, tx *sql.Tx, projectID, baseID, uid string, ecoID *string) (string, error) {
	var count int
	if err := tx.QueryRowContext(ctx,
		`select count(*) from hw_bom_revs where project_id = ?`, projectID).Scan(&count); err != nil {
		return "", err
	}
	id := newID()
	_, err := tx.ExecContext(ctx, `
		insert into hw_bom_revs (id, project_id, rev, status, eco_id, created_by, created_at)
		values (?, ?, ?, 'draft', ?, ?, ?)`,
		id, projectID, revLetter(count), ecoID, uid, nowString())
	if err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			return "", conflict("bom_draft_exists", "في BOM draft مفتوح. اعمله release أو احذفه الأول.")
		}
		return "", err
	}
	if baseID != "" {
		if _, err := tx.ExecContext(ctx, `
			insert into hw_bom_lines (bom_rev_id, part_id, quantity, ref_designators)
			select ?, part_id, quantity, ref_designators from hw_bom_lines where bom_rev_id = ?`,
			id, baseID); err != nil {
			return "", err
		}
	}
	return id, nil
}

// latestReleasedBOM: "" when nothing was released yet.
func latestReleasedBOM(ctx context.Context, q queryer, projectID string) (string, error) {
	var id string
	err := q.QueryRowContext(ctx, `
		select id from hw_bom_revs where project_id = ? and status = 'released'
		order by length(rev) desc, rev desc limit 1`, projectID).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return "", nil
	}
	return id, err
}

// POST .../hw/bom — a new draft, copied from from_rev_id (a released
// revision of this project) or from the latest release.
func (s *Server) handleCreateBOM(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapEditBOM); err != nil {
		writeError(w, err)
		return
	}
	var body struct {
		FromRevID *string `json:"from_rev_id"`
	}
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
	base := ""
	if body.FromRevID != nil && *body.FromRevID != "" {
		var status string
		err := tx.QueryRowContext(r.Context(),
			`select status from hw_bom_revs where id = ? and project_id = ?`, *body.FromRevID, h.project,
		).Scan(&status)
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, notFound("bom_not_found", "الـ BOM revision مش موجود في المشروع."))
			return
		}
		if err != nil {
			writeError(w, err)
			return
		}
		if status != "released" {
			writeError(w, conflict("bom_not_released", "انسخ من revision اتعمله release بس."))
			return
		}
		base = *body.FromRevID
	} else if base, err = latestReleasedBOM(r.Context(), tx, h.project); err != nil {
		writeError(w, err)
		return
	}
	id, err := newBOMDraft(r.Context(), tx, h.project, base, h.caller.UID, nil)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	bom, err := s.store.bomRevision(r.Context(), h.project, id, h.access.can(CapViewPrices))
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"bom": bom})
}

// draftBOM checks the revision is a draft of this project.
func (s *store) draftBOM(ctx context.Context, projectID, revID string) error {
	var status string
	err := s.db.QueryRowContext(ctx,
		`select status from hw_bom_revs where id = ? and project_id = ?`, revID, projectID).Scan(&status)
	if errors.Is(err, sql.ErrNoRows) {
		return notFound("bom_not_found", "الـ BOM revision مش موجود في المشروع.")
	}
	if err != nil {
		return err
	}
	if status != "draft" {
		return conflict("bom_revision_released", "الـ revision ده اتعمله release ومش بيتعدّل. اعمل draft جديد.")
	}
	return nil
}

// DELETE .../hw/bom/{rid} — drop a draft.
func (s *Server) handleDeleteBOMDraft(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapEditBOM); err != nil {
		writeError(w, err)
		return
	}
	rid := r.PathValue("rid")
	if err := s.store.draftBOM(r.Context(), h.project, rid); err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(),
		`delete from hw_bom_revs where id = ? and project_id = ? and status = 'draft'`, rid, h.project); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

type bomLineRequest struct {
	Quantity       int     `json:"quantity"`
	RefDesignators *string `json:"ref_designators"`
}

// PUT .../hw/bom/{rid}/lines/{partid} — add or change a line of a draft.
func (s *Server) handleSetBOMLine(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapEditBOM); err != nil {
		writeError(w, err)
		return
	}
	var body bomLineRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if body.Quantity < 1 || body.Quantity > 100000 {
		writeError(w, badRequest("invalid_quantity", "الكمية لازم تكون من 1 لـ 100000."))
		return
	}
	refs, err := optionalText(body.RefDesignators, 500, "refs_too_long", "الـ reference designators")
	if err != nil {
		writeError(w, err)
		return
	}
	rid, partID := r.PathValue("rid"), r.PathValue("partid")
	if err := s.store.draftBOM(r.Context(), h.project, rid); err != nil {
		writeError(w, err)
		return
	}
	if err := s.store.hwOwned(r.Context(), s.store.db, "hw_parts", partID, h.project, "part_not_found"); err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into hw_bom_lines (bom_rev_id, part_id, quantity, ref_designators) values (?, ?, ?, ?)
		on conflict (bom_rev_id, part_id) do update
		  set quantity = excluded.quantity, ref_designators = excluded.ref_designators`,
		rid, partID, body.Quantity, refs); err != nil {
		writeError(w, frozenBOM(err))
		return
	}
	s.handleGetBOM(w, r, h)
}

// DELETE .../hw/bom/{rid}/lines/{partid}
func (s *Server) handleDeleteBOMLine(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapEditBOM); err != nil {
		writeError(w, err)
		return
	}
	rid := r.PathValue("rid")
	if err := s.store.draftBOM(r.Context(), h.project, rid); err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(),
		`delete from hw_bom_lines where bom_rev_id = ? and part_id = ?`, rid, r.PathValue("partid")); err != nil {
		writeError(w, frozenBOM(err))
		return
	}
	s.handleGetBOM(w, r, h)
}

// POST .../hw/bom/{rid}/release — freeze a draft.
func (s *Server) handleReleaseBOM(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapReleaseBOM); err != nil {
		writeError(w, err)
		return
	}
	var body struct {
		Note *string `json:"note"`
	}
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	note, err := optionalText(body.Note, 2000, "note_too_long", "الملاحظة")
	if err != nil {
		writeError(w, err)
		return
	}
	rid := r.PathValue("rid")
	if err := s.store.draftBOM(r.Context(), h.project, rid); err != nil {
		writeError(w, err)
		return
	}
	if err := releaseBOM(r.Context(), s.store.db, rid, h.caller.UID, note); err != nil {
		writeError(w, err)
		return
	}
	pid := h.project
	_ = s.store.logActivity(r.Context(), h.ws.ID, h.caller.UID, "bom_released", "BOM release", &pid)
	s.handleGetBOM(w, r, h)
}

func releaseBOM(ctx context.Context, q queryer, rid, uid string, note *string) error {
	var lines int
	if err := q.QueryRowContext(ctx,
		`select count(*) from hw_bom_lines where bom_rev_id = ?`, rid).Scan(&lines); err != nil {
		return err
	}
	if lines == 0 {
		return conflict("bom_empty", "الـ BOM فاضي. ضيف قطع الأول.")
	}
	result, err := q.ExecContext(ctx, `
		update hw_bom_revs set status = 'released', released_by = ?, released_at = ?,
		       note = coalesce(?, note)
		where id = ? and status = 'draft'`, uid, nowString(), note, rid)
	if err != nil {
		return err
	}
	if n, _ := result.RowsAffected(); n == 0 {
		return conflict("bom_revision_released", "الـ revision ده اتعمله release خلاص.")
	}
	return nil
}

// frozenBOM maps the database's "released revision" refusal (a release that
// landed between the draft check and the write) to a conflict.
func frozenBOM(err error) error {
	if err != nil && strings.Contains(err.Error(), "bom_revision_released") {
		return conflict("bom_revision_released", "الـ revision ده اتعمله release ومش بيتعدّل. اعمل draft جديد.")
	}
	return err
}
