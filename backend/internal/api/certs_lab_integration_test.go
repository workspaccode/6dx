//go:build integration

package api

import (
	"net/http"
	"testing"
	"time"
)

func TestCertifications(t *testing.T) {
	w := newHWWorld(t)
	part := w.must(t, 201, "POST", "parts", "hw-ee", map[string]any{"part_number": "P", "description": "p"})["part"].(map[string]any)
	draft := w.must(t, 201, "POST", "bom", "hw-ee", map[string]any{})["bom"].(map[string]any)
	w.must(t, 200, "PUT", "bom/"+draft["id"].(string)+"/lines/"+part["id"].(string), "hw-ee", map[string]any{"quantity": 1})
	// A draft revision cannot be certified.
	w.must(t, 409, "POST", "certs", "hw-test", map[string]any{"standard": "fcc", "bom_rev_id": draft["id"]})
	w.must(t, 200, "POST", "bom/"+draft["id"].(string)+"/release", "hw-lead", nil)

	w.must(t, 403, "POST", "certs", "hw-ee", map[string]any{"standard": "FCC"})
	certs := list(w.must(t, 201, "POST", "certs", "hw-test", map[string]any{
		"standard": "fcc", "region": "US", "lab": "TÜV", "bom_rev_id": draft["id"], "due_at": "2020-01-01",
		"note": "internal",
	}), "certs")
	c := certs[0]
	if c["standard"] != "FCC" || c["overdue"] != true || c["bom_rev"] != "A" {
		t.Fatalf("cert: %v", c)
	}
	cid := c["id"].(string)
	w.must(t, 400, "PATCH", "certs/"+cid, "hw-test", map[string]any{"status": "passed"})
	w.must(t, 400, "PATCH", "certs/"+cid, "hw-test", map[string]any{"due_at": "next week"})
	soon := time.Now().UTC().AddDate(0, 0, 30).Format("2006-01-02")
	got := list(w.must(t, 200, "PATCH", "certs/"+cid, "hw-test", map[string]any{
		"status": "passed", "certified_at": "2026-01-10", "expires_at": soon, "certificate_number": "FCC-123",
	}), "certs")[0]
	if got["overdue"] != false || got["expiring"] != true || got["certificate_number"] != "FCC-123" {
		t.Errorf("after passing: %v", got)
	}
	// The client follows the certification, without lab or notes.
	g := list(w.must(t, 200, "GET", "certs", "hw-client", nil), "certs")[0]
	if g["status"] != "passed" {
		t.Errorf("client view: %v", g)
	}
	for _, k := range []string{"lab", "note", "bom_rev_id", "certificate_number"} {
		if _, ok := g[k]; ok {
			t.Errorf("client sees %s", k)
		}
	}
	w.must(t, 403, "PATCH", "certs/"+cid, "hw-client", map[string]any{"status": "failed"})
}

func TestLabBooking(t *testing.T) {
	w := newHWWorld(t)
	lab := "/v1/groups/" + w.gid + "/lab"
	do := func(want int, method, path, uid string, body any) map[string]any {
		t.Helper()
		status, out := w.h.doWithWorkspace(t, method, lab+path, uid, w.ws, body)
		if status != want {
			t.Fatalf("%s %s as %s: %d %v (want %d)", method, path, uid, status, out, want)
		}
		return out
	}
	do(403, "POST", "/assets", "hw-ee", map[string]any{"name": "Chamber"})
	assets := list(do(201, "POST", "/assets", "hw-test", map[string]any{"name": "Thermal chamber", "kind": "env"}), "assets")
	aid := assets[0]["id"].(string)
	do(409, "POST", "/assets", "hw-test", map[string]any{"name": "thermal chamber"})
	do(403, "GET", "/assets", "hw-client", nil)

	at := func(h int) string { return time.Now().UTC().Add(time.Duration(h) * time.Hour).Format(time.RFC3339) }
	do(201, "POST", "/bookings", "hw-tech", map[string]any{"asset_id": aid, "starts_at": at(24), "ends_at": at(28),
		"project_id": w.pid, "purpose": "EVT1 soak"})
	// Overlap refused; touching edges allowed; bad ranges refused.
	do(409, "POST", "/bookings", "hw-ee", map[string]any{"asset_id": aid, "starts_at": at(27), "ends_at": at(30)})
	do(201, "POST", "/bookings", "hw-ee", map[string]any{"asset_id": aid, "starts_at": at(28), "ends_at": at(30)})
	do(400, "POST", "/bookings", "hw-ee", map[string]any{"asset_id": aid, "starts_at": at(40), "ends_at": at(39)})
	do(400, "POST", "/bookings", "hw-ee", map[string]any{"asset_id": aid, "starts_at": at(50), "ends_at": at(50 + 15*24)})
	do(400, "POST", "/bookings", "hw-ee", map[string]any{"asset_id": aid, "starts_at": at(-10), "ends_at": at(-5)})
	do(400, "POST", "/bookings", "hw-ee", map[string]any{"asset_id": aid, "starts_at": "tomorrow", "ends_at": at(5)})

	// A private project's booking shows as busy to outsiders.
	w.h.doWithWorkspace(t, http.MethodPatch, "/v1/groups/"+w.gid+"/projects/"+w.pid, "hw-lead", w.ws,
		map[string]any{"visibility": "private"})
	bookings := list(do(200, "GET", "/bookings?asset="+aid, "hw-ee", nil), "bookings")
	if len(bookings) != 2 {
		t.Fatalf("bookings: %v", bookings)
	}
	first := bookings[0]
	if first["private"] != true || first["purpose"] != nil || first["project_id"] != nil {
		t.Errorf("private booking leaks: %v", first)
	}
	if lead := list(do(200, "GET", "/bookings?asset="+aid, "hw-lead", nil), "bookings")[0]; lead["purpose"] != "EVT1 soak" {
		t.Errorf("lead's view: %v", lead)
	}
	// Only the booker or lab.manage cancels.
	do(403, "POST", "/bookings/"+first["id"].(string)+"/cancel", "hw-ee", nil)
	do(200, "POST", "/bookings/"+first["id"].(string)+"/cancel", "hw-tech", nil)
	// Archiving the asset cancels what is left.
	do(200, "PATCH", "/assets/"+aid, "hw-test", map[string]any{"archived": true})
	if b := list(do(200, "GET", "/bookings?asset="+aid, "hw-lead", nil), "bookings"); len(b) != 0 {
		t.Errorf("bookings after archive: %v", b)
	}
	do(409, "POST", "/bookings", "hw-ee", map[string]any{"asset_id": aid, "starts_at": at(60), "ends_at": at(61)})
}

