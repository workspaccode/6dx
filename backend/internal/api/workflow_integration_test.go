//go:build integration

package api

import (
	"net/http"
	"testing"
)

func statesOf(t *testing.T, body map[string]any) []map[string]any {
	t.Helper()
	raw, ok := body["states"].([]any)
	if !ok {
		t.Fatalf("no states in %v", body)
	}
	out := make([]map[string]any, 0, len(raw))
	for _, s := range raw {
		out = append(out, s.(map[string]any))
	}
	return out
}

func stateNamed(t *testing.T, states []map[string]any, name string) map[string]any {
	t.Helper()
	for _, s := range states {
		if s["name"] == name {
			return s
		}
	}
	t.Fatalf("no state %q in %v", name, states)
	return nil
}

// New groups get the default states (hardware also «متوقف»), managers edit
// them, members only read them, and tasks follow them on both sides: the
// new state_id and the legacy status the classic board reads.
func TestEditableWorkflowStates(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "wf-lead", nil)
	wsID := workspaceOf(t, me)
	_, created := createGroup(t, h, "wf-lead", wsID, "App", "software")
	gid := groupIDOf(t, created)
	joinGroupAs(t, h, "wf-lead", wsID, gid, "wf-dev", "member", "developer")

	_, body := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/workflow", "wf-dev", wsID, nil)
	states := statesOf(t, body)
	if len(states) != 4 || body["can_manage"] != false {
		t.Fatalf("software defaults: %v", body)
	}
	_, hw := createGroup(t, h, "wf-lead", wsID, "Board", "hardware")
	_, body = h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+groupIDOf(t, hw)+"/workflow", "wf-lead", wsID, nil)
	if got := statesOf(t, body); len(got) != 5 || stateNamed(t, got, "متوقف")["category"] != "blocked" {
		t.Fatalf("hardware defaults: %v", body)
	}

	// A developer cannot change the workflow.
	if status, _ := h.doWithWorkspace(t, http.MethodPost, "/v1/groups/"+gid+"/workflow", "wf-dev", wsID,
		map[string]any{"name": "QA", "category": "active"}); status != http.StatusForbidden {
		t.Fatalf("developer add state: %d, want 403", status)
	}
	// Validation.
	for _, bad := range []map[string]any{
		{"name": "", "category": "active"},
		{"name": "X", "category": "nope"},
		{"name": "X", "category": "active", "color": "red"},
		{"name": "للتنفيذ", "category": "backlog"}, // duplicate name
	} {
		if status, _ := h.doWithWorkspace(t, http.MethodPost, "/v1/groups/"+gid+"/workflow", "wf-lead", wsID, bad); status < 400 {
			t.Errorf("accepted %v", bad)
		}
	}
	status, body := h.doWithWorkspace(t, http.MethodPost, "/v1/groups/"+gid+"/workflow", "wf-lead", wsID,
		map[string]any{"name": "QA", "category": "active", "color": "#7c3aed"})
	if status != http.StatusCreated {
		t.Fatalf("add QA: %d %v", status, body)
	}
	qa := stateNamed(t, statesOf(t, body), "QA")
	if qa["legacy_status"] != "in_progress" || qa["color"] != "#7C3AED" {
		t.Fatalf("QA state: %v", qa)
	}

	// A task starts in the first backlog state and moves by state id.
	_, project := h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "wf-lead", wsID,
		map[string]any{"name": "Shop", "group_id": gid})
	projectID := project["project"].(map[string]any)["id"].(string)
	_, task := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks", "wf-dev", wsID,
		map[string]any{"title": "Cart", "project_id": projectID})
	tk := task["task"].(map[string]any)
	if tk["state_id"] != gid+":todo" || tk["status"] != "todo" {
		t.Fatalf("new task state: %v", tk)
	}
	taskID := tk["id"].(string)
	status, body = h.doWithWorkspace(t, http.MethodPatch, "/v1/tasks/"+taskID+"/status", "wf-dev", wsID,
		map[string]any{"state_id": qa["id"]})
	if status != http.StatusOK {
		t.Fatalf("move to QA: %d %v", status, body)
	}
	if got := body["task"].(map[string]any); got["state_id"] != qa["id"] || got["status"] != "in_progress" {
		t.Fatalf("after QA move: %v", got)
	}
	// The classic board sets a status only: the state follows.
	_, body = h.doWithWorkspace(t, http.MethodPatch, "/v1/tasks/"+taskID+"/status", "wf-dev", wsID,
		map[string]any{"status": "review"})
	if got := body["task"].(map[string]any); got["state_id"] != gid+":review" {
		t.Fatalf("legacy move left state at %v", got["state_id"])
	}
	// Another group's state is refused.
	_, other := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+groupIDOf(t, hw)+"/workflow", "wf-lead", wsID, nil)
	foreign := statesOf(t, other)[0]["id"]
	if status, _ := h.doWithWorkspace(t, http.MethodPatch, "/v1/tasks/"+taskID+"/status", "wf-dev", wsID,
		map[string]any{"state_id": foreign}); status != http.StatusBadRequest {
		t.Errorf("foreign state: %d, want 400", status)
	}

	// A state holding tasks cannot be archived; the core states stay.
	review := gid + ":review"
	if status, _ := h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+gid+"/workflow/"+review, "wf-lead", wsID,
		map[string]any{"archived": true}); status != http.StatusConflict {
		t.Errorf("archive busy state: %d, want 409", status)
	}
	if status, _ := h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+gid+"/workflow/"+gid+":done", "wf-lead", wsID,
		map[string]any{"category": "active"}); status != http.StatusConflict {
		t.Errorf("removing the last done state: %d, want 409", status)
	}
	// The classic board keeps a state per column: the only «review» state
	// can be renamed, not recategorised away.
	if status, body := h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+gid+"/workflow/"+review, "wf-lead", wsID,
		map[string]any{"category": "done"}); status != http.StatusConflict || body["error"] == nil {
		t.Errorf("recategorising the last review state: %d %v", status, body)
	}
	if status, _ := h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+gid+"/workflow/"+review, "wf-lead", wsID,
		map[string]any{"name": "معتمد"}); status != http.StatusOK {
		t.Errorf("rename review: %d", status)
	}
	// Recategorising moves its tasks' legacy status with it.
	h.doWithWorkspace(t, http.MethodPatch, "/v1/tasks/"+taskID+"/status", "wf-dev", wsID,
		map[string]any{"state_id": qa["id"]})
	status, body = h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+gid+"/workflow/"+qa["id"].(string), "wf-lead", wsID,
		map[string]any{"category": "done"})
	if status != http.StatusOK {
		t.Fatalf("recategorise: %d %v", status, body)
	}
	_, list := h.doWithWorkspace(t, http.MethodGet, "/v1/tasks?group_id="+gid, "wf-dev", wsID, nil)
	got := list["tasks"].([]any)[0].(map[string]any)
	if got["status"] != "done" || got["state_id"] != qa["id"] {
		t.Fatalf("task after recategorise: %v", got)
	}

	// Reorder: every live state, once.
	live := []string{}
	for _, s := range statesOf(t, body) {
		if s["archived"] == false {
			live = append([]string{s["id"].(string)}, live...)
		}
	}
	if status, body := h.doWithWorkspace(t, http.MethodPut, "/v1/groups/"+gid+"/workflow/order", "wf-lead", wsID,
		map[string]any{"ids": live}); status != http.StatusOK || statesOf(t, body)[0]["id"] != live[0] {
		t.Fatalf("reorder: %d %v", status, body)
	}
	if status, _ := h.doWithWorkspace(t, http.MethodPut, "/v1/groups/"+gid+"/workflow/order", "wf-lead", wsID,
		map[string]any{"ids": live[:2]}); status != http.StatusBadRequest {
		t.Errorf("partial reorder: %d, want 400", status)
	}
	// An empty state archives; restoring it next to a same-name state fails.
	_, added := h.doWithWorkspace(t, http.MethodPost, "/v1/groups/"+gid+"/workflow", "wf-lead", wsID,
		map[string]any{"name": "Spare", "category": "blocked"})
	spare := stateNamed(t, statesOf(t, added), "Spare")["id"].(string)
	if status, body := h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+gid+"/workflow/"+spare, "wf-lead", wsID,
		map[string]any{"archived": true}); status != http.StatusOK {
		t.Fatalf("archive Spare: %d %v", status, body)
	}
	h.doWithWorkspace(t, http.MethodPost, "/v1/groups/"+gid+"/workflow", "wf-lead", wsID,
		map[string]any{"name": "spare", "category": "active"})
	if status, _ := h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+gid+"/workflow/"+spare, "wf-lead", wsID,
		map[string]any{"archived": false}); status != http.StatusConflict {
		t.Errorf("restore with a taken name: %d, want 409", status)
	}

	// The snapshot carries the group's states for the board.
	_, snap := h.doInGroup(t, http.MethodGet, "/v1/workspace/snapshot", "wf-dev", wsID, gid, nil)
	if len(snap["workflow_states"].([]any)) != 7 {
		t.Errorf("snapshot states: %v", snap["workflow_states"])
	}
}

