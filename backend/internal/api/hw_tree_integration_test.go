//go:build integration

package api

import (
	"fmt"
	"net/http"
	"testing"
)

// A board (assembly) inside the product BOM: the tree explodes, the leaves
// total and cost roll up, demand asks for the leaves, where-used walks up,
// and a released snapshot freezes the assembly's structure.
func TestMultiLevelBOM(t *testing.T) {
	w := newHWWorld(t)
	part := func(number string, cost int) string {
		t.Helper()
		return w.must(t, 201, "POST", "parts", "hw-ee", map[string]any{
			"part_number": number, "description": number, "unit_cost_cents": cost,
		})["part"].(map[string]any)["id"].(string)
	}
	pcba, r10k, mcu, enclosure := part("PCBA-1", 0), part("R-10K", 2), part("MCU-1", 300), part("ENC-1", 150)
	screw := part("SCREW", 1)

	// PCBA-1 = 10 × R-10K + 1 × MCU-1; ENC-1 = 4 × SCREW
	w.must(t, 200, "PUT", "parts/"+pcba+"/children/"+r10k, "hw-ee", map[string]any{"quantity": 10})
	w.must(t, 200, "PUT", "parts/"+pcba+"/children/"+mcu, "hw-ee", map[string]any{"quantity": 1})
	w.must(t, 200, "PUT", "parts/"+enclosure+"/children/"+screw, "hw-ee", map[string]any{"quantity": 4})
	// No cycles, no self, other roles cannot edit.
	w.must(t, 409, "PUT", "parts/"+r10k+"/children/"+pcba, "hw-ee", map[string]any{"quantity": 1})
	w.must(t, 400, "PUT", "parts/"+pcba+"/children/"+pcba, "hw-ee", map[string]any{"quantity": 1})
	w.must(t, 403, "PUT", "parts/"+pcba+"/children/"+screw, "hw-tech", map[string]any{"quantity": 1})

	// Product BOM rev A: 2 × PCBA-1 + 1 × ENC-1 (enclosure has its own cost,
	// but as an assembly its price is its children's).
	draft := w.must(t, 201, "POST", "bom", "hw-ee", map[string]any{})["bom"].(map[string]any)
	rid := draft["id"].(string)
	w.must(t, 200, "PUT", "bom/"+rid+"/lines/"+pcba, "hw-ee", map[string]any{"quantity": 2})
	bom := w.must(t, 200, "PUT", "bom/"+rid+"/lines/"+enclosure, "hw-ee", map[string]any{"quantity": 1})["bom"].(map[string]any)
	// 2×(10×2 + 300) + 4×1 = 644
	if bom["total_cost_cents"] != float64(644) {
		t.Errorf("rolled-up cost: %v", bom["total_cost_cents"])
	}
	tree := w.must(t, 200, "GET", "bom/"+rid+"/tree", "hw-ee", nil)
	if n := len(tree["nodes"].([]any)); n != 5 {
		t.Errorf("tree nodes: %d", n)
	}
	leafQty := map[string]float64{}
	for _, raw := range tree["leaves"].([]any) {
		l := raw.(map[string]any)
		leafQty[l["part_number"].(string)] = l["quantity"].(float64)
	}
	if leafQty["R-10K"] != 20 || leafQty["MCU-1"] != 2 || leafQty["SCREW"] != 4 || len(leafQty) != 3 {
		t.Errorf("leaves: %v", leafQty)
	}
	// The technician sees the tree but no prices.
	if tech := w.must(t, 200, "GET", "bom/"+rid+"/tree", "hw-tech", nil); tech["total_cost_cents"] != nil {
		t.Error("technician sees the rolled-up cost")
	}

	// Released: the assemblies inside it are frozen.
	w.must(t, 200, "POST", "bom/"+rid+"/release", "hw-lead", nil)
	w.must(t, 409, "PUT", "parts/"+pcba+"/children/"+screw, "hw-ee", map[string]any{"quantity": 1})
	w.must(t, 409, "DELETE", "parts/"+pcba+"/children/"+r10k, "hw-ee", nil)
	if c := w.must(t, 200, "GET", "parts/"+pcba+"/children", "hw-ee", nil); c["frozen"] != true {
		t.Errorf("children frozen flag: %v", c["frozen"])
	}

	// Demand asks for the leaves × build size.
	w.must(t, 201, "POST", "builds", "hw-lead", map[string]any{"name": "EVT1", "bom_rev_id": rid, "quantity": 5})
	need := map[string]float64{}
	for _, d := range list(w.must(t, 200, "GET", "demand", "hw-ee", nil), "demand") {
		need[d["part_number"].(string)] = d["needed"].(float64)
	}
	if need["R-10K"] != 100 || need["MCU-1"] != 10 || need["SCREW"] != 20 || need["PCBA-1"] != 0 {
		t.Errorf("demand: %v", need)
	}

	// Where-used walks up to the assembly, the revision and the build.
	used := w.must(t, 200, "GET", "parts/"+r10k+"/where-used", "hw-ee", nil)
	if a := list(used, "assemblies"); len(a) != 1 || a[0]["part_number"] != "PCBA-1" {
		t.Errorf("where-used assemblies: %v", a)
	}
	if b := list(used, "bom_revisions"); len(b) != 1 || b[0]["rev"] != "A" {
		t.Errorf("where-used revisions: %v", b)
	}
	if b := list(used, "builds"); len(b) != 1 || b[0]["name"] != "EVT1" {
		t.Errorf("where-used builds: %v", b)
	}
	// A part of another project never resolves.
	_, other := w.h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "hw-lead", w.ws, map[string]any{"name": "PB-2", "group_id": w.gid})
	base2 := "/v1/groups/" + w.gid + "/projects/" + other["project"].(map[string]any)["id"].(string) + "/hw/"
	if status, _ := w.h.doWithWorkspace(t, http.MethodGet, base2+"parts/"+r10k+"/where-used", "hw-ee", w.ws, nil); status != 404 {
		t.Errorf("foreign where-used: %d", status)
	}
}