func TestCertsLabReviewFixes(t *testing.T) {
	w := newHWWorld(t)
	c := list(w.must(t, 201, "POST", "certs", "hw-test", map[string]any{
		"standard": "CE", "status": "passed", "certified_at": "2026-01-01",
	}), "certs")[0]
	// Clearing the date of a passed certification is refused.
	w.must(t, 400, "PATCH", "certs/"+c["id"].(string), "hw-test", map[string]any{"certified_at": ""})
	w.must(t, 400, "PATCH", "certs/"+c["id"].(string), "hw-test", map[string]any{"status": "passed", "certified_at": ""})
	w.must(t, 400, "PATCH", "certs/"+c["id"].(string), "hw-test", map[string]any{"due_at": "2026-12-01Tjunk"})

	lab := "/v1/groups/" + w.gid + "/lab"
	_, a := w.h.doWithWorkspace(t, http.MethodPost, lab+"/assets", "hw-test", w.ws, map[string]any{"name": "Scope"})
	aid := list(a, "assets")[0]["id"]
	at := func(h int) string { return time.Now().UTC().Add(time.Duration(h) * time.Hour).Format(time.RFC3339) }
	book := func(uid string, body map[string]any) int {
		status, _ := w.h.doWithWorkspace(t, http.MethodPost, lab+"/bookings", uid, w.ws, body)
		return status
	}
	if s := book("hw-ee", map[string]any{"asset_id": aid, "starts_at": at(-48), "ends_at": at(2)}); s != 400 {
		t.Errorf("back-dated booking: %d", s)
	}
	if s := book("hw-ee", map[string]any{"asset_id": aid, "starts_at": at(24 * 95), "ends_at": at(24*95 + 1)}); s != 400 {
		t.Errorf("booking past the window: %d", s)
	}
	// A booking far ahead (inside the window) is visible in the list.
	if s := book("hw-ee", map[string]any{"asset_id": aid, "starts_at": at(24 * 80), "ends_at": at(24*80 + 1)}); s != 201 {
		t.Fatalf("booking 80 days out: %d", s)
	}
	_, l := w.h.doWithWorkspace(t, http.MethodGet, lab+"/bookings", "hw-ee", w.ws, nil)
	if len(list(l, "bookings")) != 1 {
		t.Errorf("far booking not listed: %v", l)
	}
	if s, _ := w.h.doWithWorkspace(t, http.MethodGet, lab+"/bookings?from=junk", "hw-ee", w.ws, nil); s != 400 {
		t.Errorf("bad from: %d", s)
	}
	// A read-only override on the project: no booking in its name.
	w.h.doWithWorkspace(t, http.MethodPut, "/v1/groups/"+w.gid+"/projects/"+w.pid+"/members/hw-ee", "hw-lead", w.ws,
		map[string]any{"access": "read"})
	if s := book("hw-ee", map[string]any{"asset_id": aid, "starts_at": at(5), "ends_at": at(6), "project_id": w.pid}); s != 403 {
		t.Errorf("read-only project booking: %d", s)
	}
	if s := book("hw-ee", map[string]any{"asset_id": aid, "starts_at": at(5), "ends_at": at(6)}); s != 201 {
		t.Errorf("booking without the project: %d", s)
	}
}
