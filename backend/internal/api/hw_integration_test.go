//go:build integration

package api

import (
	"net/http"
	"testing"
)

type hwWorld struct {
	h    *harness
	ws   string
	gid  string
	pid  string
	base string // /v1/groups/{gid}/projects/{pid}/hw/
}

func (w *hwWorld) do(t *testing.T, method, path, uid string, body any) (int, map[string]any) {
	t.Helper()
	return w.h.doWithWorkspace(t, method, w.base+path, uid, w.ws, body)
}

func (w *hwWorld) must(t *testing.T, want int, method, path, uid string, body any) map[string]any {
	t.Helper()
	status, out := w.do(t, method, path, uid, body)
	if status != want {
		t.Fatalf("%s %s as %s: %d %v (want %d)", method, path, uid, status, out, want)
	}
	return out
}

func newHWWorld(t *testing.T) *hwWorld {
	t.Helper()
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "hw-lead", nil)
	ws := workspaceOf(t, me)
	_, created := createGroup(t, h, "hw-lead", ws, "Power Board", "hardware")
	gid := groupIDOf(t, created)
	for uid, role := range map[string]string{
		"hw-ee": "electrical", "hw-fw": "firmware", "hw-test": "test", "hw-tech": "technician",
	} {
		joinGroupAs(t, h, "hw-lead", ws, gid, uid, "member", role)
	}
	joinGroupAs(t, h, "hw-lead", ws, gid, "hw-client", "guest", "client")
	_, project := h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "hw-lead", ws,
		map[string]any{"name": "PB-1", "group_id": gid})
	pid := project["project"].(map[string]any)["id"].(string)
	return &hwWorld{h: h, ws: ws, gid: gid, pid: pid,
		base: "/v1/groups/" + gid + "/projects/" + pid + "/hw/"}
}

func list(body map[string]any, key string) []map[string]any {
	raw, _ := body[key].([]any)
	out := make([]map[string]any, 0, len(raw))
	for _, item := range raw {
		out = append(out, item.(map[string]any))
	}
	return out
}