// Regressions from the review: an exploding DAG is refused, and a
// production assembly does not go back to draft.
func TestMultiLevelBOMLimits(t *testing.T) {
	w := newHWWorld(t)
	part := func(number string) string {
		t.Helper()
		return w.must(t, 201, "POST", "parts", "hw-ee", map[string]any{"part_number": number, "description": number})["part"].(map[string]any)["id"].(string)
	}
	// root → 5 levels of 10 parts, every part linked to all 10 of the next
	// level: 10^5 paths. Some edge on the way must be refused.
	root := part("ROOT")
	levels := [][]string{{root}}
	for l := 1; l <= 5; l++ {
		row := []string{}
		for i := 0; i < 10; i++ {
			row = append(row, part(fmt.Sprintf("L%d-%d", l, i)))
		}
		levels = append(levels, row)
	}
	refused := false
	for l := 1; l < len(levels) && !refused; l++ {
		for _, parent := range levels[l-1] {
			for _, child := range levels[l] {
				status, _ := w.do(t, "PUT", "parts/"+parent+"/children/"+child, "hw-ee", map[string]any{"quantity": 2})
				if status == 409 {
					refused = true
				} else if status != 200 {
					t.Fatalf("edge: %d", status)
				}
			}
		}
	}
	if !refused {
		t.Fatal("an exploding BOM was accepted")
	}
	// What was accepted still explodes within the limit.
	draft := w.must(t, 201, "POST", "bom", "hw-ee", map[string]any{})["bom"].(map[string]any)
	w.must(t, 200, "PUT", "bom/"+draft["id"].(string)+"/lines/"+root, "hw-ee", map[string]any{"quantity": 1})
	w.must(t, 200, "GET", "bom/"+draft["id"].(string)+"/tree", "hw-ee", nil)

	// Production assemblies stay put.
	asm, leaf := part("ASM"), part("LEAF")
	w.must(t, 200, "PUT", "parts/"+asm+"/children/"+leaf, "hw-ee", map[string]any{"quantity": 1})
	w.must(t, 200, "PATCH", "parts/"+asm, "hw-ee", map[string]any{"lifecycle": "production"})
	w.must(t, 409, "PATCH", "parts/"+asm, "hw-ee", map[string]any{"lifecycle": "draft"})
	w.must(t, 409, "DELETE", "parts/"+asm+"/children/"+leaf, "hw-ee", nil)
}