// A private project is visible to the group's managers and its own members
// only — in the project list, the task list, the snapshot and the home.
// A read override makes a member read-only on one project.
func TestPrivateProjectsAndOverrides(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "pp-lead", nil)
	wsID := workspaceOf(t, me)
	_, created := createGroup(t, h, "pp-lead", wsID, "Firmware", "software")
	gid := groupIDOf(t, created)
	joinGroupAs(t, h, "pp-lead", wsID, gid, "pp-in", "member", "developer")
	joinGroupAs(t, h, "pp-lead", wsID, gid, "pp-out", "member", "developer")

	_, project := h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "pp-lead", wsID,
		map[string]any{"name": "Secret", "group_id": gid})
	pid := project["project"].(map[string]any)["id"].(string)
	_, task := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks", "pp-in", wsID,
		map[string]any{"title": "Bootloader", "project_id": pid})
	taskID := task["task"].(map[string]any)["id"].(string)

	if status, _ := h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+gid+"/projects/"+pid, "pp-in", wsID,
		map[string]any{"visibility": "private"}); status != http.StatusForbidden {
		t.Fatalf("developer made it private: %d", status)
	}
	if status, body := h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+gid+"/projects/"+pid, "pp-lead", wsID,
		map[string]any{"visibility": "private"}); status != http.StatusOK {
		t.Fatalf("make private: %d %v", status, body)
	}
	if status, body := h.doWithWorkspace(t, http.MethodPut, "/v1/groups/"+gid+"/projects/"+pid+"/members/pp-in", "pp-lead", wsID,
		map[string]any{"access": "edit"}); status != http.StatusOK {
		t.Fatalf("add project member: %d %v", status, body)
	}
	// Outsiders to the group cannot be added to a project.
	if status, _ := h.doWithWorkspace(t, http.MethodPut, "/v1/groups/"+gid+"/projects/"+pid+"/members/nobody", "pp-lead", wsID,
		map[string]any{"access": "edit"}); status != http.StatusNotFound {
		t.Errorf("non-member override: %d, want 404", status)
	}

	seen := func(uid string) (projects, tasks, snap, home int) {
		_, p := h.doWithWorkspace(t, http.MethodGet, "/v1/projects?group_id="+gid, uid, wsID, nil)
		_, ts := h.doWithWorkspace(t, http.MethodGet, "/v1/tasks?group_id="+gid, uid, wsID, nil)
		_, s := h.doInGroup(t, http.MethodGet, "/v1/workspace/snapshot", uid, wsID, gid, nil)
		_, hm := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/home", uid, wsID, nil)
		return len(p["projects"].([]any)), len(ts["tasks"].([]any)), len(s["tasks"].([]any)),
			len(hm["projects"].([]any))
	}
	for _, uid := range []string{"pp-lead", "pp-in"} {
		if p, ts, s, hm := seen(uid); p != 1 || ts != 1 || s != 1 || hm != 1 {
			t.Errorf("%s sees projects=%d tasks=%d snapshot=%d home=%d, want 1 each", uid, p, ts, s, hm)
		}
	}
	if p, ts, s, hm := seen("pp-out"); p != 0 || ts != 0 || s != 0 || hm != 0 {
		t.Errorf("pp-out sees the private project: projects=%d tasks=%d snapshot=%d home=%d", p, ts, s, hm)
	}
	if status, _ := h.doWithWorkspace(t, http.MethodPatch, "/v1/tasks/"+taskID+"/status", "pp-out", wsID,
		map[string]any{"status": "done"}); status != http.StatusNotFound {
		t.Errorf("pp-out edits a private task: %d, want 404", status)
	}
	if status, _ := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/projects/"+pid+"/me", "pp-out", wsID, nil); status != http.StatusNotFound {
		t.Errorf("pp-out project me: %d, want 404", status)
	}

	// A tech lead with an override (projects.manage, not a manager) cannot
	// open the project up.
	joinGroupAs(t, h, "pp-lead", wsID, gid, "pp-tl", "member", "tech_lead")
	h.doWithWorkspace(t, http.MethodPut, "/v1/groups/"+gid+"/projects/"+pid+"/members/pp-tl", "pp-lead", wsID,
		map[string]any{"access": "edit"})
	if status, _ := h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+gid+"/projects/"+pid, "pp-tl", wsID,
		map[string]any{"visibility": "group"}); status != http.StatusForbidden {
		t.Errorf("tech lead opened the private project: %d, want 403", status)
	}
	if status, _ := h.doWithWorkspace(t, http.MethodPut, "/v1/groups/"+gid+"/projects/"+pid+"/members/pp-out", "pp-tl", wsID,
		map[string]any{"access": "edit"}); status != http.StatusForbidden {
		t.Errorf("tech lead added an override: %d, want 403", status)
	}

	// Read-only override: pp-in keeps seeing it but cannot edit.
	h.doWithWorkspace(t, http.MethodPut, "/v1/groups/"+gid+"/projects/"+pid+"/members/pp-in", "pp-lead", wsID,
		map[string]any{"access": "read"})
	if status, _ := h.doWithWorkspace(t, http.MethodPatch, "/v1/tasks/"+taskID+"/status", "pp-in", wsID,
		map[string]any{"status": "done"}); status != http.StatusForbidden {
		t.Errorf("read override edits: %d, want 403", status)
	}
	_, pm := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/projects/"+pid+"/me", "pp-in", wsID, nil)
	if caps := capsOf(t, map[string]any{"group": pm["project"]}); caps["tasks.edit"] {
		t.Errorf("read override still has tasks.edit: %v", pm)
	}

	// Leaving the group drops the override (and the private access).
	h.doWithWorkspace(t, http.MethodDelete, "/v1/groups/"+gid+"/members/pp-in", "pp-in", wsID, nil)
	_, list := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/projects/"+pid+"/members", "pp-lead", wsID, nil)
	for _, raw := range list["members"].([]any) {
		if raw.(map[string]any)["uid"] == "pp-in" {
			t.Errorf("override survived leaving the group: %v", list)
		}
	}
}

