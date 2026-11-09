package api

import (
	"errors"
	"net/http"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/workspaccode/6dx/backend/internal/httpx"
)

// --- members ----------------------------------------------------------------

type memberDTO struct {
	UID         string `json:"id"`
	Email       *string `json:"email"`
	DisplayName *string `json:"display_name"`
	PhotoURL    *string `json:"photo_url"`
	Role        Role   `json:"role"`
	OpenTasks   int    `json:"open_tasks"`
}

// GET /v1/members
func (s *Server) handleListMembers(w http.ResponseWriter, r *http.Request) {
	_, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	rows, err := s.store.pool.Query(r.Context(), `
		select m.user_uid, u.email, u.display_name, u.photo_url, m.role::text,
		       (select count(*) from tasks t
		         where t.assignee_uid = m.user_uid and t.status <> 'done')
		from workspace_members m
		join users u on u.uid = m.user_uid
		where m.workspace_id = $1
		order by m.created_at`, ws.ID)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	defer rows.Close()

	members := make([]memberDTO, 0)
	for rows.Next() {
		var m memberDTO
		var role string
		if err := rows.Scan(&m.UID, &m.Email, &m.DisplayName, &m.PhotoURL, &role, &m.OpenTasks); err != nil {
			httpx.Write(w, err)
			return
		}
		m.Role = Role(role)
		members = append(members, m)
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"members": members})
}

type changeRoleRequest struct {
	Role string `json:"role"`
}

// PATCH /v1/members/{uid}
//
// Mirrors the layered RLS policies of 0001:
//   - an owner manages everyone except the owner row,
//   - an admin manages developer/reviewer/viewer only,
//   - `owner` is never granted here (transferOwnership does that).
func (s *Server) handleChangeMemberRole(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	callerRole, err := s.store.requireAdmin(r.Context(), ws.ID, caller.UID)
	if err != nil {
		httpx.Write(w, err)
		return
	}

	var body changeRoleRequest
	if err := httpx.Decode(r, &body); err != nil {
		httpx.Write(w, err)
		return
	}
	target := httpx.PathValue(r, "uid")
	newRole := Role(body.Role)

	switch newRole {
	case RoleOwner:
		httpx.Write(w, httpx.Forbidden("owner_not_assignable",
			"لا يمكن منح صلاحية المالك — استخدم نقل الملكية."))
		return
	case RoleAdmin:
		if callerRole != RoleOwner {
			httpx.Write(w, httpx.Forbidden("admin_requires_owner",
				"منح صلاحية مدير يحتاج مالك المساحة."))
			return
		}
	case RoleDeveloper, RoleReviewer, RoleViewer:
	default:
		httpx.Write(w, httpx.BadRequest("invalid_role", "الدور غير معروف."))
		return
	}

	currentRole, err := s.store.RoleIn(r.Context(), ws.ID, target)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if currentRole == "" {
		httpx.Write(w, httpx.NotFound("member_not_found", "العضو غير موجود."))
		return
	}
	if currentRole == RoleOwner {
		httpx.Write(w, httpx.Forbidden("cannot_modify_owner", "لا يمكن تعديل صف المالك."))
		return
	}

	if _, err := s.store.pool.Exec(r.Context(),
		`update workspace_members set role = $1::member_role
		  where workspace_id = $2 and user_uid = $3`,
		string(newRole), ws.ID, target,
	); err != nil {
		httpx.Write(w, err)
		return
	}
	_ = s.store.logActivity(r.Context(), ws.ID, caller.UID, "member_role_changed",
		"تم تغيير دور عضو إلى "+string(newRole), nil)

	httpx.JSON(w, http.StatusOK, map[string]string{"role": string(newRole)})
}

