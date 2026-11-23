//go:build integration

// Groups, roles, capabilities and plan limits — docs/design/groups-and-roles.md.
package api

import (
	"context"
	"net/http"
	"strconv"
	"strings"
	"testing"
)

func capsOf(t *testing.T, body map[string]any) map[string]bool {
	t.Helper()
	group, ok := body["group"].(map[string]any)
	if !ok {
		t.Fatalf("no group in %v", body)
	}
	out := map[string]bool{}
	for _, c := range group["capabilities"].([]any) {
		out[c.(string)] = true
	}
	return out
}

func groupIDOf(t *testing.T, body map[string]any) string {
	t.Helper()
	group, ok := body["group"].(map[string]any)
	if !ok {
		t.Fatalf("no group in %v", body)
	}
	return group["id"].(string)
}

func createGroup(t *testing.T, h *harness, uid, wsID, name, kind string) (int, map[string]any) {
	t.Helper()
	return h.doWithWorkspace(t, http.MethodPost, "/v1/groups", uid, wsID,
		map[string]any{"name": name, "type": kind})
}

// joinGroupAs invites uid to gid with the given roles and accepts it.
func joinGroupAs(t *testing.T, h *harness, lead, wsID, gid, uid, groupRole, functional string) {
	t.Helper()
	status, body := h.doWithWorkspace(t, http.MethodPost, "/v1/groups/"+gid+"/invites", lead, wsID,
		map[string]any{"emails": []string{uid + "@6dx.test"}, "group_role": groupRole,
			"functional_role": functional})
	if status != http.StatusCreated {
		t.Fatalf("group invite %s: %d %v", uid, status, body)
	}
	h.do(t, http.MethodGet, "/v1/me", uid, nil)
	status, body = h.do(t, http.MethodPost, "/v1/invites/accept", uid, nil)
	if status != http.StatusOK || body["group_id"] != gid {
		t.Fatalf("accept %s: %d %v", uid, status, body)
	}
}

func TestFirstSignInCreatesTheDefaultGroup(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "g-owner", nil)
	wsID := workspaceOf(t, me)

	status, body := h.doWithWorkspace(t, http.MethodGet, "/v1/groups", "g-owner", wsID, nil)
	if status != http.StatusOK {
		t.Fatalf("list: %d %v", status, body)
	}
	groups := body["groups"].([]any)
	if len(groups) != 1 {
		t.Fatalf("want 1 default group, got %v", groups)
	}
	g := groups[0].(map[string]any)
	if g["is_default"] != true || g["group_role"] != "lead" || g["type"] != "software" {
		t.Fatalf("default group: %v", g)
	}
	plan := body["plan"].(map[string]any)
	if plan["plan"] != "free" || plan["max_groups"].(float64) != 10 || plan["used_groups"].(float64) != 1 {
		t.Fatalf("plan: %v", plan)
	}

	// Legacy project creation lands in the default group.
	_, created := h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "g-owner", wsID,
		map[string]any{"name": "Legacy"})
	project := created["project"].(map[string]any)
	if project["group_id"] != g["id"] {
		t.Fatalf("legacy project group = %v, want %v", project["group_id"], g["id"])
	}
}

func TestPlanLimitsGroupsAndArchivingFreesASlot(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "g-limit", nil)
	wsID := workspaceOf(t, me)

	// The default group is #1; nine more fill the free plan.
	var last string
	for i := 2; i <= 10; i++ {
		status, body := createGroup(t, h, "g-limit", wsID, "G"+strconv.Itoa(i), "hardware")
		if status != http.StatusCreated {
			t.Fatalf("group %d: %d %v", i, status, body)
		}
		last = groupIDOf(t, body)
	}
	status, body := createGroup(t, h, "g-limit", wsID, "G11", "software")
	if status != http.StatusConflict || body["error"] != "group_limit_reached" {
		t.Fatalf("11th group: %d %v, want 409 group_limit_reached", status, body)
	}

	// Archiving frees a slot; un-archiving needs one again.
	if status, body := h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+last, "g-limit", wsID,
		map[string]any{"is_archived": true}); status != http.StatusOK {
		t.Fatalf("archive: %d %v", status, body)
	}
	if status, body := createGroup(t, h, "g-limit", wsID, "G11", "software"); status != http.StatusCreated {
		t.Fatalf("after archive: %d %v", status, body)
	}
	status, body = h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+last, "g-limit", wsID,
		map[string]any{"is_archived": false})
	if status != http.StatusConflict || body["error"] != "group_limit_reached" {
		t.Fatalf("un-archive over the limit: %d %v", status, body)
	}

	// The paid plan raises the limit to 50.
	if _, err := h.database.ExecContext(context.Background(),
		`update workspaces set plan_id = 'pro' where id = ?`, wsID); err != nil {
		t.Fatal(err)
	}
	if status, body := createGroup(t, h, "g-limit", wsID, "G12", "software"); status != http.StatusCreated {
		t.Fatalf("pro plan: %d %v", status, body)
	}
	_, plan := h.doWithWorkspace(t, http.MethodGet, "/v1/workspace/plan", "g-limit", wsID, nil)
	if plan["max_groups"].(float64) != 50 || plan["price_cents_monthly"].(float64) != 6000 {
		t.Fatalf("pro plan usage: %v", plan)
	}
}

