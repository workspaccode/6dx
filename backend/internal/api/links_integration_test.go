//go:build integration

package api

import (
	"net/http"
	"testing"
)

// A software project asks a hardware project for a link; the hardware side
// approves; both see a summary of the other (never its BOM, prices or
// members), can tie tasks together, and either side can revoke.
func TestProjectLinks(t *testing.T) {
	hw := newHWWorld(t)
	h, ws := hw.h, hw.ws
	_, sw := createGroup(t, h, "hw-lead", ws, "Mobile App", "software")
	swID := groupIDOf(t, sw)
	joinGroupAs(t, h, "hw-lead", ws, swID, "sw-lead", "admin", "tech_lead")
	joinGroupAs(t, h, "hw-lead", ws, swID, "sw-dev", "member", "developer")
	_, app := h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "sw-lead", ws, map[string]any{"name": "App", "group_id": swID})
	appID := app["project"].(map[string]any)["id"].(string)

	swLinks := "/v1/groups/" + swID + "/projects/" + appID + "/links"
	hwLinks := "/v1/groups/" + hw.gid + "/projects/" + hw.pid + "/links"
	do := func(want int, method, path, uid string, body any) map[string]any {
		t.Helper()
		status, out := h.doWithWorkspace(t, method, path, uid, ws, body)
		if status != want {
			t.Fatalf("%s %s as %s: %d %v (want %d)", method, path, uid, status, out, want)
		}
		return out
	}

	// Only the lead / admins request; candidates never list own-group or
	// private projects.
	do(403, "GET", swLinks+"/candidates", "sw-dev", nil)
	cands := list(do(200, "GET", swLinks+"/candidates", "sw-lead", nil), "projects")
	if len(cands) != 1 || cands[0]["project_id"] != hw.pid {
		t.Fatalf("candidates: %v", cands)
	}
	do(403, "POST", swLinks, "sw-dev", map[string]any{"to_project_id": hw.pid})
	link := do(201, "POST", swLinks, "sw-lead", map[string]any{"to_project_id": hw.pid, "note": "needs firmware"})["link"].(map[string]any)
	lid := link["id"].(string)
	do(409, "POST", swLinks, "sw-lead", map[string]any{"to_project_id": hw.pid})
	do(409, "POST", hwLinks, "hw-lead", map[string]any{"to_project_id": appID}) // same pair, other way

	// The asking side cannot approve itself; the summary waits for approval.
	do(403, "POST", swLinks+"/"+lid+"/approve", "sw-lead", nil)
	do(409, "GET", swLinks+"/"+lid+"/summary", "sw-dev", nil)
	do(403, "POST", hwLinks+"/"+lid+"/approve", "hw-ee", nil)
	do(200, "POST", hwLinks+"/"+lid+"/approve", "hw-lead", nil)

	// Hardware data for the summary.
	part := hw.must(t, 201, "POST", "parts", "hw-ee", map[string]any{"part_number": "MCU", "description": "m", "unit_cost_cents": 999})["part"].(map[string]any)
	draft := hw.must(t, 201, "POST", "bom", "hw-ee", map[string]any{})["bom"].(map[string]any)
	hw.must(t, 200, "PUT", "bom/"+draft["id"].(string)+"/lines/"+part["id"].(string), "hw-ee", map[string]any{"quantity": 1})
	hw.must(t, 200, "POST", "bom/"+draft["id"].(string)+"/release", "hw-lead", nil)
	hw.must(t, 200, "POST", "firmware", "hw-fw", map[string]any{"firmware_tag": "v1.0", "bom_rev_id": draft["id"]})

	sum := do(200, "GET", swLinks+"/"+lid+"/summary", "sw-dev", nil)
	s := sum["summary"].(map[string]any)
	if s["group_type"] != "hardware" || s["released_bom"] != "A" || len(s["phases"].([]any)) != 5 ||
		len(s["firmware"].([]any)) != 1 {
		t.Fatalf("summary: %v", s)
	}
	for _, k := range []string{"parts", "bom", "members", "unit_cost_cents"} {
		if _, ok := s[k]; ok {
			t.Errorf("summary leaks %s", k)
		}
	}
	// The linked side still cannot open the other project.
	if status, _ := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+hw.gid+"/projects/"+hw.pid+"/hw/parts", "sw-dev", ws, nil); status == 200 {
		t.Error("a linked developer reads the hardware parts")
	}

	// Cross-project dependency: my task waits for theirs.
	_, mine := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks", "sw-dev", ws, map[string]any{"title": "BLE pairing", "project_id": appID})
	_, theirs := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks", "hw-ee", ws, map[string]any{"title": "BLE antenna", "project_id": hw.pid})
	mineID := mine["task"].(map[string]any)["id"]
	theirsID := theirs["task"].(map[string]any)["id"]
	tasks := list(do(200, "GET", swLinks+"/"+lid+"/tasks", "sw-dev", nil), "tasks")
	if len(tasks) != 1 || tasks[0]["title"] != "BLE antenna" {
		t.Fatalf("linked tasks: %v", tasks)
	}
	do(404, "POST", swLinks+"/"+lid+"/deps", "sw-dev", map[string]any{"task_id": theirsID, "depends_on": mineID}) // wrong sides
	deps := list(do(201, "POST", swLinks+"/"+lid+"/deps", "sw-dev", map[string]any{"task_id": mineID, "depends_on": theirsID}), "dependencies")
	if len(deps) != 1 {
		t.Fatalf("deps: %v", deps)
	}
	// The hardware side sees it from its own summary.
	hwDeps := list(do(200, "GET", hwLinks+"/"+lid+"/summary", "hw-ee", nil), "dependencies")
	if len(hwDeps) != 1 || hwDeps[0]["depends_on"].(map[string]any)["mine"] != true {
		t.Errorf("hw side deps: %v", hwDeps)
	}
	// Guests (the client) see nothing of links.
	do(403, "GET", hwLinks, "hw-client", nil)

	// Either side revokes; the summary closes.
	do(403, "POST", hwLinks+"/"+lid+"/revoke", "hw-ee", nil)
	do(200, "POST", hwLinks+"/"+lid+"/revoke", "hw-lead", nil)
	do(409, "GET", swLinks+"/"+lid+"/summary", "sw-dev", nil)
	if l := list(do(200, "GET", swLinks, "sw-dev", nil), "links"); len(l) != 0 {
		t.Errorf("revoked link still listed: %v", l)
	}
	// A new request is possible after a revoke.
	do(201, "POST", swLinks, "sw-lead", map[string]any{"to_project_id": hw.pid})

	// A link id never resolves from an unrelated project.
	_, other := h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "sw-lead", ws, map[string]any{"name": "Web", "group_id": swID})
	webLinks := "/v1/groups/" + swID + "/projects/" + other["project"].(map[string]any)["id"].(string) + "/links"
	do(404, "GET", webLinks+"/"+lid+"/summary", "sw-lead", nil)
}