// The whole MVP loop: phases from the template, parts, BOM release, a build
// with units, a test, an ECO through both reviews into BOM rev B, a gate,
// and the firmware link — each step with its role rules.
func TestHardwareProjectLifecycle(t *testing.T) {
	w := newHWWorld(t)

	// Phases come from the group's template; the first one is running.
	phases := list(w.must(t, 200, "GET", "phases", "hw-ee", nil), "phases")
	if len(phases) != 5 || phases[0]["name"] != "Proto" || phases[0]["status"] != "in_progress" ||
		phases[1]["status"] != "not_started" {
		t.Fatalf("seeded phases: %v", phases)
	}

	// Parts: engineers add them; prices are hidden from the technician.
	w.must(t, 403, "POST", "parts", "hw-tech", map[string]any{"part_number": "R-10K", "description": "10k"})
	r10k := w.must(t, 201, "POST", "parts", "hw-ee", map[string]any{
		"part_number": "R-10K", "description": "Resistor 10k 0402", "unit_cost_cents": 2,
	})["part"].(map[string]any)
	mcu := w.must(t, 201, "POST", "parts", "hw-ee", map[string]any{
		"part_number": "MCU-1", "description": "MCU", "unit_cost_cents": 350,
	})["part"].(map[string]any)
	mcuB := w.must(t, 201, "POST", "parts", "hw-ee", map[string]any{
		"part_number": "MCU-1", "revision": "b", "description": "MCU rev B", "unit_cost_cents": 360,
	})["part"].(map[string]any)
	if mcuB["revision"] != "B" {
		t.Errorf("revision not normalised: %v", mcuB)
	}
	w.must(t, 409, "POST", "parts", "hw-ee", map[string]any{"part_number": "MCU-1", "description": "dup"})
	for _, p := range list(w.must(t, 200, "GET", "parts", "hw-tech", nil), "parts") {
		if _, ok := p["unit_cost_cents"]; ok {
			t.Fatal("the technician sees prices")
		}
	}

	// BOM: a draft, lines, release by bom.release only.
	draft := w.must(t, 201, "POST", "bom", "hw-ee", map[string]any{})["bom"].(map[string]any)
	rid := draft["id"].(string)
	if draft["rev"] != "A" {
		t.Fatalf("first rev: %v", draft)
	}
	w.must(t, 409, "POST", "bom", "hw-ee", map[string]any{}) // one draft at a time
	w.must(t, 200, "PUT", "bom/"+rid+"/lines/"+r10k["id"].(string), "hw-ee", map[string]any{"quantity": 12, "ref_designators": "R1-R12"})
	bom := w.must(t, 200, "PUT", "bom/"+rid+"/lines/"+mcu["id"].(string), "hw-ee", map[string]any{"quantity": 1})["bom"].(map[string]any)
	if bom["total_cost_cents"] != float64(12*2+350) {
		t.Errorf("BOM cost: %v", bom["total_cost_cents"])
	}
	w.must(t, 403, "POST", "bom/"+rid+"/release", "hw-ee", map[string]any{})
	w.must(t, 200, "POST", "bom/"+rid+"/release", "hw-lead", map[string]any{"note": "EVT"})
	w.must(t, 409, "PUT", "bom/"+rid+"/lines/"+mcu["id"].(string), "hw-ee", map[string]any{"quantity": 2})

	// A build from the released BOM, with serialized units.
	build := w.must(t, 201, "POST", "builds", "hw-lead", map[string]any{
		"name": "EVT1", "bom_rev_id": rid, "quantity": 3, "phase_id": phases[1]["id"],
	})["build"].(map[string]any)
	bid := build["id"].(string)
	units := list(w.must(t, 200, "POST", "builds/"+bid+"/units", "hw-lead", map[string]any{"count": 3, "prefix": "PB"}), "units")
	if len(units) != 3 || units[0]["serial"] != "PB-001" {
		t.Fatalf("units: %v", units)
	}
	w.must(t, 409, "POST", "builds/"+bid+"/units", "hw-lead", map[string]any{"serials": []string{"PB-X"}})
	unit := units[0]["id"].(string)
	w.must(t, 200, "PATCH", "units/"+unit, "hw-tech", map[string]any{"firmware_version": "v0.3.1"})

	// A test plan, approved by someone else, and a recorded failure.
	plans := list(w.must(t, 200, "POST", "tests", "hw-test", map[string]any{"title": "Power-on", "criteria": "3.3V ±5%"}), "plans")
	plan := plans[0]["id"].(string)
	w.must(t, 403, "POST", "tests/"+plan+"/approve", "hw-test", nil)
	w.must(t, 200, "POST", "tests/"+plan+"/approve", "hw-lead", nil)
	w.must(t, 400, "POST", "units/"+unit+"/results", "hw-tech", map[string]any{"plan_id": plan, "result": "fail"})
	results := list(w.must(t, 200, "POST", "units/"+unit+"/results", "hw-tech",
		map[string]any{"plan_id": plan, "result": "fail", "notes": "3.0V on rail"}), "results")
	if results[0]["firmware_version"] != "v0.3.1" {
		t.Errorf("result lost the firmware: %v", results[0])
	}
	w.must(t, 403, "POST", "units/"+unit+"/results", "hw-client", map[string]any{"plan_id": plan, "result": "pass"})

	// ECO: MCU-1 A → B. The author never approves; two stages.
	eco := w.must(t, 201, "POST", "ecos", "hw-ee", map[string]any{"title": "Swap MCU to rev B", "reason": "rail droop"})["eco"].(map[string]any)
	eid := eco["id"].(string)
	if eco["code"] != "ECO-001" {
		t.Errorf("eco code: %v", eco["code"])
	}
	w.must(t, 409, "POST", "ecos/"+eid+"/submit", "hw-ee", nil) // empty
	w.must(t, 200, "POST", "ecos/"+eid+"/items", "hw-ee", map[string]any{
		"action": "change", "from_part_id": mcu["id"], "to_part_id": mcuB["id"],
	})
	w.must(t, 200, "POST", "ecos/"+eid+"/submit", "hw-ee", nil)
	w.must(t, 403, "POST", "ecos/"+eid+"/review", "hw-ee", map[string]any{"decision": "approve"})
	w.must(t, 403, "POST", "ecos/"+eid+"/review", "hw-test", map[string]any{"decision": "approve"}) // not design
	w.must(t, 200, "POST", "ecos/"+eid+"/review", "hw-fw", map[string]any{"decision": "approve"})
	w.must(t, 403, "POST", "ecos/"+eid+"/review", "hw-fw", map[string]any{"decision": "approve"}) // not production
	w.must(t, 200, "POST", "ecos/"+eid+"/review", "hw-test", map[string]any{"decision": "approve"})
	w.must(t, 403, "POST", "ecos/"+eid+"/release", "hw-ee", nil)
	released := w.must(t, 200, "POST", "ecos/"+eid+"/release", "hw-lead", nil)["eco"].(map[string]any)
	if released["status"] != "released" || released["bom_rev_id"] == nil {
		t.Fatalf("eco after release: %v", released)
	}
	revB := w.must(t, 200, "GET", "bom/"+released["bom_rev_id"].(string), "hw-ee", nil)["bom"].(map[string]any)
	if revB["rev"] != "B" || revB["status"] != "released" {
		t.Fatalf("rev B: %v", revB)
	}
	for _, line := range list(revB, "lines") {
		if line["part_number"] == "MCU-1" && line["revision"] != "B" {
			t.Errorf("rev B still has MCU rev %v", line["revision"])
		}
	}

	// Rejecting needs a reason; a rejected change reopens as a draft.
	eco2 := w.must(t, 201, "POST", "ecos", "hw-ee", map[string]any{"title": "Drop R-10K"})["eco"].(map[string]any)
	e2 := eco2["id"].(string)
	w.must(t, 200, "POST", "ecos/"+e2+"/items", "hw-ee", map[string]any{"action": "remove", "from_part_id": r10k["id"]})
	w.must(t, 200, "POST", "ecos/"+e2+"/submit", "hw-ee", nil)
	w.must(t, 400, "POST", "ecos/"+e2+"/review", "hw-fw", map[string]any{"decision": "reject"})
	w.must(t, 200, "POST", "ecos/"+e2+"/review", "hw-fw", map[string]any{"decision": "reject", "comment": "needed for pull-up"})
	if got := w.must(t, 200, "POST", "ecos/"+e2+"/reopen", "hw-ee", nil)["eco"].(map[string]any); got["status"] != "draft" {
		t.Errorf("reopen: %v", got["status"])
	}
	// A technician files an ECR (no BOM change).
	w.must(t, 403, "POST", "ecos", "hw-tech", map[string]any{"title": "x"})
	w.must(t, 201, "POST", "ecos", "hw-tech", map[string]any{"kind": "ecr", "title": "Connector cracks"})

	// Gates: only gate.decide; Go starts the next phase.
	w.must(t, 403, "POST", "phases/"+phases[0]["id"].(string)+"/gate", "hw-ee", map[string]any{"decision": "go"})
	phases = list(w.must(t, 200, "POST", "phases/"+phases[0]["id"].(string)+"/gate", "hw-lead",
		map[string]any{"decision": "go", "note": "works-like ok"}), "phases")
	if phases[0]["status"] != "passed" || phases[1]["status"] != "in_progress" {
		t.Fatalf("after go: %v %v", phases[0]["status"], phases[1]["status"])
	}
	w.must(t, 409, "POST", "phases/"+phases[0]["id"].(string)+"/gate", "hw-lead", map[string]any{"decision": "go"})
	phases = list(w.must(t, 200, "POST", "phases/"+phases[1]["id"].(string)+"/gate", "hw-lead",
		map[string]any{"decision": "recycle"}), "phases")
	if phases[1]["status"] != "in_progress" || len(phases[1]["decisions"].([]any)) != 1 {
		t.Errorf("recycle: %v", phases[1])
	}
	w.must(t, 200, "PATCH", "phases/"+phases[1]["id"].(string), "hw-ee", map[string]any{"check": map[string]any{"index": 0, "done": true}})

	// Firmware ↔ hardware.
	w.must(t, 403, "POST", "firmware", "hw-test", map[string]any{"firmware_tag": "v0.4.0", "bom_rev_id": revB["id"]})
	w.must(t, 404, "POST", "firmware", "hw-fw", map[string]any{"firmware_tag": "v0.4.0", "bom_rev_id": "nope"})
	links := list(w.must(t, 200, "POST", "firmware", "hw-fw", map[string]any{"firmware_tag": "v0.4.0", "bom_rev_id": revB["id"]}), "links")
	if len(links) != 1 || links[0]["bom_rev"] != "B" {
		t.Errorf("firmware links: %v", links)
	}

	// The client reads the overview and touches nothing.
	overview := w.must(t, 200, "GET", "overview", "hw-client", nil)
	if overview["current_phase_id"] != phases[1]["id"] || overview["bom"].(map[string]any)["released"] != "B" {
		t.Errorf("overview: %v", overview)
	}
	w.must(t, 403, "POST", "bom", "hw-client", map[string]any{})
}

