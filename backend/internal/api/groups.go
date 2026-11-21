package api

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/http"
	"strings"
)

// Groups — docs/design/groups-and-roles.md. A group lives in the active
// workspace (X-Workspace-Id); every handler resolves the caller's access to
// it first and then asks for one capability.

// groupAccess is the caller's standing in one group.
type groupAccess struct {
	ID          string
	WorkspaceID string
	Name        string
	Description *string
	Type        GroupType
	Template    string
	IsDefault   bool
	IsArchived  bool
	CreatedAt   string

	// IsMember is false for a workspace owner/admin looking at a group they
	// are not in: they may administer it (so no group is ever orphaned) but
	// get no operational capabilities.
	IsMember       bool
	UID            string // the caller's stored uid (the app's "me")
	GroupRole      GroupRole
	FunctionalRole string
	Caps           map[Capability]bool
}

func (a *groupAccess) can(c Capability) bool { return a.Caps[c] }

func (a *groupAccess) require(c Capability) error {
	if a.can(c) {
		return nil
	}
	return forbidden("missing_capability", "دورك في المجموعة دي مايسمحش بالعملية دي.")
}

func (a *groupAccess) json() map[string]any {
	return map[string]any{
		"id":              a.ID,
		"name":            a.Name,
		"description":     a.Description,
		"type":            a.Type,
		"template":        a.Template,
		"is_default":      a.IsDefault,
		"is_archived":     a.IsArchived,
		"created_at":      a.CreatedAt,
		"is_member":       a.IsMember,
		"uid":             a.UID,
		"group_role":      nullIfEmpty(string(a.GroupRole)),
		"functional_role": nullIfEmpty(a.FunctionalRole),
		"capabilities":    sortedCaps(a.Caps),
	}
}

func nullIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

// loadGroupAccess resolves gid inside the active workspace for the caller.
func (s *store) loadGroupAccess(ctx context.Context, ws *Workspace, uid, gid string) (*groupAccess, error) {
	a := &groupAccess{UID: uid}
	var isDefault, isArchived int
	err := s.db.QueryRowContext(ctx, `
		select id, workspace_id, name, description, type, template, is_default,
		       is_archived, created_at
		from groups where id = ? and workspace_id = ?`, gid, ws.ID,
	).Scan(&a.ID, &a.WorkspaceID, &a.Name, &a.Description, &a.Type, &a.Template,
		&isDefault, &isArchived, &a.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, notFound("group_not_found", "المجموعة مش موجودة في مساحة العمل دي.")
	}
	if err != nil {
		return nil, err
	}
	a.IsDefault, a.IsArchived = isDefault == 1, isArchived == 1

	var groupRole string
	err = s.db.QueryRowContext(ctx,
		`select group_role, functional_role from group_members where group_id = ? and user_uid = ?`,
		gid, uid,
	).Scan(&groupRole, &a.FunctionalRole)
	switch {
	case err == nil:
		a.IsMember = true
		a.GroupRole = GroupRole(groupRole)
		a.Caps = capabilitiesFor(a.Type, a.GroupRole, a.FunctionalRole)
	case errors.Is(err, sql.ErrNoRows):
		if !ws.Role.IsAdmin() {
			return nil, forbidden("not_group_member", "انت مش عضو في المجموعة دي.")
		}
		a.Caps = map[Capability]bool{
			CapViewGroup: true, CapManageGroup: true, CapManageMembers: true,
		}
	default:
		return nil, err
	}
	if a.IsArchived {
		// An archived group is read-only; only un-archiving is allowed.
		for c := range a.Caps {
			if c != CapViewGroup && c != CapManageGroup {
				delete(a.Caps, c)
			}
		}
	}
	return a, nil
}

