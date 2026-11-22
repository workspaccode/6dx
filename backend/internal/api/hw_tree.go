package api

import (
	"context"
	"database/sql"
	"errors"
	"math"
	"net/http"
)

// Multi-level BOM and where-used — migration 0008.
//
// A part with children is an assembly. A BOM revision lists top-level
// parts; explode() walks the assemblies under them (depth ≤ maxBOMDepth)
// and multiplies quantities down the tree. What has no children is a leaf:
// what is bought, reserved and issued.

const (
	maxBOMDepth = 10
	// maxExplodedNodes bounds every explosion: a small DAG (10 parts per
	// level, each in all 10 of the next) is 10^10 paths, which would hold
	// the single database connection forever. Past this a BOM is refused.
	maxExplodedNodes = 20000
	// maxNodeQty caps a node's quantity per unit (10 levels × 100000 would
	// overflow int64).
	maxNodeQty = 1_000_000_000
)

func bomTooLarge() error {
	return conflict("bom_too_large", "الـ BOM ده كبير جدًا لما يتفك (أكتر من 20000 جزء). قسّمه لـ assemblies أصغر.")
}

// explodeCTE: every node under a BOM revision (one ? = the revision), with
// its quantity per finished unit. `ex.path` keeps siblings apart and stops
// at the depth limit (cycles are refused on write; the limit is a second
// guard).
const explodeCTE = `
	with recursive ex(part_id, qty, level, path, parent_id, refs) as (
	  select l.part_id, l.quantity, 0, l.part_id, null, l.ref_designators
	  from hw_bom_lines l where l.bom_rev_id = ?
	  union all
	  select c.child_part_id, min(ex.qty * c.quantity, 1000000000), ex.level + 1,
	         ex.path || '/' || c.child_part_id, ex.part_id, c.ref_designators
	  from hw_part_children c join ex on c.parent_part_id = ex.part_id
	  where ex.level < 10
	  limit 20001
	)`

// partIsFrozen: the part sits in a released BOM revision, directly or inside
// an assembly — changing its children would change that snapshot.
func partIsFrozen(ctx context.Context, q queryer, partID string) (bool, error) {
	var frozen int
	err := q.QueryRowContext(ctx, `
		with recursive up(id) as (
		  select ?
		  union
		  select c.parent_part_id from hw_part_children c join up on c.child_part_id = up.id
		)
		select exists (
		  select 1 from hw_bom_lines l join hw_bom_revs b on b.id = l.bom_rev_id
		  where b.status = 'released' and l.part_id in (select id from up)
		)`, partID).Scan(&frozen)
	return frozen == 1, err
}

// wouldCycle: adding child under parent makes parent its own descendant.
func wouldCycle(ctx context.Context, q queryer, parentID, childID string) (bool, error) {
	var cycle int
	err := q.QueryRowContext(ctx, `
		with recursive down(id) as (
		  select ?
		  union
		  select c.child_part_id from hw_part_children c join down on c.parent_part_id = down.id
		)
		select exists (select 1 from down where id = ?)`, childID, parentID).Scan(&cycle)
	return cycle == 1, err
}

// GET .../hw/parts/{partid}/children — the assembly's direct children.
func (s *Server) handleListPartChildren(w http.ResponseWriter, r *http.Request, h *hwContext) {
	partID := r.PathValue("partid")
	if err := s.store.hwOwned(r.Context(), s.store.db, "hw_parts", partID, h.project, "part_not_found"); err != nil {
		writeError(w, err)
		return
	}
	s.writePartChildren(w, r, h, partID, http.StatusOK)
}