// Ids from another project never resolve, software groups have no hardware
// endpoints, and outsiders / private projects stay hidden.
func TestHardwareIsolation(t *testing.T) {
	w := newHWWorld(t)
	other := w.must(t, 201, "POST", "parts", "hw-ee", map[string]any{"part_number": "X", "description": "x"})["part"].(map[string]any)

	_, second := w.h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "hw-lead", w.ws,
		map[string]any{"name": "PB-2", "group_id": w.gid})
	pid2 := second["project"].(map[string]any)["id"].(string)
	w2 := *w
	w2.pid = pid2
	w2.base = "/v1/groups/" + w.gid + "/projects/" + pid2 + "/hw/"
	draft := w2.must(t, 201, "POST", "bom", "hw-ee", map[string]any{})["bom"].(map[string]any)
	w2.must(t, 404, "PUT", "bom/"+draft["id"].(string)+"/lines/"+other["id"].(string), "hw-ee", map[string]any{"quantity": 1})
	w.must(t, 404, "GET", "bom/"+draft["id"].(string), "hw-ee", nil)

	// A software group has no hardware screens.
	_, sw := createGroup(t, w.h, "hw-lead", w.ws, "App", "software")
	swID := groupIDOf(t, sw)
	_, swProject := w.h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "hw-lead", w.ws,
		map[string]any{"name": "App", "group_id": swID})
	status, _ := w.h.doWithWorkspace(t, http.MethodGet,
		"/v1/groups/"+swID+"/projects/"+swProject["project"].(map[string]any)["id"].(string)+"/hw/overview",
		"hw-lead", w.ws, nil)
	if status != http.StatusConflict {
		t.Errorf("software overview: %d, want 409", status)
	}

	// A private project hides its hardware from members outside it.
	w.h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+w.gid+"/projects/"+w.pid, "hw-lead", w.ws,
		map[string]any{"visibility": "private"})
	w.must(t, 404, "GET", "parts", "hw-ee", nil)
	w.h.doWithWorkspace(t, http.MethodPut, "/v1/groups/"+w.gid+"/projects/"+w.pid+"/members/hw-ee", "hw-lead", w.ws,
		map[string]any{"access": "read"})
	w.must(t, 200, "GET", "parts", "hw-ee", nil)
	w.must(t, 403, "POST", "parts", "hw-ee", map[string]any{"part_number": "Y", "description": "y"})
}

