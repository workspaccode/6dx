package api

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"strings"
)

// inviteSpec is what an accepted invite grants.
type inviteSpec struct {
	WorkspaceRole  Role
	GroupID        string
	GroupRole      GroupRole
	FunctionalRole string
	// Label is the role text shown in the notification.
	Label string
}

// cleanEmails validates and de-duplicates the addresses of one invite
// request. One bad address rejects the whole request, so the admin sees
// exactly which one to fix.
func cleanEmails(raw []string) ([]string, error) {
	if len(raw) > maxInvitesPerRequest {
		return nil, badRequest("too_many_invites",
			fmt.Sprintf("أقصى عدد للدعوات في المرة الواحدة %d.", maxInvitesPerRequest))
	}
	emails := make([]string, 0, len(raw))
	seen := make(map[string]bool, len(raw))
	for _, value := range raw {
		if strings.TrimSpace(value) == "" {
			continue
		}
		email := normalizeEmail(value)
		if email == "" {
			return nil, badRequest("invalid_email", "بريد غير صالح: "+truncate(value, 60))
		}
		if !seen[email] {
			seen[email] = true
			emails = append(emails, email)
		}
	}
	if len(emails) == 0 {
		return nil, badRequest("no_emails", "لا يوجد بريد لدعوته.")
	}
	return emails, nil
}

// storeInvites creates (or refreshes) one pending invite per address and
// notifies the accounts that already exist. A pending invite is unique per
// (workspace, e-mail): re-inviting someone moves the invite to the new group
// and role instead of duplicating it.
func (s *Server) storeInvites(
	r *http.Request,
	ws *Workspace,
	callerUID string,
	rawEmails []string,
	spec inviteSpec,
) (int, error) {
	emails, err := cleanEmails(rawEmails)
	if err != nil {
		return 0, err
	}
	ctx := r.Context()
	tx, err := s.store.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, err
	}
	defer func() { _ = tx.Rollback() }()

	var pending int
	if err := tx.QueryRowContext(ctx,
		`select count(*) from workspace_invites where workspace_id = ? and status = 'pending'`,
		ws.ID).Scan(&pending); err != nil {
		return 0, err
	}
	if pending+len(emails) > maxPendingInvitesPerWS {
		return 0, conflict("pending_invites_limit",
			fmt.Sprintf("مساحة العمل وصلت للحد الأقصى للدعوات المعلّقة (%d). ألغِ أو انتظر انتهاء القديمة.",
				maxPendingInvitesPerWS))
	}

	now := nowString()
	created := 0
	for _, email := range emails {
		var inviteID string
		err := tx.QueryRowContext(ctx, `
			select id from workspace_invites
			 where workspace_id = ? and lower(email) = ? and status = 'pending'
			 limit 1`, ws.ID, email).Scan(&inviteID)
		switch {
		case errors.Is(err, sql.ErrNoRows):
			inviteID = newID()
			if _, err := tx.ExecContext(ctx, `
				insert into workspace_invites
				  (id, workspace_id, email, role, status, invited_by, sent_at, expires_at,
				   group_id, group_role, functional_role)
				values (?, ?, ?, ?, 'pending', ?, ?, ?, ?, ?, ?)`,
				inviteID, ws.ID, email, string(spec.WorkspaceRole), callerUID, now,
				timeAhead(inviteTTL), spec.GroupID, string(spec.GroupRole), spec.FunctionalRole,
			); err != nil {
				return 0, err
			}
		case err != nil:
			return 0, err
		default:
			if _, err := tx.ExecContext(ctx, `
				update workspace_invites
				   set role = ?, sent_at = ?, expires_at = ?, invited_by = ?,
				       group_id = ?, group_role = ?, functional_role = ?
				 where id = ?`,
				string(spec.WorkspaceRole), now, timeAhead(inviteTTL), callerUID,
				spec.GroupID, string(spec.GroupRole), spec.FunctionalRole, inviteID,
			); err != nil {
				return 0, err
			}
		}

		// Notify an existing account right away.
		if _, err := tx.ExecContext(ctx, `
			insert into notifications
			  (id, workspace_id, user_uid, kind, title, body, action_label, invite_id,
			   is_read, created_at)
			select ?, ?, u.uid, 'invite',
			       'دعوة للانضمام إلى ' || coalesce(g.name, w.name),
			       coalesce(nullif(cu.display_name, ''), cu.email, 'أحد المدراء')
			         || ' دعاك للانضمام بدور ' || ?,
			       'قبول الدعوة', ?, 0, ?
			from users u
			join workspaces w on w.id = ?
			left join groups g on g.id = ?
			left join users cu on cu.uid = ?
			where lower(u.email) = ?
			  and not exists (
			    select 1 from notifications n
			    where n.user_uid = u.uid and n.invite_id = ?)`,
			newID(), ws.ID, spec.Label, inviteID, now, ws.ID, spec.GroupID, callerUID,
			email, inviteID,
		); err != nil {
			return 0, err
		}
		created++
	}
	if err := tx.Commit(); err != nil {
		return 0, err
	}
	_ = s.store.logActivity(ctx, ws.ID, callerUID, "member_invited",
		"تمت دعوة "+itoa(created)+" عضو بدور "+spec.Label, nil)
	return created, nil
}

// defaultGroupID is the group legacy (workspace-level) endpoints act on.
func (s *store) defaultGroupID(ctx context.Context, workspaceID string) (string, error) {
	var id string
	err := s.db.QueryRowContext(ctx,
		`select id from groups where workspace_id = ? and is_default = 1`, workspaceID,
	).Scan(&id)
	if errors.Is(err, sql.ErrNoRows) {
		return "", notFound("default_group_missing", "مساحة العمل مالهاش مجموعة افتراضية.")
	}
	return id, err
}

