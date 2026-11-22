//go:build integration

package api

import (
	"net/http"
	"testing"
	"time"
)

// Vendors → demand → PO (threshold, approval) → receipt (stock + reservation)
// → reserve for a build → issue; with the role rules at each step.
func TestProcurementAndInventory(t *testing.T) {
	w := newHWWorld(t)
	joinGroupAs(t, w.h, "hw-lead", w.ws, w.gid, "hw-buy", "member", "procurement")
	group := "/v1/groups/" + w.gid
	gdo := func(method, path, uid string, body any) (int, map[string]any) {
		return w.h.doWithWorkspace(t, method, group+path, uid, w.ws, body)
	}
	gmust := func(want int, method, path, uid string, body any) map[string]any {
		t.Helper()
		status, out := gdo(method, path, uid, body)
		if status != want {
			t.Fatalf("%s %s as %s: %d %v (want %d)", method, path, uid, status, out, want)
		}
		return out
	}

	// Settings: the PO approval threshold is the lead's / admins' call.
	gmust(403, "PATCH", "/inventory/settings", "hw-buy", map[string]any{"po_approval_threshold_cents": 1})
	gmust(200, "PATCH", "/inventory/settings", "hw-lead", map[string]any{"po_approval_threshold_cents": 10000, "currency": "egp"})
	if st := gmust(200, "GET", "/inventory/settings", "hw-ee", nil)["settings"].(map[string]any); st["currency"] != "EGP" {
		t.Errorf("settings: %v", st)
	}

	// Vendors: procurement manages, engineers read, the client sees nothing.
	gmust(403, "POST", "/vendors", "hw-ee", map[string]any{"name": "Digi"})
	vendors := list(gmust(201, "POST", "/vendors", "hw-buy", map[string]any{"name": "Digi", "default_lead_days": 21}), "vendors")
	vendor := vendors[0]["id"].(string)
	gmust(409, "POST", "/vendors", "hw-buy", map[string]any{"name": "digi"})
	gmust(403, "GET", "/vendors", "hw-client", nil)
	gmust(403, "GET", "/stock", "hw-client", nil)

	// A released BOM and a build in a week: the demand says order now.
	part := w.must(t, 201, "POST", "parts", "hw-ee", map[string]any{
		"part_number": "R-10K", "description": "10k", "vendor": "Digi", "unit_cost_cents": 2,
	})["part"].(map[string]any)
	draft := w.must(t, 201, "POST", "bom", "hw-ee", map[string]any{})["bom"].(map[string]any)
	w.must(t, 200, "PUT", "bom/"+draft["id"].(string)+"/lines/"+part["id"].(string), "hw-ee", map[string]any{"quantity": 12})
	w.must(t, 200, "POST", "bom/"+draft["id"].(string)+"/release", "hw-lead", nil)
	soon := time.Now().UTC().AddDate(0, 0, 7).Format("2006-01-02")
	build := w.must(t, 201, "POST", "builds", "hw-lead", map[string]any{
		"name": "EVT1", "bom_rev_id": draft["id"], "quantity": 10, "planned_at": soon,
	})["build"].(map[string]any)
	demand := list(w.must(t, 200, "GET", "demand", "hw-ee", nil), "demand")
	if len(demand) != 1 || demand[0]["needed"] != float64(120) || demand[0]["shortage"] != float64(120) ||
		demand[0]["order_now"] != true {
		t.Fatalf("demand: %v", demand)
	}

	// An engineer requests (draft), procurement submits; under the
	// threshold it is ordered at once.
	po := w.must(t, 201, "POST", "pos", "hw-ee", map[string]any{"vendor_id": vendor})["po"].(map[string]any)
	poID := po["id"].(string)
	if po["code"] != "PO-001" || po["currency"] != "EGP" {
		t.Errorf("po: %v", po)
	}
	w.must(t, 403, "POST", "pos", "hw-tech", map[string]any{"vendor_id": vendor})
	w.must(t, 200, "PUT", "pos/"+poID+"/lines/R-10K", "hw-ee", map[string]any{"qty": 120, "unit_cost_cents": 2})
	w.must(t, 403, "POST", "pos/"+poID+"/submit", "hw-ee", nil)
	if got := w.must(t, 200, "POST", "pos/"+poID+"/submit", "hw-buy", nil)["po"].(map[string]any); got["status"] != "ordered" {
		t.Fatalf("small PO: %v", got["status"])
	}
	// A big one waits for someone else's approval.
	big := w.must(t, 201, "POST", "pos", "hw-buy", map[string]any{"vendor_id": vendor})["po"].(map[string]any)
	bigID := big["id"].(string)
	w.must(t, 200, "PUT", "pos/"+bigID+"/lines/MCU-1", "hw-buy", map[string]any{"qty": 1000, "unit_cost_cents": 50})
	if got := w.must(t, 200, "POST", "pos/"+bigID+"/submit", "hw-buy", nil)["po"].(map[string]any); got["status"] != "pending_approval" {
		t.Fatalf("big PO: %v", got["status"])
	}
	w.must(t, 403, "POST", "pos/"+bigID+"/approve", "hw-buy", nil)
	w.must(t, 200, "POST", "pos/"+bigID+"/approve", "hw-lead", nil)
	// The technician sees POs but no prices.
	for _, p := range list(w.must(t, 200, "GET", "pos", "hw-tech", nil), "pos") {
		if _, ok := p["total_cents"]; ok {
			t.Fatal("the technician sees PO totals")
		}
	}
	w.must(t, 403, "GET", "pos", "hw-client", nil)

	// Receiving: partial, over-receipt refused, then complete.
	got := w.must(t, 200, "POST", "pos/"+poID+"/receive", "hw-tech", map[string]any{
		"location": "Shelf-A", "lines": []map[string]any{{"part_number": "R-10K", "qty": 100}},
	})["po"].(map[string]any)
	if got["status"] != "partially_received" {
		t.Errorf("after partial receipt: %v", got["status"])
	}
	w.must(t, 409, "POST", "pos/"+poID+"/receive", "hw-tech", map[string]any{
		"location": "Shelf-A", "lines": []map[string]any{{"part_number": "R-10K", "qty": 30}},
	})
	w.must(t, 200, "POST", "pos/"+poID+"/receive", "hw-tech", map[string]any{
		"location": "Shelf-A", "lines": []map[string]any{{"part_number": "R-10K", "qty": 20}},
	})
	stock := list(gmust(200, "GET", "/stock?part=R-10K", "hw-ee", nil), "stock")
	if len(stock) != 1 || stock[0]["on_hand"] != float64(120) || stock[0]["available"] != float64(0) {
		t.Fatalf("stock after receipt: %v", stock)
	}
	if d := list(w.must(t, 200, "GET", "demand", "hw-ee", nil), "demand")[0]; d["shortage"] != float64(0) {
		t.Errorf("demand after receipt: %v", d)
	}

	// Reserved units cannot be issued by hand…
	gmust(409, "POST", "/stock/movements", "hw-tech", map[string]any{
		"part_number": "R-10K", "location": "Shelf-A", "qty": 1, "kind": "issue",
	})
	// …move the receipt's reservation onto the build, then issue the build.
	res := list(w.must(t, 200, "GET", "reservations", "hw-ee", nil), "reservations")
	for _, rv := range res {
		w.must(t, 200, "DELETE", "reservations/"+rv["id"].(string), "hw-lead", nil)
	}
	w.must(t, 200, "POST", "reservations", "hw-lead", map[string]any{"build_id": build["id"], "part_number": "R-10K", "qty": 120})
	w.must(t, 409, "POST", "reservations", "hw-lead", map[string]any{"build_id": build["id"], "part_number": "R-10K", "qty": 1})
	if out := w.must(t, 200, "POST", "builds/"+build["id"].(string)+"/issue", "hw-tech", nil); out["issued"] != float64(1) {
		t.Errorf("issue: %v", out)
	}
	w.must(t, 409, "POST", "builds/"+build["id"].(string)+"/issue", "hw-tech", nil)
	if s := list(gmust(200, "GET", "/stock?part=R-10K", "hw-ee", nil), "stock"); len(s) != 0 {
		t.Errorf("stock after issue: %v", s)
	}

	// Adjustments are procurement's and need a reason; transfers move stock.
	gmust(403, "POST", "/stock/movements", "hw-tech", map[string]any{"part_number": "R-10K", "qty": 5, "kind": "adjust", "note": "count"})
	gmust(400, "POST", "/stock/movements", "hw-buy", map[string]any{"part_number": "R-10K", "qty": 5, "kind": "adjust"})
	gmust(201, "POST", "/stock/movements", "hw-buy", map[string]any{"part_number": "R-10K", "qty": 5, "kind": "adjust", "note": "found a strip"})
	gmust(409, "POST", "/stock/movements", "hw-tech", map[string]any{"part_number": "R-10K", "qty": 9, "kind": "transfer", "to_location": "Shelf-B"})
	gmust(201, "POST", "/stock/movements", "hw-tech", map[string]any{"part_number": "R-10K", "qty": 3, "kind": "transfer", "to_location": "Shelf-B"})
	if m := list(gmust(200, "GET", "/stock/movements?part=R-10K", "hw-ee", nil), "movements"); len(m) < 5 {
		t.Errorf("movements: %d", len(m))
	}

	// Close / cancel.
	w.must(t, 200, "POST", "pos/"+poID+"/close", "hw-buy", nil)
	w.must(t, 200, "POST", "pos/"+bigID+"/cancel", "hw-buy", nil)
	w.must(t, 409, "POST", "pos/"+bigID+"/close", "hw-buy", nil)

	// A vendor of another hardware group does not resolve.
	_, other := createGroup(t, w.h, "hw-lead", w.ws, "Other HW", "hardware")
	otherID := groupIDOf(t, other)
	_, ov := w.h.doWithWorkspace(t, http.MethodPost, "/v1/groups/"+otherID+"/vendors", "hw-lead", w.ws, map[string]any{"name": "Mouser"})
	foreign := list(ov, "vendors")[0]["id"]
	w.must(t, 404, "POST", "pos", "hw-buy", map[string]any{"vendor_id": foreign})
}
