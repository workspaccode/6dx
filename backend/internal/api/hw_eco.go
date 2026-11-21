package api

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
)

// ECO / ECR — §7.3.
//
//	draft → design_review → production_review → approved → released
//	              ↘ rejected → draft (edit and resubmit)      · cancelled
//
// Design review needs eco.approve, production review eco.approve_production.
// Whoever wrote or submitted the change never approves it. Releasing an ECO
// (bom.release) applies its items to the latest released BOM and releases
// the result as a new revision, in one transaction. An ECR (a technician's
// request) goes through the same reviews but changes no BOM.

type ecoRequest struct {
	Kind   string  `json:"kind"`
	Title  *string `json:"title"`
	Reason *string `json:"reason"`
	Impact *string `json:"impact"`
}

func (s *store) ecoRow(ctx context.Context, q queryer, projectID, ecoID string) (map[string]any, error) {
	var id, kind, title, status, created, updated string
	var number int
	var reason, impact, createdBy, submittedBy, submittedAt, bomRev *string
	err := q.QueryRowContext(ctx, `
		select id, number, kind, title, reason, impact, status, created_by, submitted_by,
		       submitted_at, bom_rev_id, created_at, updated_at
		from hw_ecos where id = ? and project_id = ?`, ecoID, projectID,
	).Scan(&id, &number, &kind, &title, &reason, &impact, &status, &createdBy, &submittedBy,
		&submittedAt, &bomRev, &created, &updated)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, notFound("eco_not_found", "الـ ECO مش موجود في المشروع.")
	}
	if err != nil {
		return nil, err
	}
	return map[string]any{
		"id": id, "number": number, "code": ecoCode(kind, number), "kind": kind, "title": title,
		"reason": reason, "impact": impact, "status": status, "created_by": createdBy,
		"submitted_by": submittedBy, "submitted_at": submittedAt, "bom_rev_id": bomRev,
		"created_at": created, "updated_at": updated,
	}, nil
}

func ecoCode(kind string, number int) string {
	prefix := "ECO"
	if kind == "ecr" {
		prefix = "ECR"
	}
	return fmt.Sprintf("%s-%03d", prefix, number)
}

