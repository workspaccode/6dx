//go:build integration

package api

import (
	"encoding/json"
	"net/http"
	"strings"
	"testing"
)

// doInGroup sends X-Group-Id like the app does for its active group.
func (h *harness) doInGroup(t *testing.T, method, path, uid, workspaceID, groupID string, body any) (int, map[string]any) {
	t.Helper()
	payload := ""
	if body != nil {
		encoded, _ := json.Marshal(body)
		payload = string(encoded)
	}
	request, err := http.NewRequest(method, h.server.URL+path, strings.NewReader(payload))
	if err != nil {
		t.Fatal(err)
	}
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Authorization", "Bearer "+uid)
	request.Header.Set("X-Workspace-Id", workspaceID)
	if groupID != "" {
		request.Header.Set("X-Group-Id", groupID)
	}
	response, err := http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	var out map[string]any
	_ = json.NewDecoder(response.Body).Decode(&out)
	return response.StatusCode, out
}

// The classic screens follow the active group: the snapshot, the project and
// task lists, and new projects all belong to the group in X-Group-Id.
func TestActiveGroupScopesTheClassicScreens(t *testing.T) {
	h := newHarness(t)
	_, me := h.do(t, http.MethodGet, "/v1/me", "ag-lead", nil)
	wsID := workspaceOf(t, me)
	joinAs(t, h, "ag-lead", "ag-outsider", "developer")
	_, created := createGroup(t, h, "ag-lead", wsID, "Mobile App", "software")
	gid := groupIDOf(t, created)
	joinGroupAs(t, h, "ag-lead", wsID, gid, "ag-dev", "member", "developer")

	// A project made from the classic screen while the group is active.
	status, body := h.doInGroup(t, http.MethodPost, "/v1/projects", "ag-lead", wsID, gid,
		map[string]any{"name": "Checkout"})
	if status != http.StatusCreated {
		t.Fatalf("create: %d %v", status, body)
	}
	project := body["project"].(map[string]any)
	if project["group_id"] != gid {
		t.Fatalf("project landed in %v, want the active group %s", project["group_id"], gid)
	}
	_, task := h.doInGroup(t, http.MethodPost, "/v1/tasks", "ag-dev", wsID, gid,
		map[string]any{"title": "Pay button", "project_id": project["id"]})
	taskID := task["task"].(map[string]any)["id"]

	// The group's snapshot: its tasks and its members, with group roles.
	_, snap := h.doInGroup(t, http.MethodGet, "/v1/workspace/snapshot", "ag-dev", wsID, gid, nil)
	if snap["group_id"] != gid {
		t.Fatalf("snapshot group = %v", snap["group_id"])
	}
	found := false
	for _, raw := range snap["tasks"].([]any) {
		if raw.(map[string]any)["id"] == taskID {
			found = true
		}
	}
	if !found {
		t.Error("the group snapshot misses the group's task")
	}
	roles := map[string]string{}
	for _, raw := range snap["members"].([]any) {
		m := raw.(map[string]any)
		roles[m["id"].(string)] = m["role"].(string)
	}
	if roles["ag-lead"] != "owner" || roles["ag-dev"] != "developer" {
		t.Errorf("group member roles: %v", roles)
	}
	if _, ok := roles["ag-outsider"]; ok {
		t.Error("a workspace member outside the group is listed")
	}

	// The default snapshot no longer carries that task.
	_, def := h.doWithWorkspace(t, http.MethodGet, "/v1/workspace/snapshot", "ag-lead", wsID, nil)
	for _, raw := range def["tasks"].([]any) {
		if raw.(map[string]any)["id"] == taskID {
			t.Error("the default snapshot leaks the group's task")
		}
	}

	// An outsider cannot pick the group as active.
	if status, _ := h.doInGroup(t, http.MethodGet, "/v1/workspace/snapshot", "ag-outsider", wsID, gid, nil); status != http.StatusForbidden {
		t.Errorf("outsider snapshot: %d, want 403", status)
	}
	if status, _ := h.doInGroup(t, http.MethodGet, "/v1/tasks", "ag-outsider", wsID, gid, nil); status != http.StatusForbidden {
		t.Errorf("outsider tasks: %d, want 403", status)
	}
}