// groupFromRequest is the common prologue: caller, workspace, group access.
func (s *Server) groupFromRequest(r *http.Request) (*authCaller, *Workspace, *groupAccess, error) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		return nil, nil, nil, err
	}
	access, err := s.store.loadGroupAccess(r.Context(), ws, caller.UID, r.PathValue("gid"))
	if err != nil {
		return nil, nil, nil, err
	}
	return caller, ws, access, nil
}

// --- plan --------------------------------------------------------------------

type planUsage struct {
	PlanID      string `json:"plan"`
	Name        string `json:"name"`
	MaxGroups   int    `json:"max_groups"`
	UsedGroups  int    `json:"used_groups"`
	PriceCents  int    `json:"price_cents_monthly"`
	CanAddGroup bool   `json:"can_add_group"`
}

// planUsageTx counts active (non-archived) groups against the plan. Run it
// in the same transaction as the insert: the single SQLite connection then
// serialises concurrent creates, so two requests cannot both take the last
// slot.
func planUsageTx(ctx context.Context, q interface {
	QueryRowContext(context.Context, string, ...any) *sql.Row
}, workspaceID string) (*planUsage, error) {
	u := &planUsage{}
	if err := q.QueryRowContext(ctx, `
		select p.id, p.name, p.max_groups, p.price_cents_monthly,
		       (select count(*) from groups g where g.workspace_id = w.id and g.is_archived = 0)
		from workspaces w join plans p on p.id = w.plan_id
		where w.id = ?`, workspaceID,
	).Scan(&u.PlanID, &u.Name, &u.MaxGroups, &u.PriceCents, &u.UsedGroups); err != nil {
		return nil, err
	}
	u.CanAddGroup = u.UsedGroups < u.MaxGroups
	return u, nil
}

func groupLimitError(u *planUsage) error {
	return conflict("group_limit_reached", fmt.Sprintf(
		"وصلت للحد الأقصى للمجموعات في خطتك (%d / %d). أرشف مجموعة أو رقّي الخطة.",
		u.UsedGroups, u.MaxGroups))
}

// GET /v1/workspace/plan
func (s *Server) handleWorkspacePlan(w http.ResponseWriter, r *http.Request) {
	_, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	usage, err := planUsageTx(r.Context(), s.store.db, ws.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, usage)
}

// --- groups ------------------------------------------------------------------

// GET /v1/groups — the caller's groups in the active workspace (all of them
// for a workspace owner/admin).
func (s *Server) handleListGroups(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	rows, err := s.store.db.QueryContext(r.Context(), `
		select g.id, g.name, g.type, g.is_default, g.is_archived,
		       gm.group_role, gm.functional_role,
		       (select count(*) from group_members x where x.group_id = g.id),
		       (select count(*) from projects p where p.group_id = g.id and p.is_archived = 0)
		from groups g
		left join group_members gm on gm.group_id = g.id and gm.user_uid = ?
		where g.workspace_id = ? and (gm.user_uid is not null or ?)
		order by g.is_archived, g.is_default desc, g.name`,
		caller.UID, ws.ID, ws.Role.IsAdmin())
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()

	groups := make([]map[string]any, 0)
	for rows.Next() {
		var id, name, groupType string
		var isDefault, isArchived, members, projects int
		var groupRole, functional *string
		if err := rows.Scan(&id, &name, &groupType, &isDefault, &isArchived,
			&groupRole, &functional, &members, &projects); err != nil {
			writeError(w, err)
			return
		}
		groups = append(groups, map[string]any{
			"id":              id,
			"name":            name,
			"type":            groupType,
			"is_default":      isDefault == 1,
			"is_archived":     isArchived == 1,
			"is_member":       groupRole != nil,
			"group_role":      groupRole,
			"functional_role": functional,
			"member_count":    members,
			"project_count":   projects,
		})
	}
	if err := rows.Err(); err != nil {
		writeError(w, err)
		return
	}
	usage, err := planUsageTx(r.Context(), s.store.db, ws.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"groups": groups, "plan": usage})
}

type createGroupRequest struct {
	Name        string  `json:"name"`
	Description *string `json:"description"`
	Type        string  `json:"type"`
	Template    string  `json:"template"`
}