// The home shows what the role needs: managers get the team block, members
// their own tasks, guests only progress.
func TestGroupHomeByRole(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "hm-lead", nil)
	wsID := workspaceOf(t, me)
	_, created := createGroup(t, h, "hm-lead", wsID, "Web", "software")
	gid := groupIDOf(t, created)
	joinGroupAs(t, h, "hm-lead", wsID, gid, "hm-dev", "member", "developer")
	joinGroupAs(t, h, "hm-lead", wsID, gid, "hm-client", "guest", "client")
	_, project := h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "hm-lead", wsID,
		map[string]any{"name": "Site", "group_id": gid})
	pid := project["project"].(map[string]any)["id"]
	h.doWithWorkspace(t, http.MethodPost, "/v1/tasks", "hm-dev", wsID, map[string]any{"title": "A", "project_id": pid})
	h.doWithWorkspace(t, http.MethodPost, "/v1/tasks", "hm-dev", wsID, map[string]any{"title": "B", "project_id": pid})

	_, lead := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/home", "hm-lead", wsID, nil)
	team, ok := lead["team"].(map[string]any)
	if !ok || team["members"] != float64(3) || team["unassigned"] != float64(2) {
		t.Fatalf("lead home team: %v", lead)
	}
	if lead["counts"].(map[string]any)["backlog"] != float64(2) {
		t.Errorf("lead counts: %v", lead["counts"])
	}

	_, dev := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/home", "hm-dev", wsID, nil)
	if _, ok := dev["team"]; ok {
		t.Error("a developer gets the team block")
	}
	if _, ok := dev["my_tasks"].([]any); !ok {
		t.Errorf("developer home has no my_tasks: %v", dev)
	}

	_, guest := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/home", "hm-client", wsID, nil)
	if _, ok := guest["my_tasks"]; ok {
		t.Error("a guest gets my_tasks")
	}
	if _, ok := guest["team"]; ok {
		t.Error("a guest gets the team block")
	}
	if p := guest["projects"].([]any); len(p) != 1 || p[0].(map[string]any)["open_tasks"] != float64(2) {
		t.Errorf("guest progress: %v", guest["projects"])
	}
}
