package api

import (
	"context"
	"database/sql"
	"errors"
	"net/http"
)

type clientDecisionRequest struct {
	OptionIndex int `json:"option_index"`
}

// POST /v1/client-report/decision
//
// Port of `submit_client_decision()` with the 0007 tightening: the index is
// validated, the decision is written once, and an owner/admin may correct it.
// Any member may call it — a `viewer` is the external client.
func (s *Server) handleClientDecision(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}

	var body clientDecisionRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}

	role, err := s.store.requireMember(r.Context(), ws.ID, caller.UID)
	if err != nil {
		writeError(w, err)
		return
	}

	chosen, err := s.store.submitClientDecision(r.Context(), ws.ID, caller.UID, body.OptionIndex, role)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"choice": chosen})
}

func (s *store) submitClientDecision(
	ctx context.Context,
	workspaceID, callerUID string,
	optionIndex int,
	role Role,
) (string, error) {
	var (
		reportID  string
		options   string
		decidedBy *string
	)
	err := s.db.QueryRowContext(ctx, `
		select id, decision_options, decided_by
		from client_reports where workspace_id = ? limit 1`, workspaceID,
	).Scan(&reportID, &options, &decidedBy)
	if errors.Is(err, sql.ErrNoRows) {
		return "", notFound("no_client_report", "لا يوجد تقرير عميل لهذه المساحة.")
	}
	if err != nil {
		return "", err
	}

	decoded := decodeJSONArray(options)
	if optionIndex < 0 || optionIndex >= len(decoded) {
		return "", badRequest("option_out_of_range", "اختيار خارج النطاق.")
	}
	if decidedBy != nil && !role.IsAdmin() {
		return "", conflict("decision_already_recorded", "قرار العميل اتسجّل بالفعل.")
	}

	chosen, _ := decoded[optionIndex].(string)
	if _, err := s.db.ExecContext(ctx, `
		update client_reports set decision_choice = ?, decided_by = ?, decided_at = ?
		 where id = ?`, chosen, callerUID, nowString(), reportID,
	); err != nil {
		return "", err
	}
	if err := s.logActivity(ctx, workspaceID, callerUID, "client_decision",
		"قرار العميل: "+chosen, nil); err != nil {
		return "", err
	}
	return chosen, nil
}