// The template is the group's; edits reach phases that have not started.
func TestPhaseTemplates(t *testing.T) {
	w := newHWWorld(t)
	base := "/v1/groups/" + w.gid + "/phases"
	status, body := w.h.doWithWorkspace(t, http.MethodGet, base, "hw-ee", w.ws, nil)
	templates := list(body, "phases")
	if status != 200 || len(templates) != 5 || body["can_manage"] != false {
		t.Fatalf("templates: %d %v", status, body)
	}
	if status, _ := w.h.doWithWorkspace(t, http.MethodPost, base, "hw-ee", w.ws, map[string]any{"name": "X"}); status != 403 {
		t.Errorf("engineer edits the template: %d", status)
	}
	// Rename DVT (not started) and Proto (running): only DVT follows.
	byName := map[string]string{}
	for _, tp := range templates {
		byName[tp["name"].(string)] = tp["id"].(string)
	}
	w.h.doWithWorkspace(t, http.MethodPatch, base+"/"+byName["DVT"], "hw-lead", w.ws, map[string]any{"name": "DVT-A"})
	w.h.doWithWorkspace(t, http.MethodPatch, base+"/"+byName["Proto"], "hw-lead", w.ws, map[string]any{"name": "Prototype"})
	if status, _ := w.h.doWithWorkspace(t, http.MethodPost, base, "hw-lead", w.ws,
		map[string]any{"name": "Sustaining", "checklist": []string{"EOL watch"}}); status != 201 {
		t.Fatalf("add template phase: %d", status)
	}
	names := []string{}
	for _, p := range list(w.must(t, 200, "GET", "phases", "hw-ee", nil), "phases") {
		names = append(names, p["name"].(string))
	}
	want := []string{"Proto", "EVT", "DVT-A", "PVT", "MP", "Sustaining"}
	if len(names) != len(want) {
		t.Fatalf("project phases %v, want %v", names, want)
	}
	for i := range want {
		if names[i] != want[i] {
			t.Fatalf("project phases %v, want %v", names, want)
		}
	}
	// Archive then restore: the not-started copy leaves and comes back.
	w.h.doWithWorkspace(t, http.MethodPatch, base+"/"+byName["PVT"], "hw-lead", w.ws, map[string]any{"archived": true})
	if got := list(w.must(t, 200, "GET", "phases", "hw-ee", nil), "phases"); len(got) != 5 {
		t.Fatalf("after archiving PVT: %d phases", len(got))
	}
	w.h.doWithWorkspace(t, http.MethodPatch, base+"/"+byName["PVT"], "hw-lead", w.ws, map[string]any{"archived": false})
	if got := list(w.must(t, 200, "GET", "phases", "hw-ee", nil), "phases"); len(got) != 6 || got[5]["name"] != "PVT" {
		t.Fatalf("after restoring PVT: %v", got)
	}

	// A project made now gets the new template.
	_, project := w.h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "hw-lead", w.ws,
		map[string]any{"name": "PB-3", "group_id": w.gid})
	pid := project["project"].(map[string]any)["id"].(string)
	_, fresh := w.h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+w.gid+"/projects/"+pid+"/hw/phases", "hw-lead", w.ws, nil)
	if got := list(fresh, "phases"); len(got) != 6 || got[0]["name"] != "Prototype" {
		t.Errorf("new project phases: %v", got)
	}
}