func TestHardwareRolesGetTheirCapabilities(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "hw-lead", nil)
	wsID := workspaceOf(t, me)
	_, created := createGroup(t, h, "hw-lead", wsID, "Power Board", "hardware")
	gid := groupIDOf(t, created)

	lead := capsOf(t, created)
	for _, c := range []string{"gate.decide", "bom.release", "members.manage", "group.delete"} {
		if !lead[c] {
			t.Errorf("lead lacks %s", c)
		}
	}

	joinGroupAs(t, h, "hw-lead", wsID, gid, "hw-ee", "member", "electrical")
	joinGroupAs(t, h, "hw-lead", wsID, gid, "hw-tech", "member", "technician")
	joinGroupAs(t, h, "hw-lead", wsID, gid, "hw-client", "guest", "")

	check := func(uid string, want, deny []string) {
		t.Helper()
		status, body := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/me", uid, wsID, nil)
		if status != http.StatusOK {
			t.Fatalf("%s me: %d %v", uid, status, body)
		}
		caps := capsOf(t, body)
		for _, c := range want {
			if !caps[c] {
				t.Errorf("%s lacks %s", uid, c)
			}
		}
		for _, c := range deny {
			if caps[c] {
				t.Errorf("%s must not have %s", uid, c)
			}
		}
	}
	check("hw-ee", []string{"bom.edit", "eco.submit", "eco.approve"},
		[]string{"bom.release", "gate.decide", "members.manage"})
	check("hw-tech", []string{"tests.record", "ecr.submit", "inventory.move"},
		[]string{"eco.submit", "bom.edit", "gate.decide"})
	check("hw-client", []string{"group.view", "comments.write"},
		[]string{"tasks.edit", "bom.edit", "members.manage"})

	// A guest sees names, not the team's e-mails.
	_, members := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/members", "hw-client", wsID, nil)
	for _, raw := range members["members"].([]any) {
		if email := raw.(map[string]any)["email"]; email != nil {
			t.Errorf("guest sees e-mail %v", email)
		}
	}

	// Software roles are not valid in a hardware group.
	status, body := h.doWithWorkspace(t, http.MethodPost, "/v1/groups/"+gid+"/invites", "hw-lead", wsID,
		map[string]any{"emails": []string{"x@6dx.test"}, "functional_role": "developer"})
	if status != http.StatusBadRequest || body["error"] != "invalid_functional_role" {
		t.Errorf("software role in hardware group: %d %v", status, body)
	}
}