// joinGroup adds the user to the invite's group inside tx. A member who is
// already in the group keeps their current roles.
func joinGroup(ctx context.Context, tx *sql.Tx, groupID, uid string, role GroupRole, functional, now string) error {
	_, err := tx.ExecContext(ctx, `
		insert into group_members (group_id, user_uid, group_role, functional_role, created_at)
		values (?, ?, ?, ?, ?)
		on conflict (group_id, user_uid) do nothing`,
		groupID, uid, string(role), functional, now)
	return err
}

// DELETE /v1/invites/{id} — cancel a pending invite. A group invite needs
// members.manage in that group; a workspace invite a workspace admin.
func (s *Server) handleCancelInvite(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	var groupID sql.NullString
	err = s.store.db.QueryRowContext(r.Context(), `
		select group_id from workspace_invites where id = ? and workspace_id = ? and status = 'pending'`,
		r.PathValue("id"), ws.ID).Scan(&groupID)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("invite_not_found", "الدعوة مش موجودة أو اتقبلت."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if groupID.Valid && groupID.String != "" {
		access, err := s.store.loadGroupAccess(r.Context(), ws, caller.UID, groupID.String)
		if err != nil {
			writeError(w, err)
			return
		}
		if err := access.require(CapManageMembers); err != nil {
			writeError(w, err)
			return
		}
	} else if _, err := s.store.requireAdmin(r.Context(), ws.ID, caller.UID); err != nil {
		writeError(w, err)
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(),
		`update workspace_invites set status = 'revoked' where id = ? and status = 'pending'`,
		r.PathValue("id")); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// GET /v1/invites/{id} — what the invite screen shows before accepting. Only
// the invitee may read it: the address must match the caller's verified
// e-mail, so an invite id alone reveals nothing.
func (s *Server) handleGetInvite(w http.ResponseWriter, r *http.Request) {
	caller, err := s.callerAndUpsert(r)
	if err != nil {
		writeError(w, err)
		return
	}
	var (
		id, workspaceID, workspaceName, email, status, expiresAt, sentAt string
		groupID, groupName, groupType, groupRole, functional, inviter    *string
	)
	err = s.store.db.QueryRowContext(r.Context(), `
		select i.id, i.workspace_id, w.name, i.email, i.status, i.expires_at, i.sent_at,
		       i.group_id, g.name, g.type, i.group_role, i.functional_role,
		       (select coalesce(nullif(u.display_name, ''), u.email) from users u where u.uid = i.invited_by)
		from workspace_invites i
		join workspaces w on w.id = i.workspace_id
		left join groups g on g.id = i.group_id
		where i.id = ?`, r.PathValue("id"),
	).Scan(&id, &workspaceID, &workspaceName, &email, &status, &expiresAt, &sentAt,
		&groupID, &groupName, &groupType, &groupRole, &functional, &inviter)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("invite_not_found", "الدعوة مش موجودة."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if caller.Email == "" || !strings.EqualFold(email, caller.Email) {
		// Say which address it is for (masked), so the user knows to switch
		// accounts, without leaking anything about the group.
		writeJSON(w, http.StatusForbidden, map[string]string{
			"error":   "invite_for_another_email",
			"message": "الدعوة دي لبريد تاني: " + maskEmail(email),
		})
		return
	}
	if status == "pending" && expiresAt <= nowString() {
		status = "expired"
	}
	alreadyMember := false
	if groupID != nil {
		var n int
		_ = s.store.db.QueryRowContext(r.Context(),
			`select count(*) from group_members where group_id = ? and user_uid = ?`,
			*groupID, caller.UID).Scan(&n)
		alreadyMember = n > 0
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"invite": map[string]any{
			"id":              id,
			"status":          status,
			"sent_at":         sentAt,
			"expires_at":      expiresAt,
			"workspace_id":    workspaceID,
			"workspace_name":  workspaceName,
			"group_id":        groupID,
			"group_name":      groupName,
			"group_type":      groupType,
			"group_role":      groupRole,
			"functional_role": functional,
			"invited_by":      inviter,
			"already_member":  alreadyMember,
		},
	})
}

// POST /v1/invites/{id}/decline
func (s *Server) handleDeclineInvite(w http.ResponseWriter, r *http.Request) {
	caller, err := s.callerAndUpsert(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if caller.Email == "" {
		writeError(w, badRequest("email_required", "حسابك بلا بريد إلكتروني لمطابقة الدعوة."))
		return
	}
	result, err := s.store.db.ExecContext(r.Context(), `
		update workspace_invites set status = 'revoked'
		 where id = ? and status = 'pending' and lower(email) = lower(?)`,
		r.PathValue("id"), caller.Email)
	if err != nil {
		writeError(w, err)
		return
	}
	if n, _ := result.RowsAffected(); n == 0 {
		writeError(w, notFound("no_pending_invite", "مفيش دعوة معلّقة بالرقم ده لحسابك."))
		return
	}
	_, _ = s.store.db.ExecContext(r.Context(),
		`update notifications set is_read = 1 where user_uid = ? and invite_id = ?`,
		caller.UID, r.PathValue("id"))
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// maskEmail turns sami@company.com into s***@company.com.
func maskEmail(email string) string {
	local, domain, ok := strings.Cut(email, "@")
	if !ok || local == "" {
		return "***"
	}
	return string([]rune(local)[:1]) + "***@" + domain
}