// Regressions from the links review.
func TestProjectLinkReviewFixes(t *testing.T) {
	hw := newHWWorld(t)
	h, ws := hw.h, hw.ws
	_, sw := createGroup(t, h, "hw-lead", ws, "App", "software")
	swID := groupIDOf(t, sw)
	_, app := h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "hw-lead", ws, map[string]any{"name": "App", "group_id": swID})
	appID := app["project"].(map[string]any)["id"].(string)
	swLinks := "/v1/groups/" + swID + "/projects/" + appID + "/links"
	hwLinks := "/v1/groups/" + hw.gid + "/projects/" + hw.pid + "/links"
	do := func(want int, method, path string, body any) map[string]any {
		t.Helper()
		status, out := h.doWithWorkspace(t, method, path, "hw-lead", ws, body)
		if status != want {
			t.Fatalf("%s %s: %d %v (want %d)", method, path, status, out, want)
		}
		return out
	}
	link := func() string {
		t.Helper()
		lid := do(201, "POST", swLinks, map[string]any{"to_project_id": hw.pid})["link"].(map[string]any)["id"].(string)
		do(200, "POST", hwLinks+"/"+lid+"/approve", nil)
		return lid
	}
	_, a := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks", "hw-lead", ws, map[string]any{"title": "a", "project_id": appID})
	_, b := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks", "hw-lead", ws, map[string]any{"title": "b", "project_id": hw.pid})
	dep := map[string]any{"task_id": a["task"].(map[string]any)["id"], "depends_on": b["task"].(map[string]any)["id"]}

	// Revoke, re-link: the same dependency can be added again.
	l1 := link()
	do(201, "POST", swLinks+"/"+l1+"/deps", dep)
	do(200, "POST", swLinks+"/"+l1+"/revoke", nil)
	l2 := link()
	do(201, "POST", swLinks+"/"+l2+"/deps", dep)

	// Making a side private ends its links.
	do(200, "PATCH", "/v1/groups/"+hw.gid+"/projects/"+hw.pid, map[string]any{"visibility": "private"})
	do(409, "GET", swLinks+"/"+l2+"/summary", nil)
	if l := list(do(200, "GET", swLinks, nil), "links"); len(l) != 0 {
		t.Errorf("links survived going private: %v", l)
	}
	// A pending request whose asking side went private cannot be approved.
	do(200, "PATCH", "/v1/groups/"+hw.gid+"/projects/"+hw.pid, map[string]any{"visibility": "group"})
	pending := do(201, "POST", hwLinks, map[string]any{"to_project_id": appID})["link"].(map[string]any)["id"].(string)
	h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+hw.gid+"/projects/"+hw.pid, "hw-lead", ws, map[string]any{"visibility": "private"})
	do(409, "POST", swLinks+"/"+pending+"/approve", nil)
}