func TestGroupRoleRules(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "r-lead", nil)
	wsID := workspaceOf(t, me)
	_, created := createGroup(t, h, "r-lead", wsID, "App", "software")
	gid := groupIDOf(t, created)
	joinGroupAs(t, h, "r-lead", wsID, gid, "r-admin", "admin", "tech_lead")
	joinGroupAs(t, h, "r-lead", wsID, gid, "r-dev", "member", "developer")
	joinGroupAs(t, h, "r-lead", wsID, gid, "r-admin2", "admin", "pm")

	// An assistant manages members but cannot make or remove assistants.
	if status, body := h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+gid+"/members/r-dev",
		"r-admin", wsID, map[string]any{"functional_role": "qa"}); status != http.StatusOK {
		t.Errorf("admin changes a member: %d %v", status, body)
	}
	if status, body := h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+gid+"/members/r-dev",
		"r-admin", wsID, map[string]any{"group_role": "admin"}); status != http.StatusForbidden {
		t.Errorf("admin promotes to admin: %d %v, want 403", status, body)
	}
	if status, body := h.doWithWorkspace(t, http.MethodDelete, "/v1/groups/"+gid+"/members/r-admin2",
		"r-admin", wsID, nil); status != http.StatusForbidden {
		t.Errorf("admin removes admin: %d %v, want 403", status, body)
	}
	if status, body := h.doWithWorkspace(t, http.MethodPost, "/v1/groups/"+gid+"/invites",
		"r-admin", wsID, map[string]any{"emails": []string{"a@6dx.test"}, "group_role": "admin"}); status != http.StatusForbidden {
		t.Errorf("admin invites an admin: %d %v, want 403", status, body)
	}
	// A member cannot manage anyone.
	if status, _ := h.doWithWorkspace(t, http.MethodDelete, "/v1/groups/"+gid+"/members/r-admin",
		"r-dev", wsID, nil); status != http.StatusForbidden {
		t.Errorf("member removes someone: %d, want 403", status)
	}
	// Nobody is made lead by PATCH; the lead cannot leave without a transfer.
	if status, _ := h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+gid+"/members/r-dev",
		"r-lead", wsID, map[string]any{"group_role": "lead"}); status != http.StatusForbidden {
		t.Errorf("PATCH to lead: %d, want 403", status)
	}
	if status, body := h.doWithWorkspace(t, http.MethodDelete, "/v1/groups/"+gid+"/members/r-lead",
		"r-lead", wsID, nil); status != http.StatusConflict || body["error"] != "lead_must_transfer" {
		t.Errorf("lead leaves: %d %v", status, body)
	}

	// Transfer: the new lead leads, the old lead becomes an assistant.
	if status, body := h.doWithWorkspace(t, http.MethodPost, "/v1/groups/"+gid+"/transfer",
		"r-lead", wsID, map[string]any{"uid": "r-admin"}); status != http.StatusOK {
		t.Fatalf("transfer: %d %v", status, body)
	}
	_, mine := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/me", "r-lead", wsID, nil)
	if role := mine["group"].(map[string]any)["group_role"]; role != "admin" {
		t.Errorf("old lead role = %v, want admin", role)
	}
	_, theirs := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/me", "r-admin", wsID, nil)
	if role := theirs["group"].(map[string]any)["group_role"]; role != "lead" {
		t.Errorf("new lead role = %v, want lead", role)
	}

	// Leaving works for everyone but the lead.
	if status, _ := h.doWithWorkspace(t, http.MethodDelete, "/v1/groups/"+gid+"/members/r-dev",
		"r-dev", wsID, nil); status != http.StatusOK {
		t.Errorf("member leaves: %d", status)
	}
}

func TestGroupIsolation(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "iso-owner", nil)
	wsID := workspaceOf(t, me)
	_, created := createGroup(t, h, "iso-owner", wsID, "Secret HW", "hardware")
	gid := groupIDOf(t, created)

	// A workspace developer who is not in the group cannot open it.
	joinAs(t, h, "iso-owner", "iso-dev", "developer")
	if status, body := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/me", "iso-dev", wsID, nil); status != http.StatusForbidden || body["error"] != "not_group_member" {
		t.Errorf("non-member: %d %v", status, body)
	}
	_, list := h.doWithWorkspace(t, http.MethodGet, "/v1/groups", "iso-dev", wsID, nil)
	for _, raw := range list["groups"].([]any) {
		if raw.(map[string]any)["id"] == gid {
			t.Error("a non-member must not see the group in the list")
		}
	}

	// Another workspace cannot reach it at all.
	_, other := h.do(t, http.MethodGet, "/v1/me", "iso-stranger", nil)
	if status, _ := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/me", "iso-stranger",
		workspaceOf(t, other), nil); status != http.StatusNotFound {
		t.Errorf("other workspace: %d, want 404", status)
	}

	// A project cannot be put into a group the caller cannot manage.
	if status, _ := h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "iso-dev", wsID,
		map[string]any{"name": "X", "group_id": gid}); status != http.StatusForbidden {
		t.Errorf("project into foreign group: %d, want 403", status)
	}

	// The workspace owner who left the group can still administer it (no
	// orphaned groups) but gets no operational capability.
	joinGroupAs(t, h, "iso-owner", wsID, gid, "iso-lead2", "member", "electrical")
	h.doWithWorkspace(t, http.MethodPost, "/v1/groups/"+gid+"/transfer", "iso-owner", wsID,
		map[string]any{"uid": "iso-lead2"})
	h.doWithWorkspace(t, http.MethodDelete, "/v1/groups/"+gid+"/members/iso-owner", "iso-owner", wsID, nil)
	status, body := h.doWithWorkspace(t, http.MethodGet, "/v1/groups/"+gid+"/me", "iso-owner", wsID, nil)
	if status != http.StatusOK {
		t.Fatalf("workspace admin view: %d %v", status, body)
	}
	caps := capsOf(t, body)
	if !caps["members.manage"] || caps["bom.release"] || caps["gate.decide"] {
		t.Errorf("workspace admin caps: %v", caps)
	}
}