// GET .../hw/ecos
func (s *Server) handleListECOs(w http.ResponseWriter, r *http.Request, h *hwContext) {
	rows, err := s.store.db.QueryContext(r.Context(), `
		select id, number, kind, title, status, updated_at,
		       (select count(*) from hw_eco_items i where i.eco_id = hw_ecos.id)
		from hw_ecos where project_id = ? order by number desc`, h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	ecos := make([]map[string]any, 0)
	for rows.Next() {
		var id, kind, title, status, updated string
		var number, items int
		if err := rows.Scan(&id, &number, &kind, &title, &status, &updated, &items); err != nil {
			writeError(w, err)
			return
		}
		ecos = append(ecos, map[string]any{
			"id": id, "number": number, "code": ecoCode(kind, number), "kind": kind,
			"title": title, "status": status, "updated_at": updated, "items": items,
		})
	}
	if err := rows.Err(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ecos": ecos})
}

// GET .../hw/ecos/{eid} — the change with its items and review trail.
func (s *Server) handleGetECO(w http.ResponseWriter, r *http.Request, h *hwContext) {
	eco, err := s.store.ecoRow(r.Context(), s.store.db, h.project, r.PathValue("eid"))
	if err != nil {
		writeError(w, err)
		return
	}
	items := make([]map[string]any, 0)
	rows, err := s.store.db.QueryContext(r.Context(), `
		select i.id, i.action, i.quantity, i.ref_designators,
		       i.from_part_id, f.part_number, f.revision,
		       i.to_part_id, t.part_number, t.revision
		from hw_eco_items i
		left join hw_parts f on f.id = i.from_part_id
		left join hw_parts t on t.id = i.to_part_id
		where i.eco_id = ?`, eco["id"])
	if err != nil {
		writeError(w, err)
		return
	}
	for rows.Next() {
		var id, action string
		var qty *int
		var refs, fromID, fromNum, fromRev, toID, toNum, toRev *string
		if err := rows.Scan(&id, &action, &qty, &refs, &fromID, &fromNum, &fromRev, &toID, &toNum, &toRev); err != nil {
			rows.Close()
			writeError(w, err)
			return
		}
		items = append(items, map[string]any{
			"id": id, "action": action, "quantity": qty, "ref_designators": refs,
			"from_part_id": fromID, "from_part": partLabel(fromNum, fromRev),
			"to_part_id": toID, "to_part": partLabel(toNum, toRev),
		})
	}
	rows.Close()

	approvals := make([]map[string]any, 0)
	rows, err = s.store.db.QueryContext(r.Context(), `
		select a.stage, a.decision, a.comment, a.at,
		       (select coalesce(nullif(u.display_name, ''), u.uid) from users u where u.uid = a.user_uid)
		from hw_eco_approvals a where a.eco_id = ? order by a.at`, eco["id"])
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	for rows.Next() {
		var stage, decision, at string
		var comment, by *string
		if err := rows.Scan(&stage, &decision, &comment, &at, &by); err != nil {
			writeError(w, err)
			return
		}
		approvals = append(approvals, map[string]any{
			"stage": stage, "decision": decision, "comment": comment, "at": at, "by": by,
		})
	}
	eco["items"] = items
	eco["approvals"] = approvals
	eco["can_review"] = s.ecoCanReview(h, eco)
	writeJSON(w, http.StatusOK, map[string]any{"eco": eco})
}

func partLabel(number, rev *string) any {
	if number == nil {
		return nil
	}
	return *number + " rev " + derefOr(rev, "?")
}

// ecoCanReview: the caller holds the stage's capability and did not write
// or submit the change.
func (s *Server) ecoCanReview(h *hwContext, eco map[string]any) bool {
	if author, _ := eco["created_by"].(*string); author != nil && *author == h.caller.UID {
		return false
	}
	if submitter, _ := eco["submitted_by"].(*string); submitter != nil && *submitter == h.caller.UID {
		return false
	}
	switch eco["status"] {
	case "design_review":
		return h.access.can(CapApproveECO)
	case "production_review":
		return h.access.can(CapApproveECOPro)
	}
	return false
}

// POST .../hw/ecos
func (s *Server) handleCreateECO(w http.ResponseWriter, r *http.Request, h *hwContext) {
	var body ecoRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if body.Kind == "" {
		body.Kind = "eco"
	}
	switch body.Kind {
	case "eco":
		if err := h.require(CapSubmitECO); err != nil {
			writeError(w, err)
			return
		}
	case "ecr":
		if err := h.requireAny(CapSubmitECR, CapSubmitECO); err != nil {
			writeError(w, err)
			return
		}
	default:
		writeError(w, badRequest("invalid_kind", "النوع لازم يكون eco أو ecr."))
		return
	}
	title, err := requiredText(body.Title, 200, "invalid_title", "العنوان")
	if err != nil {
		writeError(w, err)
		return
	}
	reason, err := optionalText(body.Reason, 5000, "reason_too_long", "السبب")
	if err != nil {
		writeError(w, err)
		return
	}
	impact, err := optionalText(body.Impact, 5000, "impact_too_long", "الأثر")
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
		`select coalesce(max(number), 0) + 1 from hw_ecos where project_id = ?`, h.project).Scan(&next); err != nil {
		writeError(w, err)
		return
	}
	id, now := newID(), nowString()
	if _, err := tx.ExecContext(r.Context(), `
		insert into hw_ecos (id, project_id, number, kind, title, reason, impact, created_by,
		                     created_at, updated_at)
		values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		id, h.project, next, body.Kind, title, reason, impact, h.caller.UID, now, now); err != nil {
		writeError(w, err)
		return
	}
	eco, err := s.store.ecoRow(r.Context(), tx, h.project, id)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"eco": eco})
}

// ecoForEdit loads a draft the caller may edit: its author, or anyone who
// can submit ECOs.
func (s *Server) ecoForEdit(r *http.Request, h *hwContext) (map[string]any, error) {
	eco, err := s.store.ecoRow(r.Context(), s.store.db, h.project, r.PathValue("eid"))
	if err != nil {
		return nil, err
	}
	if eco["status"] != "draft" {
		return nil, conflict("eco_not_draft", "الـ ECO اتقدّم ومش بيتعدّل. لو اترفض رجّعه draft.")
	}
	author, _ := eco["created_by"].(*string)
	if (author == nil || *author != h.caller.UID) && !h.access.can(CapSubmitECO) {
		return nil, forbidden("missing_capability", "دورك مايسمحش بتعديل الـ ECO ده.")
	}
	return eco, nil
}

type ecoItemRequest struct {
	Action         string  `json:"action"`
	FromPartID     *string `json:"from_part_id"`
	ToPartID       *string `json:"to_part_id"`
	Quantity       *int    `json:"quantity"`
	RefDesignators *string `json:"ref_designators"`
}

// POST .../hw/ecos/{eid}/items
func (s *Server) handleAddECOItem(w http.ResponseWriter, r *http.Request, h *hwContext) {
	eco, err := s.ecoForEdit(r, h)
	if err != nil {
		writeError(w, err)
		return
	}
	var body ecoItemRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	has := func(p *string) bool { return p != nil && *p != "" }
	switch {
	case body.Action == "add" && has(body.ToPartID) && !has(body.FromPartID):
	case body.Action == "change" && has(body.ToPartID) && has(body.FromPartID):
	case body.Action == "remove" && has(body.FromPartID) && !has(body.ToPartID):
	default:
		writeError(w, badRequest("invalid_eco_item",
			"add محتاج قطعة جديدة، و change محتاج القديمة والجديدة، و remove محتاج القديمة."))
		return
	}
	for _, p := range []*string{body.FromPartID, body.ToPartID} {
		if has(p) {
			if err := s.store.hwOwned(r.Context(), s.store.db, "hw_parts", *p, h.project, "part_not_found"); err != nil {
				writeError(w, err)
				return
			}
		}
	}
	if body.Quantity != nil && (*body.Quantity < 1 || *body.Quantity > 100000) {
		writeError(w, badRequest("invalid_quantity", "الكمية لازم تكون من 1 لـ 100000."))
		return
	}
	refs, err := optionalText(body.RefDesignators, 500, "refs_too_long", "الـ reference designators")
	if err != nil {
		writeError(w, err)
		return
	}
	nilIfEmpty := func(p *string) any {
		if has(p) {
			return *p
		}
		return nil
	}
	if _, err := s.store.db.ExecContext(r.Context(), `
		insert into hw_eco_items (id, eco_id, action, from_part_id, to_part_id, quantity, ref_designators)
		values (?, ?, ?, ?, ?, ?, ?)`,
		newID(), eco["id"], body.Action, nilIfEmpty(body.FromPartID), nilIfEmpty(body.ToPartID),
		body.Quantity, refs); err != nil {
		writeError(w, err)
		return
	}
	s.handleGetECO(w, r, h)
}

// DELETE .../hw/ecos/{eid}/items/{iid}
func (s *Server) handleDeleteECOItem(w http.ResponseWriter, r *http.Request, h *hwContext) {
	eco, err := s.ecoForEdit(r, h)
	if err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(),
		`delete from hw_eco_items where id = ? and eco_id = ?`, r.PathValue("iid"), eco["id"]); err != nil {
		writeError(w, err)
		return
	}
	s.handleGetECO(w, r, h)
}

// POST .../hw/ecos/{eid}/submit — to design review.
func (s *Server) handleSubmitECO(w http.ResponseWriter, r *http.Request, h *hwContext) {
	eco, err := s.ecoForEdit(r, h)
	if err != nil {
		writeError(w, err)
		return
	}
	if eco["kind"] == "eco" {
		var items int
		if err := s.store.db.QueryRowContext(r.Context(),
			`select count(*) from hw_eco_items where eco_id = ?`, eco["id"]).Scan(&items); err != nil {
			writeError(w, err)
			return
		}
		if items == 0 {
			writeError(w, conflict("eco_empty", "الـ ECO لازم يكون فيه تغيير واحد على الأقل."))
			return
		}
	}
	now := nowString()
	if _, err := s.store.db.ExecContext(r.Context(), `
		update hw_ecos set status = 'design_review', submitted_by = ?, submitted_at = ?, updated_at = ?
		where id = ? and status = 'draft'`, h.caller.UID, now, now, eco["id"]); err != nil {
		writeError(w, err)
		return
	}
	pid := h.project
	_ = s.store.logActivity(r.Context(), h.ws.ID, h.caller.UID, "eco_submitted",
		ecoCode(eco["kind"].(string), eco["number"].(int))+" اتقدّم للمراجعة", &pid)
	s.handleGetECO(w, r, h)
}

type ecoReviewRequest struct {
	Decision string  `json:"decision"`
	Comment  *string `json:"comment"`
}

// POST .../hw/ecos/{eid}/review — approve or reject the current stage.
func (s *Server) handleReviewECO(w http.ResponseWriter, r *http.Request, h *hwContext) {
	var body ecoReviewRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if !oneOf(body.Decision, "approve", "reject") {
		writeError(w, badRequest("invalid_decision", "القرار لازم يكون approve أو reject."))
		return
	}
	comment, err := optionalText(body.Comment, 2000, "comment_too_long", "التعليق")
	if err != nil {
		writeError(w, err)
		return
	}
	if body.Decision == "reject" && comment == nil {
		writeError(w, badRequest("reason_required", "اكتب سبب الرفض."))
		return
	}
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	eco, err := s.store.ecoRow(r.Context(), tx, h.project, r.PathValue("eid"))
	if err != nil {
		writeError(w, err)
		return
	}
	stage := map[string]string{"design_review": "design", "production_review": "production"}[eco["status"].(string)]
	if stage == "" {
		writeError(w, conflict("eco_not_in_review", "الـ ECO مش في مرحلة مراجعة."))
		return
	}
	if !s.ecoCanReview(h, eco) {
		writeError(w, forbidden("cannot_review",
			"المراجعة دي محتاجة دور معيّن، واللي كتب أو قدّم الـ ECO مايعتمدوش."))
		return
	}
	next := "rejected"
	if body.Decision == "approve" {
		next = map[string]string{"design": "production_review", "production": "approved"}[stage]
	}
	now := nowString()
	// The status condition makes two concurrent reviews of one stage count
	// once: the second finds the ECO already moved.
	result, err := tx.ExecContext(r.Context(),
		`update hw_ecos set status = ?, updated_at = ? where id = ? and status = ?`,
		next, now, eco["id"], eco["status"])
	if err != nil {
		writeError(w, err)
		return
	}
	if n, _ := result.RowsAffected(); n == 0 {
		writeError(w, conflict("eco_changed", "الـ ECO اتغيّر. حدّث الشاشة."))
		return
	}
	if _, err := tx.ExecContext(r.Context(), `
		insert into hw_eco_approvals (id, eco_id, stage, user_uid, decision, comment, at)
		values (?, ?, ?, ?, ?, ?, ?)`, newID(), eco["id"], stage, h.caller.UID, body.Decision, comment, now); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.handleGetECO(w, r, h)
}

// POST .../hw/ecos/{eid}/reopen — a rejected change goes back to draft.
// POST .../hw/ecos/{eid}/cancel — drop a change that was not released.
func (s *Server) handleECOStatus(to string) func(http.ResponseWriter, *http.Request, *hwContext) {
	return func(w http.ResponseWriter, r *http.Request, h *hwContext) {
		eco, err := s.store.ecoRow(r.Context(), s.store.db, h.project, r.PathValue("eid"))
		if err != nil {
			writeError(w, err)
			return
		}
		author, _ := eco["created_by"].(*string)
		if (author == nil || *author != h.caller.UID) && !h.access.can(CapSubmitECO) {
			writeError(w, forbidden("missing_capability", "دورك مايسمحش بالعملية دي."))
			return
		}
		from := map[string][]string{
			"draft":     {"rejected"},
			"cancelled": {"draft", "design_review", "production_review", "approved", "rejected"},
		}[to]
		if !oneOf(eco["status"].(string), from...) {
			writeError(w, conflict("invalid_eco_transition", "مينفعش من الحالة الحالية."))
			return
		}
		if _, err := s.store.db.ExecContext(r.Context(),
			`update hw_ecos set status = ?, updated_at = ? where id = ? and status = ?`,
			to, nowString(), eco["id"], eco["status"]); err != nil {
			writeError(w, err)
			return
		}
		s.handleGetECO(w, r, h)
	}
}

// POST .../hw/ecos/{eid}/release — apply an approved ECO: new BOM revision
// from the latest release + the items, released at once (the ECN).
func (s *Server) handleReleaseECO(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapReleaseBOM); err != nil {
		writeError(w, err)
		return
	}
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	eco, err := s.store.ecoRow(r.Context(), tx, h.project, r.PathValue("eid"))
	if err != nil {
		writeError(w, err)
		return
	}
	if eco["status"] != "approved" {
		writeError(w, conflict("eco_not_approved", "الـ ECO لازم يتعتمد في المرحلتين الأول."))
		return
	}
	if eco["kind"] != "eco" {
		writeError(w, conflict("ecr_has_no_release", "الـ ECR طلب بس. اعمل ECO بالتغييرات."))
		return
	}
	base, err := latestReleasedBOM(r.Context(), tx, h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	ecoID := eco["id"].(string)
	revID, err := newBOMDraft(r.Context(), tx, h.project, base, h.caller.UID, &ecoID)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := applyECOItems(r.Context(), tx, ecoID, revID); err != nil {
		writeError(w, err)
		return
	}
	note := "ECN " + eco["code"].(string)
	if err := releaseBOM(r.Context(), tx, revID, h.caller.UID, &note); err != nil {
		writeError(w, err)
		return
	}
	if _, err := tx.ExecContext(r.Context(),
		`update hw_ecos set status = 'released', bom_rev_id = ?, updated_at = ? where id = ?`,
		revID, nowString(), ecoID); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	pid := h.project
	_ = s.store.logActivity(r.Context(), h.ws.ID, h.caller.UID, "eco_released",
		eco["code"].(string)+" اتعمله release", &pid)
	s.handleGetECO(w, r, h)
}

// applyECOItems edits the new draft. An item that no longer fits the BOM
// (a part already there, or not there to change) fails the whole release.
func applyECOItems(ctx context.Context, tx *sql.Tx, ecoID, revID string) error {
	rows, err := tx.QueryContext(ctx, `
		select action, from_part_id, to_part_id, quantity, ref_designators
		from hw_eco_items where eco_id = ?`, ecoID)
	if err != nil {
		return err
	}
	type item struct {
		action   string
		from, to *string
		qty      *int
		refs     *string
	}
	items := []item{}
	for rows.Next() {
		var it item
		if err := rows.Scan(&it.action, &it.from, &it.to, &it.qty, &it.refs); err != nil {
			rows.Close()
			return err
		}
		items = append(items, it)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}
	exists := func(partID string) (bool, error) {
		var one int
		err := tx.QueryRowContext(ctx,
			`select 1 from hw_bom_lines where bom_rev_id = ? and part_id = ?`, revID, partID).Scan(&one)
		if errors.Is(err, sql.ErrNoRows) {
			return false, nil
		}
		return err == nil, err
	}
	stale := conflict("eco_does_not_apply", "التغييرات مش متوافقة مع آخر BOM اتعمله release. عدّل الـ ECO.")
	for _, it := range items {
		switch it.action {
		case "add":
			found, err := exists(*it.to)
			if err != nil {
				return err
			}
			if found {
				return stale
			}
			qty := 1
			if it.qty != nil {
				qty = *it.qty
			}
			if _, err := tx.ExecContext(ctx, `
				insert into hw_bom_lines (bom_rev_id, part_id, quantity, ref_designators) values (?, ?, ?, ?)`,
				revID, *it.to, qty, it.refs); err != nil {
				return err
			}
		case "change":
			found, err := exists(*it.from)
			if err != nil {
				return err
			}
			if !found {
				return stale
			}
			if dup, err := exists(*it.to); err != nil {
				return err
			} else if dup && *it.to != *it.from {
				return stale
			}
			if _, err := tx.ExecContext(ctx, `
				update hw_bom_lines set part_id = ?, quantity = coalesce(?, quantity),
				       ref_designators = coalesce(?, ref_designators)
				where bom_rev_id = ? and part_id = ?`, *it.to, it.qty, it.refs, revID, *it.from); err != nil {
				return err
			}
		case "remove":
			found, err := exists(*it.from)
			if err != nil {
				return err
			}
			if !found {
				return stale
			}
			if _, err := tx.ExecContext(ctx,
				`delete from hw_bom_lines where bom_rev_id = ? and part_id = ?`, revID, *it.from); err != nil {
				return err
			}
		}
	}
	return nil
}