var groupTemplates = map[GroupType]map[string]bool{
	GroupSoftware: {"scrum": true, "kanban": true},
	GroupHardware: {"evt_dvt_pvt": true, "custom": true},
}

// POST /v1/groups — any workspace member except a viewer; the creator leads.
func (s *Server) handleCreateGroup(w http.ResponseWriter, r *http.Request) {
	caller, ws, err := s.callerAndWorkspace(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if !ws.Role.IsEditor() {
		writeError(w, forbidden("viewer_read_only", "العميل مايقدرش يعمل مجموعة."))
		return
	}
	var body createGroupRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	body.Name = strings.TrimSpace(body.Name)
	groupType := GroupType(body.Type)
	switch {
	case body.Name == "":
		writeError(w, badRequest("name_required", "اسم المجموعة مطلوب."))
		return
	case tooLong(body.Name, maxProjectNameLength):
		writeError(w, badRequest("name_too_long",
			fmt.Sprintf("اسم المجموعة أطول من %d حرف.", maxProjectNameLength)))
		return
	case optionalTooLong(body.Description, maxProjectDescLength):
		writeError(w, badRequest("description_too_long",
			fmt.Sprintf("الوصف أطول من %d حرف.", maxProjectDescLength)))
		return
	case !validGroupType(groupType):
		writeError(w, badRequest("invalid_group_type", "نوع المجموعة لازم يكون software أو hardware."))
		return
	}
	if body.Template == "" {
		body.Template = map[GroupType]string{GroupSoftware: "scrum", GroupHardware: "evt_dvt_pvt"}[groupType]
	}
	if !groupTemplates[groupType][body.Template] {
		writeError(w, badRequest("invalid_template", "القالب ده مش متاح لنوع المجموعة."))
		return
	}

	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()

	usage, err := planUsageTx(r.Context(), tx, ws.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	if !usage.CanAddGroup {
		writeError(w, groupLimitError(usage))
		return
	}

	groupID := newID()
	now := nowString()
	if _, err := tx.ExecContext(r.Context(), `
		insert into groups (id, workspace_id, name, description, type, template,
		                    created_by, created_at, updated_at)
		values (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		groupID, ws.ID, body.Name, body.Description, string(groupType), body.Template,
		caller.UID, now, now,
	); err != nil {
		writeError(w, err)
		return
	}
	if err := joinGroup(r.Context(), tx, groupID, caller.UID, GroupLead,
		defaultLeadRole[groupType], now); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	_ = s.store.logActivity(r.Context(), ws.ID, caller.UID, "group_created",
		"مجموعة جديدة: "+body.Name, nil)

	access, err := s.store.loadGroupAccess(r.Context(), ws, caller.UID, groupID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"group": access.json()})
}

// GET /v1/groups/{gid}/me — the caller's roles and capabilities; the app
// builds its routes and buttons from it.
func (s *Server) handleGroupMe(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.groupFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"group": access.json()})
}

type updateGroupRequest struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
	IsArchived  *bool   `json:"is_archived"`
}

// PATCH /v1/groups/{gid} — rename, describe, archive / un-archive.
func (s *Server) handleUpdateGroup(w http.ResponseWriter, r *http.Request) {
	caller, ws, access, err := s.groupFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapManageGroup); err != nil {
		writeError(w, err)
		return
	}
	var body updateGroupRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if body.Name != nil {
		name := strings.TrimSpace(*body.Name)
		if name == "" || tooLong(name, maxProjectNameLength) {
			writeError(w, badRequest("invalid_name",
				fmt.Sprintf("اسم المجموعة لازم يكون من 1 لـ %d حرف.", maxProjectNameLength)))
			return
		}
		body.Name = &name
	}
	if optionalTooLong(body.Description, maxProjectDescLength) {
		writeError(w, badRequest("description_too_long",
			fmt.Sprintf("الوصف أطول من %d حرف.", maxProjectDescLength)))
		return
	}
	if access.IsArchived && body.IsArchived == nil {
		writeError(w, conflict("group_archived", "المجموعة مأرشفة. فك الأرشفة الأول."))
		return
	}
	if body.IsArchived != nil && *body.IsArchived && access.IsDefault {
		writeError(w, conflict("default_group_not_archivable", "المجموعة الافتراضية مينفعش تتأرشف."))
		return
	}

	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()

	// Un-archiving takes a plan slot again.
	if body.IsArchived != nil && !*body.IsArchived && access.IsArchived {
		usage, err := planUsageTx(r.Context(), tx, ws.ID)
		if err != nil {
			writeError(w, err)
			return
		}
		if !usage.CanAddGroup {
			writeError(w, groupLimitError(usage))
			return
		}
	}

	var archived any
	if body.IsArchived != nil {
		archived = boolInt(*body.IsArchived)
	}
	if _, err := tx.ExecContext(r.Context(), `
		update groups set
		  name        = coalesce(?, name),
		  description = coalesce(?, description),
		  is_archived = coalesce(?, is_archived),
		  updated_at  = ?
		where id = ? and workspace_id = ?`,
		body.Name, body.Description, archived, nowString(), access.ID, ws.ID,
	); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	updated, err := s.store.loadGroupAccess(r.Context(), ws, caller.UID, access.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"group": updated.json()})
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

// DELETE /v1/groups/{gid} — the lead, and only an empty group: deleting
// would cascade to every project, task and BOM in it. Archive instead.
func (s *Server) handleDeleteGroup(w http.ResponseWriter, r *http.Request) {
	_, ws, access, err := s.groupFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapDeleteGroup); err != nil {
		writeError(w, err)
		return
	}
	if access.IsDefault {
		writeError(w, conflict("default_group_not_deletable", "المجموعة الافتراضية مينفعش تتحذف."))
		return
	}
	var projects int
	if err := s.store.db.QueryRowContext(r.Context(),
		`select count(*) from projects where group_id = ?`, access.ID).Scan(&projects); err != nil {
		writeError(w, err)
		return
	}
	if projects > 0 {
		writeError(w, conflict("group_has_projects",
			"المجموعة فيها مشاريع. أرشفها بدل الحذف، أو انقل المشاريع الأول."))
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(),
		`delete from groups where id = ? and workspace_id = ?`, access.ID, ws.ID); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

type transferLeadRequest struct {
	UID string `json:"uid"`
}

// POST /v1/groups/{gid}/transfer — the lead hands the group to another
// member and becomes an admin.
func (s *Server) handleTransferGroupLead(w http.ResponseWriter, r *http.Request) {
	caller, _, access, err := s.groupFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if access.GroupRole != GroupLead {
		writeError(w, forbidden("lead_only", "نقل القيادة خاص بقائد المجموعة."))
		return
	}
	var body transferLeadRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	if body.UID == "" || body.UID == caller.UID {
		writeError(w, badRequest("invalid_target", "اختار عضو تاني."))
		return
	}

	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()

	var targetRole string
	err = tx.QueryRowContext(r.Context(),
		`select group_role from group_members where group_id = ? and user_uid = ?`,
		access.ID, body.UID).Scan(&targetRole)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("member_not_found", "العضو مش في المجموعة."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if GroupRole(targetRole) == GroupGuest {
		writeError(w, conflict("guest_cannot_lead", "الضيف مينفعش يبقى قائد المجموعة."))
		return
	}
	// Demote first: the single-lead index allows one lead at a time.
	if _, err := tx.ExecContext(r.Context(),
		`update group_members set group_role = 'admin' where group_id = ? and user_uid = ?`,
		access.ID, caller.UID); err != nil {
		writeError(w, err)
		return
	}
	if _, err := tx.ExecContext(r.Context(),
		`update group_members set group_role = 'lead' where group_id = ? and user_uid = ?`,
		access.ID, body.UID); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// --- members -----------------------------------------------------------------

// GET /v1/groups/{gid}/members — a guest sees names and roles, no e-mails.
func (s *Server) handleListGroupMembers(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.groupFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	rows, err := s.store.db.QueryContext(r.Context(), `
		select gm.user_uid, u.display_name, u.email, u.photo_url, gm.group_role,
		       gm.functional_role, gm.created_at
		from group_members gm
		left join users u on u.uid = gm.user_uid
		where gm.group_id = ?
		order by case gm.group_role when 'lead' then 0 when 'admin' then 1
		                            when 'member' then 2 else 3 end, gm.created_at`,
		access.ID)
	if err != nil {
		writeError(w, err)
		return
	}
	defer rows.Close()

	hideEmails := access.IsMember && access.GroupRole == GroupGuest
	members := make([]map[string]any, 0)
	for rows.Next() {
		var uid, groupRole, functional, joined string
		var name, email, photo *string
		if err := rows.Scan(&uid, &name, &email, &photo, &groupRole, &functional, &joined); err != nil {
			writeError(w, err)
			return
		}
		if hideEmails {
			email = nil
		}
		members = append(members, map[string]any{
			"uid":             uid,
			"name":            firstNonEmpty(name, &uid),
			"email":           email,
			"avatar_url":      photo,
			"group_role":      groupRole,
			"functional_role": functional,
			"joined_at":       joined,
		})
	}
	if err := rows.Err(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"members": members})
}

type updateGroupMemberRequest struct {
	GroupRole      *string `json:"group_role"`
	FunctionalRole *string `json:"functional_role"`
}

// canManageRole: the lead manages everyone; an admin manages members and
// guests only (cannot create, demote or remove another admin).
func canManageRole(actor *groupAccess, current, next GroupRole) error {
	if current == GroupLead || next == GroupLead {
		return forbidden("use_transfer", "القيادة بتتنقل من «نقل القيادة» بس.")
	}
	if actor.GroupRole == GroupLead || !actor.IsMember {
		return nil
	}
	if current == GroupAdmin || next == GroupAdmin {
		return forbidden("admin_requires_lead", "تعيين أو تغيير مساعد خاص بقائد المجموعة.")
	}
	return nil
}

// PATCH /v1/groups/{gid}/members/{uid}
func (s *Server) handleUpdateGroupMember(w http.ResponseWriter, r *http.Request) {
	_, _, access, err := s.groupFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapManageMembers); err != nil {
		writeError(w, err)
		return
	}
	var body updateGroupMemberRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	target := r.PathValue("uid")

	tx, err := s.store.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, err)
		return
	}
	defer func() { _ = tx.Rollback() }()

	var currentRole, currentFunctional string
	err = tx.QueryRowContext(r.Context(),
		`select group_role, functional_role from group_members where group_id = ? and user_uid = ?`,
		access.ID, target).Scan(&currentRole, &currentFunctional)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("member_not_found", "العضو مش في المجموعة."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}

	nextRole := GroupRole(currentRole)
	if body.GroupRole != nil {
		nextRole = GroupRole(*body.GroupRole)
		if !nextRole.valid() {
			writeError(w, badRequest("invalid_group_role", "الدور الإداري غير معروف."))
			return
		}
	}
	nextFunctional := currentFunctional
	if body.FunctionalRole != nil {
		nextFunctional = *body.FunctionalRole
	}
	if err := canManageRole(access, GroupRole(currentRole), nextRole); err != nil {
		writeError(w, err)
		return
	}
	if nextRole == GroupGuest {
		nextFunctional = "client"
	} else if nextFunctional == "client" {
		writeError(w, badRequest("client_is_guest", "دور العميل لازم يكون ضيف."))
		return
	}
	if !validFunctionalRole(access.Type, nextFunctional) {
		writeError(w, badRequest("invalid_functional_role", "الدور الوظيفي مش متاح لنوع المجموعة."))
		return
	}

	if _, err := tx.ExecContext(r.Context(), `
		update group_members set group_role = ?, functional_role = ?
		 where group_id = ? and user_uid = ?`,
		string(nextRole), nextFunctional, access.ID, target); err != nil {
		writeError(w, err)
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"uid": target, "group_role": nextRole, "functional_role": nextFunctional,
	})
}

// DELETE /v1/groups/{gid}/members/{uid} — remove someone, or leave (uid =
// yourself). The lead transfers first.
func (s *Server) handleRemoveGroupMember(w http.ResponseWriter, r *http.Request) {
	caller, _, access, err := s.groupFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	target := r.PathValue("uid")
	leaving := target == caller.UID
	if !leaving {
		if err := access.require(CapManageMembers); err != nil {
			writeError(w, err)
			return
		}
	}

	var currentRole string
	err = s.store.db.QueryRowContext(r.Context(),
		`select group_role from group_members where group_id = ? and user_uid = ?`,
		access.ID, target).Scan(&currentRole)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, notFound("member_not_found", "العضو مش في المجموعة."))
		return
	}
	if err != nil {
		writeError(w, err)
		return
	}
	if GroupRole(currentRole) == GroupLead {
		writeError(w, conflict("lead_must_transfer", "قائد المجموعة لازم ينقل القيادة الأول."))
		return
	}
	if !leaving && GroupRole(currentRole) == GroupAdmin && access.IsMember && access.GroupRole != GroupLead {
		writeError(w, forbidden("admin_requires_lead", "إزالة مساعد خاصة بقائد المجموعة."))
		return
	}
	if _, err := s.store.db.ExecContext(r.Context(),
		`delete from group_members where group_id = ? and user_uid = ?`, access.ID, target); err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

type groupInviteRequest struct {
	Emails         []string `json:"emails"`
	GroupRole      string   `json:"group_role"`
	FunctionalRole string   `json:"functional_role"`
}

// defaultMemberRole is the functional role an invite gets when none is given.
var defaultMemberRole = map[GroupType]string{
	GroupSoftware: "developer",
	GroupHardware: "electrical",
}

// POST /v1/groups/{gid}/invites — invite with the role preset; accepting
// joins the workspace and this group.
func (s *Server) handleSendGroupInvites(w http.ResponseWriter, r *http.Request) {
	caller, ws, access, err := s.groupFromRequest(r)
	if err != nil {
		writeError(w, err)
		return
	}
	if err := access.require(CapManageMembers); err != nil {
		writeError(w, err)
		return
	}
	var body groupInviteRequest
	if err := decodeBody(r, &body); err != nil {
		writeError(w, err)
		return
	}
	role := GroupRole(body.GroupRole)
	if role == "" {
		role = GroupMember
	}
	if !role.valid() {
		writeError(w, badRequest("invalid_group_role", "الدور الإداري غير معروف."))
		return
	}
	if err := canManageRole(access, GroupMember, role); err != nil {
		writeError(w, err)
		return
	}
	functional := body.FunctionalRole
	if role == GroupGuest {
		functional = "client"
	} else if functional == "" {
		functional = defaultMemberRole[access.Type]
	}
	if functional == "client" && role != GroupGuest {
		writeError(w, badRequest("client_is_guest", "دور العميل لازم يكون ضيف."))
		return
	}
	if !validFunctionalRole(access.Type, functional) {
		writeError(w, badRequest("invalid_functional_role", "الدور الوظيفي مش متاح لنوع المجموعة."))
		return
	}

	created, err := s.storeInvites(r, ws, caller.UID, body.Emails, inviteSpec{
		WorkspaceRole:  workspaceRoleFor(role),
		GroupID:        access.ID,
		GroupRole:      role,
		FunctionalRole: functional,
		Label:          functional,
	})
	if err != nil {
		writeError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]int{"created": created})
}
