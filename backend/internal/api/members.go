package api

import (
	"database/sql"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/workspaccode/6dx/backend/internal/auth"
)

// --- members ----------------------------------------------------------------

// GET /v1/members
func (s *Server) handleListMembers(w http.ResponseWriter, r *http.Request) {
	_, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}

	rows, err := s.store.db.QueryContext(r.Context(), `
		select m.user_uid, u.email, u.display_name, u.photo_url, m.role,
		       (select count(*) from tasks t
		         where t.assignee_uid = m.user_uid and t.status <> 'done')
		from workspace_members m
		left join users u on u.uid = m.user_uid
		where m.workspace_id = ?
		order by m.created_at`, ws.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()

	members := make([]map[string]any, 0)
	for rows.Next() {
		var uid, role string
		var email, displayName, photoURL *string
		var openTasks int
		if err := rows.Scan(&uid, &email, &displayName, &photoURL, &role, &openTasks); err != nil {
			writeError(w, err)
			return
		}
		members = append(members, map[string]any{
			"id":           uid,
			"email":        email,
			"display_name": displayName,
			"photo_url":    photoURL,
			"role":         role,
			"open_tasks":   openTasks,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"members": members})
}

type changeRoleRequest struct {
	Role string `json:"role"`
}

// PATCH /v1/members/{uid}
//
// Mirrors the layered policies: an owner manages everyone except the owner row,
// an admin manages developer/reviewer/viewer only, and `owner` is never granted
// here (transferOwnership does that).
func (s *Server) handleChangeMemberRole(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	callerRole, err := s.store.requireAdmin(r.Context(), ws.ID, caller.UID)
	if err != nil {
		writeError(w, err)
		return
	}

	var body changeRoleRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	target := r.PathValue("uid")
	newRole := Role(body.Role)

	switch newRole {
	case RoleOwner:
		writeError(w, forbidden("owner_not_assignable",
			"لا يمكن منح صلاحية المالك — استخدم نقل الملكية."))
		return
	case RoleAdmin:
		if callerRole != RoleOwner {
			writeError(w, forbidden("admin_requires_owner",
				"منح صلاحية مدير يحتاج مالك المساحة."))
			return
		}
	case RoleDeveloper, RoleReviewer, RoleViewer:
	default:
		writeError(w, badRequest("invalid_role", "الدور غير معروف."))
		return
	}

	currentRole, err := s.store.RoleIn(r.Context(), ws.ID, target)
	if err != nil {
		writeError(w, err)
		return
	}
	if currentRole == "" {
		writeError(w, notFound("member_not_found", "العضو غير موجود."))
		return
	}
	if currentRole == RoleOwner {
		writeError(w, forbidden("cannot_modify_owner", "لا يمكن تعديل صف المالك."))
		return
	}

	if _, err := s.store.db.ExecContext(r.Context(),
		`update workspace_members set role = ? where workspace_id = ? and user_uid = ?`,
		string(newRole), ws.ID, target,
	); err != nil {
		writeError(w, err)
		return
	}
	_ = s.store.logActivity(r.Context(), ws.ID, caller.UID, "member_role_changed",
		"تم تغيير دور عضو إلى "+string(newRole), nil)

	writeJSON(w, http.StatusOK, map[string]string{"role": string(newRole)})
}

// DELETE /v1/members/{uid}
func (s *Server) handleRemoveMember(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	callerRole, err := s.store.requireAdmin(r.Context(), ws.ID, caller.UID)
	if err != nil {
		writeError(w, err)
		return
	}
	target := r.PathValue("uid")

	currentRole, err := s.store.RoleIn(r.Context(), ws.ID, target)
	if err != nil {
		writeError(w, err)
		return
	}
	if currentRole == "" {
		writeError(w, notFound("member_not_found", "العضو غير موجود."))
		return
	}
	if currentRole == RoleOwner {
		writeError(w, forbidden("cannot_remove_owner",
			"لا يمكن إزالة مالك المساحة — انقل الملكية أولاً."))
		return
	}
	if currentRole == RoleAdmin && callerRole != RoleOwner {
		writeError(w, forbidden("admin_requires_owner",
			"إزالة مدير تحتاج مالك المساحة."))
		return
	}

	if _, err := s.store.db.ExecContext(r.Context(),
		`delete from workspace_members where workspace_id = ? and user_uid = ?`,
		ws.ID, target,
	); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// --- invitations ------------------------------------------------------------

// inviteTTL is how long an invitation stays actionable — the same 7 days the
// Postgres `default (now() + interval '7 days')` used.
const inviteTTL = 7 * 24 * time.Hour

type inviteRequest struct {
	Emails []string `json:"emails"`
	Role   string   `json:"role"`
}

// POST /v1/invites
func (s *Server) handleSendInvites(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	callerRole, err := s.store.requireAdmin(r.Context(), ws.ID, caller.UID)
	if err != nil {
		writeError(w, err)
		return
	}

	var body inviteRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if len(body.Emails) == 0 {
		writeError(w, badRequest("no_emails", "لا يوجد بريد لدعوته."))
		return
	}
	role := body.Role
	if role == "" {
		role = string(RoleDeveloper)
	}
	switch Role(role) {
	case RoleOwner:
		writeError(w, forbidden("owner_not_invitable", "لا يمكن دعوة أحد كمالك."))
		return
	case RoleAdmin:
		if callerRole != RoleOwner {
			writeError(w, forbidden("admin_requires_owner", "دعوة مدير تحتاج مالك المساحة."))
			return
		}
	case RoleDeveloper, RoleReviewer, RoleViewer:
	default:
		writeError(w, badRequest("invalid_role", "الدور غير معروف."))
		return
	}

	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()

	now := nowString()
	created := 0
	for _, raw := range body.Emails {
		email := strings.ToLower(strings.TrimSpace(raw))
		if email == "" {
			continue
		}

		// One pending invite per (workspace, e-mail): reuse the row if it
		// exists so re-inviting updates the role instead of duplicating.
		var inviteID string
		err := tx.QueryRowContext(r.Context(), `
			select id from workspace_invites
			 where workspace_id = ? and lower(email) = ? and status = 'pending'
			 limit 1`, ws.ID, email).Scan(&inviteID)
		switch {
		case errors.Is(err, sql.ErrNoRows):
			inviteID = newID()
			if _, err := tx.ExecContext(r.Context(), `
				insert into workspace_invites
				  (id, workspace_id, email, role, status, invited_by, sent_at, expires_at)
				values (?, ?, ?, ?, 'pending', ?, ?, ?)`,
				inviteID, ws.ID, email, role, caller.UID, now, timeAhead(inviteTTL),
			); err != nil {
				writeError(w, err)
				return
			}
		case err != nil:
			writeError(w, err)
			return
		default:
			if _, err := tx.ExecContext(r.Context(), `
				update workspace_invites set role = ?, sent_at = ?, expires_at = ?
				 where id = ?`, role, now, timeAhead(inviteTTL), inviteID,
			); err != nil {
				writeError(w, err)
				return
			}
		}

		// Notify an existing account right away (the old DB trigger).
		if _, err := tx.ExecContext(r.Context(), `
			insert into notifications
			  (id, workspace_id, user_uid, kind, title, body, action_label, invite_id,
			   is_read, created_at)
			select ?, ?, u.uid, 'invite',
			       'دعوة للانضمام إلى ' || w.name,
			       coalesce(nullif(cu.display_name, ''), cu.email, 'أحد المدراء')
			         || ' دعاك للانضمام بدور ' || ?,
			       'قبول الدعوة', ?, 0, ?
			from users u
			join workspaces w on w.id = ?
			left join users cu on cu.uid = ?
			where lower(u.email) = ?
			  and not exists (
			    select 1 from notifications n
			    where n.user_uid = u.uid and n.invite_id = ?)`,
			newID(), ws.ID, role, inviteID, now, ws.ID, caller.UID, email, inviteID,
		); err != nil {
			writeError(w, err)
			return
		}
		created++
	}

	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	_ = s.store.logActivity(r.Context(), ws.ID, caller.UID, "member_invited",
		"تمت دعوة "+itoa(created)+" عضو بدور "+role, nil)

	writeJSON(w, http.StatusCreated, map[string]int{"created": created})
}

// GET /v1/invites/pending
func (s *Server) handlePendingInvites(w http.ResponseWriter, r *http.Request) {
	caller, err := s.callerAndUpsert(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if caller.Email == "" {
		writeJSON(w, http.StatusOK, map[string]any{"invites": []any{}})
		return
	}

	rows, err := s.store.db.QueryContext(r.Context(), `
		select i.id, i.workspace_id, w.name, i.role, i.email, i.sent_at, i.expires_at
		from workspace_invites i
		join workspaces w on w.id = i.workspace_id
		where i.status = 'pending'
		  and lower(i.email) = lower(?)
		  and i.expires_at > ?
		  and not exists (
		    select 1 from workspace_members m
		    where m.workspace_id = i.workspace_id and m.user_uid = ?)
		order by i.sent_at desc`,
		caller.Email, nowString(), caller.UID)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()

	invites := make([]map[string]any, 0)
	for rows.Next() {
		var id, wsID, workspaceName, role, email, sentAt, expiresAt string
		if err := rows.Scan(&id, &wsID, &workspaceName, &role, &email,
			&sentAt, &expiresAt); err != nil {
			writeError(w, err)
			return
		}
		invites = append(invites, map[string]any{
			"invite_id":      id,
			"workspace_id":   wsID,
			"workspace_name": workspaceName,
			"role":           role,
			"email":          email,
			"sent_at":        sentAt,
			"expires_at":     expiresAt,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"invites": invites})
}

// POST /v1/invites/sync
func (s *Server) handleSyncInvites(w http.ResponseWriter, r *http.Request) {
	caller, err := s.callerAndUpsert(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if caller.Email == "" {
		writeJSON(w, http.StatusOK, map[string]int{"created": 0})
		return
	}

	now := nowString()
	result, err := s.store.db.ExecContext(r.Context(), `
		insert into notifications
		  (id, workspace_id, user_uid, kind, title, body, action_label, invite_id,
		   is_read, created_at)
		select lower(hex(randomblob(16))), i.workspace_id, ?, 'invite',
		       'دعوة للانضمام إلى ' || w.name,
		       'تمت دعوتك للانضمام بدور ' || i.role,
		       'قبول الدعوة', i.id, 0, ?
		from workspace_invites i
		join workspaces w on w.id = i.workspace_id
		where i.status = 'pending'
		  and lower(i.email) = lower(?)
		  and i.expires_at > ?
		  and not exists (
		    select 1 from workspace_members m
		    where m.workspace_id = i.workspace_id and m.user_uid = ?)
		  and not exists (
		    select 1 from notifications n
		    where n.user_uid = ? and n.invite_id = i.id)`,
		caller.UID, now, caller.Email, now, caller.UID, caller.UID)
	if err != nil {
		writeError(w, err)
		return
	}
	affected, _ := result.RowsAffected()
	writeJSON(w, http.StatusOK, map[string]int64{"created": affected})
}

type acceptInviteRequest struct {
	InviteID *string `json:"invite_id"`
}

// POST /v1/invites/accept
func (s *Server) handleAcceptInvite(w http.ResponseWriter, r *http.Request) {
	caller, err := s.callerAndUpsert(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if caller.Email == "" {
		writeError(w, badRequest("email_required",
			"حسابك بلا بريد إلكتروني لمطابقة الدعوة."))
		return
	}

	var body acceptInviteRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}

	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()

	var (
		inviteID, workspaceID, role, status, email string
		invitedBy                                 *string
		expiresAt                                 string
	)
	if body.InviteID != nil && *body.InviteID != "" {
		err = tx.QueryRowContext(r.Context(), `
			select id, workspace_id, role, status, email, invited_by, expires_at
			from workspace_invites where id = ?`, *body.InviteID,
		).Scan(&inviteID, &workspaceID, &role, &status, &email, &invitedBy, &expiresAt)
	} else {
		err = tx.QueryRowContext(r.Context(), `
			select id, workspace_id, role, status, email, invited_by, expires_at
			from workspace_invites
			where status = 'pending' and lower(email) = lower(?)
			order by sent_at desc limit 1`, caller.Email,
		).Scan(&inviteID, &workspaceID, &role, &status, &email, &invitedBy, &expiresAt)
	}
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("no_pending_invite", "لا توجد دعوة في انتظار هذا الحساب."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}

	if !strings.EqualFold(email, caller.Email) {
		writeError(w, forbidden("invite_for_another_email", "هذه الدعوة موجهة لبريد آخر."))
		return
	}
	if status != "pending" {
		writeError(w, conflict("invite_not_pending", "هذه الدعوة لم تعد معلقة."))
		return
	}
	if expiresAt <= nowString() {
		if _, err := tx.ExecContext(r.Context(),
			`update workspace_invites set status = 'expired' where id = ?`, inviteID,
		); err != nil {
			writeError(w, err)
			return
		}
		_ = tx.Commit()
		writeError(w, conflict("invite_expired", "انتهت صلاحية الدعوة."))
		return
	}

	now := nowString()
	if _, err := tx.ExecContext(r.Context(), `
		insert into workspace_members (workspace_id, user_uid, role, created_at)
		values (?, ?, ?, ?)
		on conflict (workspace_id, user_uid) do nothing`,
		workspaceID, caller.UID, role, now,
	); err != nil {
		writeError(w, err)
		return
	}
	if _, err := tx.ExecContext(r.Context(),
		`update workspace_invites set status = 'accepted' where id = ?`, inviteID,
	); err != nil {
		writeError(w, err)
		return
	}
	if _, err := tx.ExecContext(r.Context(),
		`update notifications set is_read = 1 where user_uid = ? and invite_id = ?`,
		caller.UID, inviteID,
	); err != nil {
		writeError(w, err)
		return
	}
	if invitedBy != nil {
		if _, err := tx.ExecContext(r.Context(), `
			insert into notifications
			  (id, workspace_id, user_uid, kind, title, body, is_read, created_at)
			values (?, ?, ?, 'member_joined', 'عضو جديد في مساحة العمل', ?, 0, ?)`,
			newID(), workspaceID, *invitedBy,
			caller.Email+" قبل الدعوة وانضم بدور "+role, now,
		); err != nil {
			writeError(w, err)
			return
		}
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}

	_ = s.store.logActivity(r.Context(), workspaceID, caller.UID, "member_joined",
		caller.Email+" انضم بدور "+role, nil)

	writeJSON(w, http.StatusOK, map[string]string{"workspace_id": workspaceID})
}

// --- notifications ----------------------------------------------------------

// POST /v1/notifications/{id}/read
func (s *Server) handleMarkNotificationRead(w http.ResponseWriter, r *http.Request) {
	caller, err := s.callerAndUpsert(r)
	if err != nil {
		writeError(w, err)
		return
	}
	result, err := s.store.db.ExecContext(r.Context(),
		`update notifications set is_read = 1 where id = ? and user_uid = ?`,
		r.PathValue("id"), caller.UID)
	if err != nil {
		writeError(w, err)
		return
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		writeError(w, notFound("notification_not_found", "الإشعار غير موجود."))
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// POST /v1/notifications/read-all
func (s *Server) handleMarkAllNotificationsRead(w http.ResponseWriter, r *http.Request) {
	caller, err := s.callerAndUpsert(r)
	if err != nil {
		writeError(w, err)
		return
	}
	result, err := s.store.db.ExecContext(r.Context(),
		`update notifications set is_read = 1 where user_uid = ? and is_read = 0`,
		caller.UID)
	if err != nil {
		writeError(w, err)
		return
	}
	affected, _ := result.RowsAffected()
	writeJSON(w, http.StatusOK, map[string]int64{"updated": affected})
}

// itoa is a tiny integer formatter (avoids pulling strconv into hot paths).
func itoa(value int) string {
	if value == 0 {
		return "0"
	}
	negative := value < 0
	if negative {
		value = -value
	}
	digits := make([]byte, 0, 12)
	for value > 0 {
		digits = append([]byte{byte('0' + value%10)}, digits...)
		value /= 10
	}
	if negative {
		return "-" + string(digits)
	}
	return string(digits)
}

var _ = auth.FromContext