func TestDeletingGroupsAndRemovingLeads(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "d-owner", nil)
	wsID := workspaceOf(t, me)
	_, list := h.doWithWorkspace(t, http.MethodGet, "/v1/groups", "d-owner", wsID, nil)
	defaultID := list["groups"].([]any)[0].(map[string]any)["id"].(string)

	if status, body := h.doWithWorkspace(t, http.MethodDelete, "/v1/groups/"+defaultID, "d-owner", wsID, nil); status != http.StatusConflict || body["error"] != "default_group_not_deletable" {
		t.Errorf("delete default: %d %v", status, body)
	}

	_, created := createGroup(t, h, "d-owner", wsID, "Temp", "software")
	gid := groupIDOf(t, created)
	h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "d-owner", wsID,
		map[string]any{"name": "Inside", "group_id": gid})
	if status, body := h.doWithWorkspace(t, http.MethodDelete, "/v1/groups/"+gid, "d-owner", wsID, nil); status != http.StatusConflict || body["error"] != "group_has_projects" {
		t.Errorf("delete with projects: %d %v", status, body)
	}

	_, empty := createGroup(t, h, "d-owner", wsID, "Empty", "software")
	if status, _ := h.doWithWorkspace(t, http.MethodDelete, "/v1/groups/"+groupIDOf(t, empty), "d-owner", wsID, nil); status != http.StatusOK {
		t.Errorf("delete empty group: %d", status)
	}

	// Removing someone from the workspace who leads a group is refused.
	joinAs(t, h, "d-owner", "d-dev", "developer")
	_, theirs := createGroup(t, h, "d-dev", wsID, "Dev's group", "software")
	if theirs["group"] == nil {
		t.Fatalf("developer could not create a group: %v", theirs)
	}
	if status, body := h.doWithWorkspace(t, http.MethodDelete, "/v1/members/d-dev", "d-owner", wsID, nil); status != http.StatusConflict || body["error"] != "member_leads_a_group" {
		t.Errorf("remove a group lead: %d %v", status, body)
	}
}

func TestLegacyInviteJoinsTheDefaultGroup(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "l-owner", nil)
	wsID := workspaceOf(t, me)
	joinAs(t, h, "l-owner", "l-reviewer", "reviewer")

	_, list := h.doWithWorkspace(t, http.MethodGet, "/v1/groups", "l-reviewer", wsID, nil)
	groups := list["groups"].([]any)
	if len(groups) != 1 {
		t.Fatalf("reviewer groups: %v", groups)
	}
	g := groups[0].(map[string]any)
	if g["is_default"] != true || g["group_role"] != "member" || g["functional_role"] != "reviewer" {
		t.Fatalf("legacy mapping: %v", g)
	}
}