// DELETE /v1/members/{uid}
func (s *Server) handleRemoveMember(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	callerRole, err := s.store.requireAdmin(r.Context(), ws.ID, caller.UID)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	target := httpx.PathValue(r, "uid")

	currentRole, err := s.store.RoleIn(r.Context(), ws.ID, target)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if currentRole == "" {
		httpx.Write(w, httpx.NotFound("member_not_found", "العضو غير موجود."))
		return
	}
	if currentRole == RoleOwner {
		httpx.Write(w, httpx.Forbidden("cannot_remove_owner",
			"لا يمكن إزالة مالك المساحة — انقل الملكية أولاً."))
		return
	}
	if currentRole == RoleAdmin && callerRole != RoleOwner {
		httpx.Write(w, httpx.Forbidden("admin_requires_owner",
			"إزالة مدير تحتاج مالك المساحة."))
		return
	}

	if _, err := s.store.pool.Exec(r.Context(),
		`delete from workspace_members where workspace_id = $1 and user_uid = $2`,
		ws.ID, target,
	); err != nil {
		httpx.Write(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// --- invitations ------------------------------------------------------------

type inviteRequest struct {
	Emails []string `json:"emails"`
	Role   string   `json:"role"`
}

// POST /v1/invites
//
// The Supabase backend used a DB trigger to notify an invitee who already had
// an account; here the notification is part of the same transaction.
func (s *Server) handleSendInvites(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	callerRole, err := s.store.requireAdmin(r.Context(), ws.ID, caller.UID)
	if err != nil {
		httpx.Write(w, err)
		return
	}

	var body inviteRequest
	if err := httpx.Decode(r, &body); err != nil {
		httpx.Write(w, err)
		return
	}
	if len(body.Emails) == 0 {
		httpx.Write(w, httpx.BadRequest("no_emails", "لا يوجد بريد لدعوته."))
		return
	}
	role := body.Role
	if role == "" {
		role = string(RoleDeveloper)
	}
	if Role(role) == RoleOwner {
		httpx.Write(w, httpx.Forbidden("owner_not_invitable", "لا يمكن دعوة أحد كمالك."))
		return
	}
	if Role(role) == RoleAdmin && callerRole != RoleOwner {
		httpx.Write(w, httpx.Forbidden("admin_requires_owner", "دعوة مدير تحتاج مالك المساحة."))
		return
	}

	tx, err := s.store.pool.Begin(r.Context())
	if err != nil {
		httpx.Write(w, err)
		return
	}
	defer func() { _ = tx.Rollback(r.Context()) }()

	created := 0
	for _, raw := range body.Emails {
		email := strings.ToLower(strings.TrimSpace(raw))
		if email == "" {
			continue
		}

		var inviteID string
		err := tx.QueryRow(r.Context(), `
			insert into workspace_invites (workspace_id, email, role, invited_by)
			values ($1, $2, $3::member_role, $4)
			on conflict (workspace_id, lower(email)) where status = 'pending'
			do update set role = excluded.role, sent_at = now()
			returning id::text`,
			ws.ID, email, role, caller.UID,
		).Scan(&inviteID)
		if err != nil {
			httpx.Write(w, err)
			return
		}

		// Notify an existing account right away (the 0008 trigger).
		if _, err := tx.Exec(r.Context(), `
			insert into notifications (workspace_id, user_uid, kind, title, body, action_label, invite_id)
			select $1, u.uid, 'invite',
			       'دعوة للانضمام إلى ' || w.name,
			       coalesce(nullif(cu.display_name, ''), cu.email, 'أحد المدراء')
			         || ' دعاك للانضمام بدور ' || $2,
			       'قبول الدعوة', $3::uuid
			from users u
			join workspaces w on w.id = $1
			left join users cu on cu.uid = $4
			where lower(u.email) = $5
			on conflict (user_uid, invite_id) where invite_id is not null do nothing`,
			ws.ID, role, inviteID, caller.UID, email,
		); err != nil {
			httpx.Write(w, err)
			return
		}
		created++
	}

	if err := tx.Commit(r.Context()); err != nil {
		httpx.Write(w, err)
		return
	}
	_ = s.store.logActivity(r.Context(), ws.ID, caller.UID, "member_invited",
		"تمت دعوة "+itoa(created)+" عضو بدور "+role, nil)

	httpx.JSON(w, http.StatusCreated, map[string]int{"created": created})
}

// GET /v1/invites/pending
//
// `my_pending_invites()`: invites addressed to the caller's e-mail that they
// have not accepted yet.
func (s *Server) handlePendingInvites(w http.ResponseWriter, r *http.Request) {
	caller, err := s.callerAndUpsert(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if caller.Email == "" {
		httpx.JSON(w, http.StatusOK, map[string]any{"invites": []any{}})
		return
	}

	rows, err := s.store.pool.Query(r.Context(), `
		select i.id::text, i.workspace_id::text, w.name, i.role::text, i.email,
		       to_char(i.sent_at, 'YYYY-MM-DD"T"HH24:MI:SSOF'),
		       to_char(i.expires_at, 'YYYY-MM-DD"T"HH24:MI:SSOF')
		from workspace_invites i
		join workspaces w on w.id = i.workspace_id
		where i.status = 'pending'
		  and lower(i.email) = lower($1)
		  and i.expires_at > now()
		  and not exists (
		    select 1 from workspace_members m
		    where m.workspace_id = i.workspace_id and m.user_uid = $2)
		order by i.sent_at desc`, caller.Email, caller.UID)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	defer rows.Close()

	type inviteRow struct {
		ID            string `json:"invite_id"`
		WorkspaceID   string `json:"workspace_id"`
		WorkspaceName string `json:"workspace_name"`
		Role          string `json:"role"`
		Email         string `json:"email"`
		SentAt        string `json:"sent_at"`
		ExpiresAt     string `json:"expires_at"`
	}
	invites := make([]inviteRow, 0)
	for rows.Next() {
		var row inviteRow
		if err := rows.Scan(&row.ID, &row.WorkspaceID, &row.WorkspaceName, &row.Role,
			&row.Email, &row.SentAt, &row.ExpiresAt); err != nil {
			httpx.Write(w, err)
			return
		}
		invites = append(invites, row)
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"invites": invites})
}

// POST /v1/invites/sync
//
// `sync_my_invites()`: create the notifications for invites that arrived
// before the account existed. Idempotent (unique index on user+invite).
func (s *Server) handleSyncInvites(w http.ResponseWriter, r *http.Request) {
	caller, err := s.callerAndUpsert(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if caller.Email == "" {
		httpx.JSON(w, http.StatusOK, map[string]int{"created": 0})
		return
	}

	tag, err := s.store.pool.Exec(r.Context(), `
		insert into notifications (workspace_id, user_uid, kind, title, body, action_label, invite_id)
		select i.workspace_id, $1, 'invite',
		       'دعوة للانضمام إلى ' || w.name,
		       'تمت دعوتك للانضمام بدور ' || i.role::text,
		       'قبول الدعوة', i.id
		from workspace_invites i
		join workspaces w on w.id = i.workspace_id
		where i.status = 'pending'
		  and lower(i.email) = lower($2)
		  and i.expires_at > now()
		  and not exists (
		    select 1 from workspace_members m
		    where m.workspace_id = i.workspace_id and m.user_uid = $1)
		on conflict (user_uid, invite_id) where invite_id is not null do nothing`,
		caller.UID, caller.Email)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]int64{"created": tag.RowsAffected()})
}

type acceptInviteRequest struct {
	InviteID *string `json:"invite_id"`
}

// POST /v1/invites/accept
//
// `accept_invite()`: the caller cannot insert their own membership through any
// other endpoint, so this is the only way into a second workspace.
func (s *Server) handleAcceptInvite(w http.ResponseWriter, r *http.Request) {
	caller, err := s.callerAndUpsert(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if caller.Email == "" {
		httpx.Write(w, httpx.BadRequest("email_required",
			"حسابك بلا بريد إلكتروني لمطابقة الدعوة."))
		return
	}

	var body acceptInviteRequest
	if err := httpx.Decode(r, &body); err != nil {
		httpx.Write(w, err)
		return
	}

	tx, err := s.store.pool.Begin(r.Context())
	if err != nil {
		httpx.Write(w, err)
		return
	}
	defer func() { _ = tx.Rollback(r.Context()) }()

	var (
		inviteID    string
		workspaceID string
		role        string
		status      string
		email       string
		invitedBy   *string
		expired     bool
	)
	if body.InviteID != nil && *body.InviteID != "" {
		err = tx.QueryRow(r.Context(), `
			select id::text, workspace_id::text, role::text, status::text, email,
			       invited_by, expires_at <= now()
			from workspace_invites where id = $1::uuid`,
			*body.InviteID,
		).Scan(&inviteID, &workspaceID, &role, &status, &email, &invitedBy, &expired)
	} else {
		err = tx.QueryRow(r.Context(), `
			select id::text, workspace_id::text, role::text, status::text, email,
			       invited_by, expires_at <= now()
			from workspace_invites
			where status = 'pending' and lower(email) = lower($1)
			order by sent_at desc
			limit 1`, caller.Email,
		).Scan(&inviteID, &workspaceID, &role, &status, &email, &invitedBy, &expired)
	}
	if errors.Is(err, pgx.ErrNoRows) {
		httpx.Write(w, httpx.NotFound("no_pending_invite", "لا توجد دعوة في انتظار هذا الحساب."))
		return
	}
	if err != nil {
		httpx.Write(w, err)
		return
	}

	if !strings.EqualFold(email, caller.Email) {
		httpx.Write(w, httpx.Forbidden("invite_for_another_email",
			"هذه الدعوة موجهة لبريد آخر."))
		return
	}
	if status != "pending" {
		httpx.Write(w, httpx.Conflict("invite_not_pending", "هذه الدعوة لم تعد معلقة."))
		return
	}
	if expired {
		_, _ = tx.Exec(r.Context(),
			`update workspace_invites set status = 'expired' where id = $1::uuid`, inviteID)
		_ = tx.Commit(r.Context())
		httpx.Write(w, httpx.Conflict("invite_expired", "انتهت صلاحية الدعوة."))
		return
	}

	if _, err := tx.Exec(r.Context(), `
		insert into workspace_members (workspace_id, user_uid, role)
		values ($1::uuid, $2, $3::member_role)
		on conflict (workspace_id, user_uid) do nothing`,
		workspaceID, caller.UID, role,
	); err != nil {
		httpx.Write(w, err)
		return
	}
	if _, err := tx.Exec(r.Context(),
		`update workspace_invites set status = 'accepted' where id = $1::uuid`, inviteID,
	); err != nil {
		httpx.Write(w, err)
		return
	}
	if _, err := tx.Exec(r.Context(),
		`update notifications set is_read = true
		  where user_uid = $1 and invite_id = $2::uuid`, caller.UID, inviteID,
	); err != nil {
		httpx.Write(w, err)
		return
	}
	if invitedBy != nil {
		if _, err := tx.Exec(r.Context(), `
			insert into notifications (workspace_id, user_uid, kind, title, body)
			values ($1::uuid, $2, 'member_joined', 'عضو جديد في مساحة العمل', $3)`,
			workspaceID, *invitedBy, caller.Email+" قبل الدعوة وانضم بدور "+role,
		); err != nil {
			httpx.Write(w, err)
			return
		}
	}
	if err := tx.Commit(r.Context()); err != nil {
		httpx.Write(w, err)
		return
	}

	_ = s.store.logActivity(r.Context(), workspaceID, caller.UID, "member_joined",
		caller.Email+" انضم بدور "+role, nil)

	httpx.JSON(w, http.StatusOK, map[string]string{"workspace_id": workspaceID})
}

// --- notifications ----------------------------------------------------------

// POST /v1/notifications/{id}/read
func (s *Server) handleMarkNotificationRead(w http.ResponseWriter, r *http.Request) {
	caller, err := s.callerAndUpsert(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	tag, err := s.store.pool.Exec(r.Context(),
		`update notifications set is_read = true where id = $1::uuid and user_uid = $2`,
		httpx.PathValue(r, "id"), caller.UID)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	if tag.RowsAffected() == 0 {
		httpx.Write(w, httpx.NotFound("notification_not_found", "الإشعار غير موجود."))
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// POST /v1/notifications/read-all
func (s *Server) handleMarkAllNotificationsRead(w http.ResponseWriter, r *http.Request) {
	caller, err := s.callerAndUpsert(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	tag, err := s.store.pool.Exec(r.Context(),
		`update notifications set is_read = true where user_uid = $1 and is_read = false`,
		caller.UID)
	if err != nil {
		httpx.Write(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]int64{"updated": tag.RowsAffected()})
}

// --- client decisions -------------------------------------------------------

type clientDecisionRequest struct {
	OptionIndex int `json:"option_index"`
}

// POST /v1/client-report/decision
//
// Port of `submit_client_decision()` with the 0007 tightening: the index is
// validated, the decision is written once, and an owner/admin may correct it.
func (s *Server) handleClientDecision(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		httpx.Write(w, err)
		return
	}

	var body clientDecisionRequest
	if err := httpx.Decode(r, &body); err != nil {
		httpx.Write(w, err)
		return
	}

	role, err := s.store.requireMember(r.Context(), ws.ID, caller.UID)
	if err != nil {
		httpx.Write(w, err)
		return
	}

	tx, err := s.store.pool.Begin(r.Context())
	if err != nil {
		httpx.Write(w, err)
		return
	}
	defer func() { _ = tx.Rollback(r.Context()) }()

	var (
		reportID string
		options  []string
		decided  bool
	)
	err = tx.QueryRow(r.Context(), `
		select id::text, decision_options, decided_at is not null
		from client_reports where workspace_id = $1
		for update`, ws.ID,
	).Scan(&reportID, &options, &decided)
	if errors.Is(err, pgx.ErrNoRows) {
		httpx.Write(w, httpx.NotFound("no_client_report", "لا يوجد تقرير عميل لهذه المساحة."))
		return
	}
	if err != nil {
		httpx.Write(w, err)
		return
	}

	if body.OptionIndex < 0 || body.OptionIndex >= len(options) {
		httpx.Write(w, httpx.BadRequest("option_out_of_range", "اختيار خارج النطاق."))
		return
	}
	if decided && !role.IsAdmin() {
		httpx.Write(w, httpx.Conflict("decision_already_recorded", "قرار العميل اتسجّل بالفعل."))
		return
	}

	chosen := options[body.OptionIndex]
	if _, err := tx.Exec(r.Context(), `
		update client_reports
		   set decision_choice = $1, decided_by = $2, decided_at = now()
		 where id = $3::uuid`, chosen, caller.UID, reportID,
	); err != nil {
		httpx.Write(w, err)
		return
	}
	if _, err := tx.Exec(r.Context(), `
		insert into activity_events (workspace_id, type, text, actor_uid)
		values ($1, 'client_decision', $2, $3)`,
		ws.ID, "قرار العميل: "+chosen, caller.UID,
	); err != nil {
		httpx.Write(w, err)
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		httpx.Write(w, err)
		return
	}

	httpx.JSON(w, http.StatusOK, map[string]string{"choice": chosen})
}

func itoa(value int) string {
	if value == 0 {
		return "0"
	}
	digits := ""
	for value > 0 {
		digits = string(rune('0'+value%10)) + digits
		value /= 10
	}
	return digits
}