func (s *Server) writePartChildren(w http.ResponseWriter, r *http.Request, h *hwContext, partID string, status int) {
	rows, err := s.store.db.QueryContext(r.Context(), `
		select c.child_part_id, c.quantity, c.ref_designators, p.part_number, p.revision, p.description,
		       exists (select 1 from hw_part_children x where x.parent_part_id = c.child_part_id)
		from hw_part_children c join hw_parts p on p.id = c.child_part_id
		where c.parent_part_id = ? order by p.part_number`, partID)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	children := make([]map[string]any, 0)
	for rows.Next() {
		var id, number, rev, description string
		var qty int
		var refs *string
		var assembly bool
		if err := rows.Scan(&id, &qty, &refs, &number, &rev, &description, &assembly); err != nil {
			writeError(w, err)
			return
		}
		children = append(children, map[string]any{
			"part_id": id, "quantity": qty, "ref_designators": refs, "part_number": number,
			"revision": rev, "description": description, "is_assembly": assembly,
		})
	}
	if err := rows.Err(); err != nil {
		writeError(w, err)
		return
	}
	frozen, err := partIsFrozen(r.Context(), s.store.db, partID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, status, map[string]any{"children": children, "frozen": frozen})
}

// requireEditableAssembly: an assembly in a released BOM, or in production,
// keeps its structure; a new revision of it is the way to change it.
//
// It runs inside the write's transaction: with the single connection, a
// BOM release cannot land between this check and the change.
func (s *Server) requireEditableAssembly(ctx context.Context, q queryer, h *hwContext, partID string) error {
	var lifecycle string
	err := q.QueryRowContext(ctx,
		`select lifecycle from hw_parts where id = ? and project_id = ?`, partID, h.project).Scan(&lifecycle)
	if errors.Is(err, sql.ErrNoRows) {
		return notFound("part_not_found", "القطعة مش موجودة في المشروع.")
	}
	if err != nil {
		return err
	}
	if lifecycle == "production" || lifecycle == "obsolete" {
		return conflict("assembly_frozen", "الـ assembly ده في الإنتاج. اعمل revision جديد علشان تغيّر مكوناته.")
	}
	frozen, err := partIsFrozen(ctx, q, partID)
	if err != nil {
		return err
	}
	if frozen {
		return conflict("assembly_frozen",
			"الـ assembly ده جوه BOM اتعمله release، وتغيير مكوناته هيغيّر الـ snapshot. اعمل revision جديد.")
	}
	return nil
}