// The pre-group endpoints show the default group only; a private hardware
// group's projects and tasks are reached through the group, by members.
func TestLegacyEndpointsDoNotLeakOtherGroups(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "s-owner", nil)
	wsID := workspaceOf(t, me)
	joinAs(t, h, "s-owner", "s-dev", "developer")
	_, created := createGroup(t, h, "s-owner", wsID, "Secret HW", "hardware")
	gid := groupIDOf(t, created)

	_, p := h.doWithWorkspace(t, http.MethodPost, "/v1/projects", "s-owner", wsID,
		map[string]any{"name": "Prototype", "group_id": gid})
	projectID := p["project"].(map[string]any)["id"].(string)
	_, task := h.doWithWorkspace(t, http.MethodPost, "/v1/tasks", "s-owner", wsID,
		map[string]any{"title": "Bring-up", "project_id": projectID})
	taskID := task["task"].(map[string]any)["id"].(string)

	contains := func(list []any, id string) bool {
		for _, raw := range list {
			if raw.(map[string]any)["id"] == id {
				return true
			}
		}
		return false
	}

	// The developer (not in the group) sees neither.
	_, projects := h.doWithWorkspace(t, http.MethodGet, "/v1/projects", "s-dev", wsID, nil)
	if contains(projects["projects"].([]any), projectID) {
		t.Error("/v1/projects leaks the hardware project")
	}
	_, tasks := h.doWithWorkspace(t, http.MethodGet, "/v1/tasks", "s-dev", wsID, nil)
	if contains(tasks["tasks"].([]any), taskID) {
		t.Error("/v1/tasks leaks the hardware task")
	}
	_, snap := h.doWithWorkspace(t, http.MethodGet, "/v1/workspace/snapshot", "s-dev", wsID, nil)
	if contains(snap["tasks"].([]any), taskID) {
		t.Error("snapshot leaks the hardware task")
	}
	if status, _ := h.doWithWorkspace(t, http.MethodGet, "/v1/projects?group_id="+gid, "s-dev", wsID, nil); status != http.StatusForbidden {
		t.Errorf("group listing for a non-member: %d, want 403", status)
	}
	// ...and cannot write to the task by id.
	if status, _ := h.doWithWorkspace(t, http.MethodPatch, "/v1/tasks/"+taskID+"/status", "s-dev", wsID,
		map[string]any{"status": "done"}); status != http.StatusNotFound {
		t.Errorf("status change by a non-member: %d, want 404", status)
	}
	if status, _ := h.doWithWorkspace(t, http.MethodDelete, "/v1/tasks/"+taskID, "s-dev", wsID, nil); status != http.StatusNotFound {
		t.Errorf("delete by a non-member: %d, want 404", status)
	}

	// The lead reads the group explicitly.
	_, mine := h.doWithWorkspace(t, http.MethodGet, "/v1/projects?group_id="+gid, "s-owner", wsID, nil)
	if !contains(mine["projects"].([]any), projectID) {
		t.Error("the group listing misses its project")
	}
	_, groupTasks := h.doWithWorkspace(t, http.MethodGet, "/v1/tasks?group_id="+gid, "s-owner", wsID, nil)
	if !contains(groupTasks["tasks"].([]any), taskID) {
		t.Error("the group task listing misses its task")
	}
}

func TestInviteScreenEndpoints(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "v-lead", nil)
	wsID := workspaceOf(t, me)
	_, created := createGroup(t, h, "v-lead", wsID, "Power Board", "hardware")
	gid := groupIDOf(t, created)
	h.doWithWorkspace(t, http.MethodPost, "/v1/groups/"+gid+"/invites", "v-lead", wsID,
		map[string]any{"emails": []string{"v-tech@6dx.test"}, "functional_role": "technician"})

	var inviteID string
	if err := h.database.QueryRowContext(context.Background(),
		`select id from workspace_invites where email = 'v-tech@6dx.test'`).Scan(&inviteID); err != nil {
		t.Fatal(err)
	}

	h.do(t, http.MethodGet, "/v1/me", "v-tech", nil)
	status, body := h.do(t, http.MethodGet, "/v1/invites/"+inviteID, "v-tech", nil)
	if status != http.StatusOK {
		t.Fatalf("get invite: %d %v", status, body)
	}
	invite := body["invite"].(map[string]any)
	if invite["group_name"] != "Power Board" || invite["group_type"] != "hardware" ||
		invite["functional_role"] != "technician" || invite["status"] != "pending" {
		t.Fatalf("invite: %v", invite)
	}

	// Someone else's account sees only the masked address.
	h.do(t, http.MethodGet, "/v1/me", "v-other", nil)
	status, body = h.do(t, http.MethodGet, "/v1/invites/"+inviteID, "v-other", nil)
	if status != http.StatusForbidden || body["error"] != "invite_for_another_email" {
		t.Fatalf("other account: %d %v", status, body)
	}
	if msg, _ := body["message"].(string); msg == "" || strings.Contains(msg, "v-tech@") {
		t.Errorf("address must be masked: %q", msg)
	}
	if status, _ := h.do(t, http.MethodPost, "/v1/invites/"+inviteID+"/decline", "v-other", nil); status != http.StatusNotFound {
		t.Errorf("decline by another account: %d, want 404", status)
	}

	if status, _ := h.do(t, http.MethodPost, "/v1/invites/"+inviteID+"/decline", "v-tech", nil); status != http.StatusOK {
		t.Fatalf("decline: %d", status)
	}
	_, body = h.do(t, http.MethodGet, "/v1/invites/"+inviteID, "v-tech", nil)
	if body["invite"].(map[string]any)["status"] != "revoked" {
		t.Errorf("declined invite status: %v", body)
	}
	if status, _ := h.do(t, http.MethodPost, "/v1/invites/accept", "v-tech",
		map[string]any{"invite_id": inviteID}); status != http.StatusConflict {
		t.Errorf("accept after decline: %d, want 409", status)
	}
}