// Regressions from the phase 4a review.
func TestHardwareReviewFixes(t *testing.T) {
	w := newHWWorld(t)
	phases := list(w.must(t, 200, "GET", "phases", "hw-lead", nil), "phases")
	w.must(t, 200, "POST", "phases/"+phases[0]["id"].(string)+"/gate", "hw-lead",
		map[string]any{"decision": "go", "note": "internal note"})

	// The client sees progress only, and no names or notes.
	w.must(t, 403, "GET", "parts", "hw-client", nil)
	w.must(t, 403, "GET", "ecos", "hw-client", nil)
	overview := w.must(t, 200, "GET", "overview", "hw-client", nil)
	for _, p := range list(overview, "phases") {
		for _, raw := range p["decisions"].([]any) {
			d := raw.(map[string]any)
			if _, ok := d["by"]; ok {
				t.Error("the client sees who decided a gate")
			}
			if _, ok := d["note"]; ok {
				t.Error("the client sees gate notes")
			}
		}
	}

	// Ticking a phase that has not started is refused (the template owns it).
	w.must(t, 409, "PATCH", "phases/"+phases[2]["id"].(string), "hw-ee",
		map[string]any{"check": map[string]any{"index": 0, "done": true}})

	// Only the author edits an ECO; another engineer cannot slip items in.
	part := w.must(t, 201, "POST", "parts", "hw-ee", map[string]any{"part_number": "C1", "description": "cap"})["part"].(map[string]any)
	eco := w.must(t, 201, "POST", "ecos", "hw-ee", map[string]any{"title": "Add C1"})["eco"].(map[string]any)
	eid := eco["id"].(string)
	w.must(t, 403, "POST", "ecos/"+eid+"/items", "hw-fw", map[string]any{"action": "add", "to_part_id": part["id"]})
	w.must(t, 200, "POST", "ecos/"+eid+"/items", "hw-ee", map[string]any{"action": "add", "to_part_id": part["id"]})
	// A read-only override stops the author too.
	w.h.doWithWorkspace(t, http.MethodPut, "/v1/groups/"+w.gid+"/projects/"+w.pid+"/members/hw-ee", "hw-lead", w.ws,
		map[string]any{"access": "read"})
	w.must(t, 403, "POST", "ecos/"+eid+"/submit", "hw-ee", nil)
	w.must(t, 403, "POST", "ecos/"+eid+"/cancel", "hw-ee", nil)
	w.h.doWithWorkspace(t, http.MethodDelete, "/v1/groups/"+w.gid+"/projects/"+w.pid+"/members/hw-ee", "hw-lead", w.ws, nil)

	// Unit status by hand is the build manager's; clearing a field works.
	draft := w.must(t, 201, "POST", "bom", "hw-ee", map[string]any{})["bom"].(map[string]any)
	w.must(t, 200, "PUT", "bom/"+draft["id"].(string)+"/lines/"+part["id"].(string), "hw-ee", map[string]any{"quantity": 1})
	w.must(t, 200, "POST", "bom/"+draft["id"].(string)+"/release", "hw-lead", nil)
	w.must(t, 409, "POST", "bom/"+draft["id"].(string)+"/release", "hw-lead", nil)
	b := w.must(t, 201, "POST", "builds", "hw-lead", map[string]any{"name": "EVT1", "bom_rev_id": draft["id"], "quantity": 1, "cm": "ACME"})["build"].(map[string]any)
	units := list(w.must(t, 200, "POST", "builds/"+b["id"].(string)+"/units", "hw-lead", map[string]any{"count": 1, "prefix": "U"}), "units")
	w.must(t, 403, "PATCH", "units/"+units[0]["id"].(string), "hw-tech", map[string]any{"status": "passed"})
	w.must(t, 200, "PATCH", "units/"+units[0]["id"].(string), "hw-tech", map[string]any{"location": "Lab"})
	w.must(t, 200, "PATCH", "units/"+units[0]["id"].(string), "hw-tech", map[string]any{"location": ""})
	got := list(w.must(t, 200, "GET", "builds/"+b["id"].(string)+"/units", "hw-ee", nil), "units")[0]
	if got["location"] != nil {
		t.Errorf("location not cleared: %v", got["location"])
	}
	builds := list(w.must(t, 200, "PATCH", "builds/"+b["id"].(string), "hw-lead", map[string]any{"cm": ""}), "builds")
	if builds[0]["cm"] != nil {
		t.Errorf("cm not cleared: %v", builds[0]["cm"])
	}

	// Go after a template reorder still starts the next phase.
	base := "/v1/groups/" + w.gid + "/phases"
	_, tb := w.h.doWithWorkspace(t, http.MethodGet, base, "hw-lead", w.ws, nil)
	ids := []string{}
	for _, tp := range list(tb, "phases") {
		ids = append(ids, tp["id"].(string))
	}
	// Proto, EVT, DVT, PVT, MP → Proto, EVT, MP, DVT, PVT
	order := []string{ids[0], ids[1], ids[4], ids[2], ids[3]}
	if status, body := w.h.doWithWorkspace(t, http.MethodPut, base+"/order", "hw-lead", w.ws,
		map[string]any{"ids": order}); status != 200 {
		t.Fatalf("reorder: %d %v", status, body)
	}
	evt := list(w.must(t, 200, "GET", "phases", "hw-lead", nil), "phases")[1]
	after := list(w.must(t, 200, "POST", "phases/"+evt["id"].(string)+"/gate", "hw-lead",
		map[string]any{"decision": "go"}), "phases")
	if after[2]["name"] != "MP" || after[2]["status"] != "in_progress" {
		t.Errorf("after go: %v %v", after[2]["name"], after[2]["status"])
	}
}
