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