// PUT .../hw/parts/{partid}/children/{child} {quantity, ref_designators}
func (s *Server) handleSetPartChild(w http.ResponseWriter, r *http.Request, h *hwContext) {
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
	parent, child := r.PathValue("partid"), r.PathValue("child")
	if parent == child {
		writeError(w, badRequest("self_child", "القطعة مينفعش تبقى جوه نفسها."))
		return
	}
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	if err := s.requireEditableAssembly(r.Context(), tx, h, parent); err != nil {
		writeError(w, err)
		return
	}
	if err := s.store.hwOwned(r.Context(), tx, "hw_parts", child, h.project, "part_not_found"); err != nil {
		writeError(w, err)
		return
	}
	cycle, err := wouldCycle(r.Context(), tx, parent, child)
	if err != nil {
		writeError(w, err)
		return
	}
	if cycle {
		writeError(w, conflict("bom_cycle", "القطعة دي فيها الـ assembly نفسه، فده هيعمل حلقة."))
		return
	}
	var depth int
	if err := tx.QueryRowContext(r.Context(), `
		with recursive
		  up(id, d) as (select ?, 0 union select c.parent_part_id, up.d + 1 from hw_part_children c
		                join up on c.child_part_id = up.id where up.d < 20),
		  down(id, d) as (select ?, 0 union select c.child_part_id, down.d + 1 from hw_part_children c
		                  join down on c.parent_part_id = down.id where down.d < 20)
		select (select max(d) from up) + (select max(d) from down) + 1`, parent, child).Scan(&depth); err != nil {
		writeError(w, err)
		return
	}
	if depth > maxBOMDepth {
		writeError(w, conflict("bom_too_deep", "الحد الأقصى 10 مستويات."))
		return
	}
	if _, err := tx.ExecContext(r.Context(), `
		insert into hw_part_children (parent_part_id, child_part_id, quantity, ref_designators)
		values (?, ?, ?, ?)
		on conflict (parent_part_id, child_part_id) do update
		  set quantity = excluded.quantity, ref_designators = excluded.ref_designators`,
		parent, child, body.Quantity, refs); err != nil {
		writeError(w, err)
		return
	}
	// Every tree that contains this edge must stay explodable: count the
	// paths under each topmost assembly above the parent (bounded queries).
	roots := []string{}
	rootRows, err := tx.QueryContext(r.Context(), `
		with recursive up(id) as (
		  select ?
		  union
		  select c.parent_part_id from hw_part_children c join up on c.child_part_id = up.id
		)
		select id from up where not exists (select 1 from hw_part_children c where c.child_part_id = up.id)
		limit 50`, parent)
	if err != nil {
		writeError(w, err)
		return
	}
	for rootRows.Next() {
		var id string
		if err := rootRows.Scan(&id); err != nil {
			rootRows.Close()
			writeError(w, err)
			return
		}
		roots = append(roots, id)
	}
	rootRows.Close()
	for _, root := range roots {
		var nodes int
		if err := tx.QueryRowContext(r.Context(), `
			with recursive down(id, level) as (
			  select ?, 0
			  union all
			  select c.child_part_id, down.level + 1 from hw_part_children c join down on c.parent_part_id = down.id
			  where down.level < 10
			  limit 20001
			)
			select count(*) from down`, root).Scan(&nodes); err != nil {
			writeError(w, err)
			return
		}
		if nodes > maxExplodedNodes {
			writeError(w, bomTooLarge())
			return
		}
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.writePartChildren(w, r, h, parent, http.StatusOK)
}

// DELETE .../hw/parts/{partid}/children/{child}
func (s *Server) handleDeletePartChild(w http.ResponseWriter, r *http.Request, h *hwContext) {
	if err := h.require(CapEditBOM); err != nil {
		writeError(w, err)
		return
	}
	parent := r.PathValue("partid")
	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()
	if err := s.requireEditableAssembly(r.Context(), tx, h, parent); err != nil {
		writeError(w, err)
		return
	}
	if _, err := tx.ExecContext(r.Context(),
		`delete from hw_part_children where parent_part_id = ? and child_part_id = ?`,
		parent, r.PathValue("child")); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	s.writePartChildren(w, r, h, parent, http.StatusOK)
}

// GET .../hw/bom/{rid}/tree — the exploded revision: every node with its
// level, quantity per unit and parent; plus the flat totals of the leaves
// (what is bought) and, with prices.view, the rolled-up cost.
func (s *Server) handleBOMTree(w http.ResponseWriter, r *http.Request, h *hwContext) {
	rid := r.PathValue("rid")
	if err := s.store.hwOwned(r.Context(), s.store.db, "hw_bom_revs", rid, h.project, "bom_not_found"); err != nil {
		writeError(w, err)
		return
	}
	prices := h.access.can(CapViewPrices)
	rows, err := s.store.db.QueryContext(r.Context(), explodeCTE+`
		select ex.part_id, ex.qty, ex.level, ex.parent_id, ex.refs, p.part_number, p.revision, p.description,
		       p.unit_cost_cents,
		       exists (select 1 from hw_part_children x where x.parent_part_id = ex.part_id)
		from ex join hw_parts p on p.id = ex.part_id
		order by ex.path`, rid)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	nodes := make([]map[string]any, 0)
	type leaf struct {
		number, rev, description string
		qty                      int64
		cost                     *int64
	}
	leaves := map[string]*leaf{}
	order := []string{}
	var total int64
	overflow := false
	for rows.Next() {
		if len(nodes) >= maxExplodedNodes {
			writeError(w, bomTooLarge())
			return
		}
		var id, number, rev, description string
		var qty int64
		var level int
		var parent, refs *string
		var cost *int64
		var assembly bool
		if err := rows.Scan(&id, &qty, &level, &parent, &refs, &number, &rev, &description, &cost, &assembly); err != nil {
			writeError(w, err)
			return
		}
		node := map[string]any{
			"part_id": id, "quantity": qty, "level": level, "parent_id": parent, "ref_designators": refs,
			"part_number": number, "revision": rev, "description": description, "is_assembly": assembly,
		}
		if prices {
			node["unit_cost_cents"] = cost
		}
		nodes = append(nodes, node)
		if assembly && level >= maxBOMDepth {
			// Children past the depth limit would silently vanish from the
			// leaves, the cost and the demand.
			writeError(w, conflict("bom_too_deep", "الـ BOM أعمق من 10 مستويات."))
			return
		}
		if !assembly {
			l, ok := leaves[id]
			if !ok {
				l = &leaf{number: number, rev: rev, description: description, cost: cost}
				leaves[id] = l
				order = append(order, id)
			}
			l.qty += qty
			if cost != nil && *cost > 0 {
				if qty > (math.MaxInt64-total) / *cost {
					overflow = true
				} else {
					total += *cost * qty
				}
			}
		}
	}
	if err := rows.Err(); err != nil {
		writeError(w, err)
		return
	}
	flat := make([]map[string]any, 0, len(order))
	for _, id := range order {
		l := leaves[id]
		row := map[string]any{
			"part_id": id, "part_number": l.number, "revision": l.rev, "description": l.description, "quantity": l.qty,
		}
		if prices {
			row["unit_cost_cents"] = l.cost
		}
		flat = append(flat, row)
	}
	out := map[string]any{"nodes": nodes, "leaves": flat}
	if prices && !overflow {
		out["total_cost_cents"] = total
	}
	writeJSON(w, http.StatusOK, out)
}

// GET .../hw/parts/{partid}/where-used — the assemblies that contain the
// part (any level up), the BOM revisions that use it (directly or through
// them) and the builds made from those revisions.
func (s *Server) handleWhereUsed(w http.ResponseWriter, r *http.Request, h *hwContext) {
	partID := r.PathValue("partid")
	if err := s.store.hwOwned(r.Context(), s.store.db, "hw_parts", partID, h.project, "part_not_found"); err != nil {
		writeError(w, err)
		return
	}
	const up = `
		with recursive up(id, level) as (
		  select ?, 0
		  union
		  select c.parent_part_id, up.level + 1 from hw_part_children c join up on c.child_part_id = up.id
		  where up.level < 20
		)`
	ctx := r.Context()
	assemblies := make([]map[string]any, 0)
	rows, err := s.store.db.QueryContext(ctx, up+`
		select p.id, p.part_number, p.revision, p.description, min(up.level)
		from up join hw_parts p on p.id = up.id where up.level > 0
		group by p.id order by min(up.level), p.part_number`, partID)
	if err != nil {
		writeError(w, err)
		return
	}
	for rows.Next() {
		var id, number, rev, description string
		var level int
		if err := rows.Scan(&id, &number, &rev, &description, &level); err != nil {
			rows.Close()
			writeError(w, err)
			return
		}
		assemblies = append(assemblies, map[string]any{
			"part_id": id, "part_number": number, "revision": rev, "description": description, "level": level,
		})
	}
	rows.Close()

	revisions := make([]map[string]any, 0)
	rows, err = s.store.db.QueryContext(ctx, up+`
		select distinct b.id, b.rev, b.status
		from hw_bom_lines l join hw_bom_revs b on b.id = l.bom_rev_id
		where b.project_id = ? and l.part_id in (select id from up)
		order by length(b.rev) desc, b.rev desc`, partID, h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	for rows.Next() {
		var id, rev, status string
		if err := rows.Scan(&id, &rev, &status); err != nil {
			rows.Close()
			writeError(w, err)
			return
		}
		revisions = append(revisions, map[string]any{"id": id, "rev": rev, "status": status})
	}
	rows.Close()

	builds := make([]map[string]any, 0)
	rows, err = s.store.db.QueryContext(ctx, up+`
		select distinct bd.id, bd.name, bd.status, br.rev
		from hw_builds bd join hw_bom_revs br on br.id = bd.bom_rev_id
		where bd.project_id = ? and exists (
		  select 1 from hw_bom_lines l where l.bom_rev_id = bd.bom_rev_id and l.part_id in (select id from up))
		order by bd.created_at desc`, partID, h.project)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()
	for rows.Next() {
		var id, name, status, rev string
		if err := rows.Scan(&id, &name, &status, &rev); err != nil {
			writeError(w, err)
			return
		}
		builds = append(builds, map[string]any{"id": id, "name": name, "status": status, "bom_rev": rev})
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"assemblies": assemblies, "bom_revisions": revisions, "builds": builds,
	})
}
