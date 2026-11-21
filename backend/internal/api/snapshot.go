package api

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"strconv"

	"github.com/workspaccode/6dx/backend/internal/auth"
)

// snapshot builds the one payload every screen reads.
//
// Previously this was the `get_workspace_snapshot()` SQL function.
// SQLite has no plpgsql, so the projection is assembled here — and the JSON
// shape is byte-for-byte the one `WorkspaceSnapshotMapper` already consumes, so
// no screen changed.
func (s *store) snapshot(ctx context.Context, workspaceID, callerUID string) (map[string]any, error) {
	var (
		name string
	)
	if err := s.db.QueryRowContext(ctx,
		`select name from workspaces where id = ?`, workspaceID,
	).Scan(&name); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	// Membership is a second line of defence after the middleware.
	role, err := s.RoleIn(ctx, workspaceID, callerUID)
	if err != nil {
		return nil, err
	}
	if role == "" {
		return nil, nil
	}

	members, err := s.snapshotMembers(ctx, workspaceID, role)
	if err != nil {
		return nil, err
	}
	// The invite list holds outsiders' e-mails and who invited them; only the
	// people who manage invites need it.
	invites := make([]any, 0)
	if role.IsAdmin() {
		invites, err = s.snapshotInvites(ctx, workspaceID)
		if err != nil {
			return nil, err
		}
	}
	tasks, taskNames, err := s.snapshotTasks(ctx, workspaceID)
	if err != nil {
		return nil, err
	}
	comments, subtasks, err := s.snapshotTaskDetails(ctx, workspaceID)
	if err != nil {
		return nil, err
	}
	dependencies, err := s.snapshotDependencies(ctx, workspaceID, taskNames)
	if err != nil {
		return nil, err
	}
	activity, err := s.snapshotActivity(ctx, workspaceID)
	if err != nil {
		return nil, err
	}
	sprints, err := s.snapshotSprints(ctx, workspaceID, taskNames)
	if err != nil {
		return nil, err
	}
	pullRequests, err := s.snapshotPullRequests(ctx, workspaceID)
	if err != nil {
		return nil, err
	}
	labels, repositories, err := s.snapshotProjectExtras(ctx, workspaceID)
	if err != nil {
		return nil, err
	}
	integrations, err := s.snapshotIntegrations(ctx, workspaceID)
	if err != nil {
		return nil, err
	}
	notifications, digest, err := s.snapshotUserSurfaces(ctx, workspaceID, callerUID)
	if err != nil {
		return nil, err
	}
	clientReport, err := s.snapshotClientReport(ctx, workspaceID, callerUID, role)
	if err != nil {
		return nil, err
	}

	return map[string]any{
		"workspace_id":   workspaceID,
		"name":           name,
		"members":        members,
		"invites":        invites,
		"tasks":          tasks,
		"comments":       comments,
		"subtasks":       subtasks,
		"dependencies":   dependencies,
		"activity":       activity,
		"sprints":        sprints,
		"pull_requests":  pullRequests,
		"labels":         labels,
		"integrations":   integrations,
		"repositories":   repositories,
		"notifications":  notifications,
		"digest":         digest,
		"client_report":  clientReport,
	}, nil
}

// snapshotMembers lists the team. A viewer is the external client: they see
// names and roles, never the team's e-mail addresses.
func (s *store) snapshotMembers(ctx context.Context, wsID string, viewerRole Role) ([]any, error) {
	rows, err := s.db.QueryContext(ctx, `
		select m.user_uid, u.email, u.display_name, u.photo_url, m.role,
		       (select count(*) from tasks t
		         where t.workspace_id = m.workspace_id
		           and t.assignee_uid = m.user_uid and t.status <> 'done')
		from workspace_members m
		left join users u on u.uid = m.user_uid
		where m.workspace_id = ?
		order by m.created_at`, wsID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]any, 0)
	for rows.Next() {
		var uid, role string
		var email, displayName, photoURL *string
		var openTasks int
		if err := rows.Scan(&uid, &email, &displayName, &photoURL, &role, &openTasks); err != nil {
			return nil, err
		}
		name := firstNonEmpty(displayName, email, &uid)
		if viewerRole == RoleViewer {
			email = nil
			name = firstNonEmpty(displayName, &uid)
		}
		out = append(out, map[string]any{
			"id":         uid,
			"name":       name,
			"role":       role,
			"email":      email,
			"avatar_url": photoURL,
			"open_tasks": openTasks,
			"is_online":  false,
		})
	}
	return out, rows.Err()
}

func (s *store) snapshotInvites(ctx context.Context, wsID string) ([]any, error) {
	rows, err := s.db.QueryContext(ctx, `
		select i.id, i.email, i.role, i.status, i.sent_at,
		       (select coalesce(nullif(u.display_name, ''), u.email)
		          from users u where u.uid = i.invited_by)
		from workspace_invites i
		where i.workspace_id = ?
		order by i.sent_at desc`, wsID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]any, 0)
	for rows.Next() {
		var id, email, role, status, sentAt string
		var invitedBy *string
		if err := rows.Scan(&id, &email, &role, &status, &sentAt, &invitedBy); err != nil {
			return nil, err
		}
		out = append(out, map[string]any{
			"id":         id,
			"email":      email,
			"role":       role,
			"status":     status,
			"sent_at":    sentAt,
			"invited_by": invitedBy,
		})
	}
	return out, rows.Err()
}

func (s *store) snapshotTasks(ctx context.Context, wsID string) ([]any, map[string]taskInfo, error) {
	rows, err := s.db.QueryContext(ctx, `
		select t.id, t.key, t.title, t.description, t.status, t.priority, t.points,
		       t.project_id, p.name, t.assignee_uid,
		       (select coalesce(nullif(u.display_name, ''), u.email)
		          from users u where u.uid = t.assignee_uid),
		       t.label, t.branch, t.pr_number, t.due_at, t.created_at
		from tasks t
		left join projects p on p.id = t.project_id
		where t.workspace_id = ?
		order by t.created_at desc`, wsID)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()

	out := make([]any, 0)
	names := map[string]taskInfo{}
	for rows.Next() {
		var (
			id, title, status, priority string
			key, description, projectID *string
			projectName, assigneeUID   *string
			assigneeName, label, branch *string
			dueAt, createdAt           *string
			prNumber                   *int
			points                     int
		)
		if err := rows.Scan(&id, &key, &title, &description, &status, &priority, &points,
			&projectID, &projectName, &assigneeUID, &assigneeName, &label, &branch,
			&prNumber, &dueAt, &createdAt); err != nil {
			return nil, nil, err
		}
		names[id] = taskInfo{Key: key, Title: title, AssigneeName: assigneeName}
		out = append(out, map[string]any{
			"id":            id,
			"key":           key,
			"title":         title,
			"description":   description,
			"status":        status,
			"priority":      priority,
			"points":        points,
			"project_id":    projectID,
			"project_name":  projectName,
			"assignee_id":   assigneeUID,
			"assignee_name": assigneeName,
			"label":         label,
			"branch":        branch,
			"pr_number":     prNumber,
			"due_at":        dueAt,
			"created_at":    createdAt,
		})
	}
	return out, names, rows.Err()
}

type taskInfo struct {
	Key          *string
	Title        string
	AssigneeName *string
}

func (s *store) snapshotTaskDetails(ctx context.Context, wsID string) ([]any, []any, error) {
	commentRows, err := s.db.QueryContext(ctx, `
		select c.id, c.task_id,
		       (select coalesce(nullif(u.display_name, ''), u.email)
		          from users u where u.uid = c.author_uid),
		       c.body, c.attachment, c.code, c.created_at
		from task_comments c
		join tasks t on t.id = c.task_id
		where t.workspace_id = ?
		order by c.created_at`, wsID)
	if err != nil {
		return nil, nil, err
	}
	defer commentRows.Close()

	comments := make([]any, 0)
	for commentRows.Next() {
		var id, taskID, body, createdAt string
		var author, attachment, code *string
		if err := commentRows.Scan(&id, &taskID, &author, &body, &attachment, &code, &createdAt); err != nil {
			return nil, nil, err
		}
		comments = append(comments, map[string]any{
			"id":         id,
			"task_id":    taskID,
			"author":     author,
			"body":       body,
			"attachment": attachment,
			"code":       code,
			"created_at": createdAt,
		})
	}

	subtaskRows, err := s.db.QueryContext(ctx, `
		select sc.id, sc.task_id, sc.title, sc.is_done
		from task_subtasks sc
		join tasks t on t.id = sc.task_id
		where t.workspace_id = ?`, wsID)
	if err != nil {
		return nil, nil, err
	}
	defer subtaskRows.Close()

	subtasks := make([]any, 0)
	for subtaskRows.Next() {
		var id, taskID, title string
		var done int
		if err := subtaskRows.Scan(&id, &taskID, &title, &done); err != nil {
			return nil, nil, err
		}
		subtasks = append(subtasks, map[string]any{
			"id":      id,
			"task_id": taskID,
			"title":   title,
			"is_done": done != 0,
		})
	}
	return comments, subtasks, nil
}

func (s *store) snapshotDependencies(ctx context.Context, wsID string, tasks map[string]taskInfo) ([]any, error) {
	rows, err := s.db.QueryContext(ctx, `
		select d.id, d.task_id, d.state, d.reason
		from task_dependencies d
		join tasks t on t.id = d.task_id
		where t.workspace_id = ?`, wsID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]any, 0)
	for rows.Next() {
		var id, taskID, state string
		var reason *string
		if err := rows.Scan(&id, &taskID, &state, &reason); err != nil {
			return nil, err
		}
		info := tasks[taskID]
		out = append(out, map[string]any{
			"id":            id,
			"task_id":       taskID,
			"task_key":      derefOr(info.Key, ""),
			"title":         info.Title,
			"state":         state,
			"reason":        reason,
			"assignee_name": info.AssigneeName,
		})
	}
	return out, rows.Err()
}

func (s *store) snapshotActivity(ctx context.Context, wsID string) ([]any, error) {
	rows, err := s.db.QueryContext(ctx, `
		select a.id, a.type, a.text,
		       (select coalesce(nullif(u.display_name, ''), u.email)
		          from users u where u.uid = a.actor_uid),
		       a.created_at
		from activity_events a
		where a.workspace_id = ?
		order by a.created_at desc
		limit 200`, wsID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]any, 0)
	for rows.Next() {
		var id, kind, text, createdAt string
		var actor *string
		if err := rows.Scan(&id, &kind, &text, &actor, &createdAt); err != nil {
			return nil, err
		}
		out = append(out, map[string]any{
			"id":    id,
			"type":  kind,
			"text":  text,
			"actor": actor,
			"at":    createdAt,
		})
	}
	return out, rows.Err()
}

func (s *store) snapshotSprints(ctx context.Context, wsID string, tasks map[string]taskInfo) ([]any, error) {
	rows, err := s.db.QueryContext(ctx, `
		select id, name, goal, starts_at, ends_at, capacity, committed
		from sprints where workspace_id = ?
		order by starts_at`, wsID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	type sprintRow struct {
		id, name, startsAt, endsAt string
		goal                       *string
		capacity, committed        int
	}
	sprints := make([]sprintRow, 0)
	for rows.Next() {
		var row sprintRow
		if err := rows.Scan(&row.id, &row.name, &row.goal, &row.startsAt, &row.endsAt,
			&row.capacity, &row.committed); err != nil {
			return nil, err
		}
		sprints = append(sprints, row)
	}

	out := make([]any, 0)
	for _, sprint := range sprints {
		items, err := s.snapshotSprintItems(ctx, sprint.id, tasks)
		if err != nil {
			return nil, err
		}
		out = append(out, map[string]any{
			"id":        sprint.id,
			"name":      sprint.name,
			"goal":      sprint.goal,
			"start":     sprint.startsAt,
			"end":       sprint.endsAt,
			"capacity":  sprint.capacity,
			"committed": sprint.committed,
			"items":     items,
		})
	}
	return out, nil
}

func (s *store) snapshotSprintItems(ctx context.Context, sprintID string, tasks map[string]taskInfo) ([]any, error) {
	rows, err := s.db.QueryContext(ctx, `
		select si.task_id, si.points, t.key, t.title, t.assignee_uid
		from sprint_items si
		join tasks t on t.id = si.task_id
		where si.sprint_id = ?`, sprintID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]any, 0)
	for rows.Next() {
		var taskID, title string
		var points int
		var key, assignee *string
		if err := rows.Scan(&taskID, &points, &key, &title, &assignee); err != nil {
			return nil, err
		}
		out = append(out, map[string]any{
			"task_id":     taskID,
			"key":         key,
			"title":       title,
			"points":      points,
			"assignee_id": assignee,
		})
	}
	return out, rows.Err()
}

func (s *store) snapshotPullRequests(ctx context.Context, wsID string) ([]any, error) {
	rows, err := s.db.QueryContext(ctx, `
		select pr.id, pr.number, pr.title, pr.author, pr.branch, pr.base_branch,
		       pr.state, pr.checks, pr.files, pr.additions, pr.deletions,
		       (select coalesce(nullif(u.display_name, ''), u.email)
		          from users u where u.uid = pr.reviewer_uid),
		       pr.last_commit,
		       (select t.key from tasks t where t.id = pr.task_id),
		       (select p.name from projects p where p.id = pr.project_id)
		from pull_requests pr
		where pr.workspace_id = ?`, wsID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]any, 0)
	for rows.Next() {
		var (
			id, title, state string
			number           int
			additions        int
			deletions        int
			author           *string
			branch           string
			baseBranch       string
			checks, files    string
			lastCommit       *string
			reviewerName     *string
			issueKey         *string
			projectName      *string
		)
		if err := rows.Scan(&id, &number, &title, &author, &branch, &baseBranch,
			&state, &checks, &files, &additions, &deletions, &reviewerName,
			&lastCommit, &issueKey, &projectName); err != nil {
			return nil, err
		}
		out = append(out, map[string]any{
			"id":                 id,
			"number":             number,
			"title":              title,
			"author":             author,
			"branch":             branch,
			"base_branch":        baseBranch,
			"state":              state,
			"issue_key":          issueKey,
			"project_name":       projectName,
			"checks":             decodeJSONArray(checks),
			"files":              decodeJSONArray(files),
			"additions":          additions,
			"deletions":          deletions,
			"reviewer_name":      reviewerName,
			"last_commit":        lastCommit,
			"last_commit_author": nil,
			"waiting_hours":      0,
		})
	}
	return out, rows.Err()
}

func (s *store) snapshotProjectExtras(ctx context.Context, wsID string) ([]any, []any, error) {
	labelRows, err := s.db.QueryContext(ctx, `
		select l.id, l.name, l.color
		from project_labels l
		join projects p on p.id = l.project_id
		where p.workspace_id = ?`, wsID)
	if err != nil {
		return nil, nil, err
	}
	defer labelRows.Close()

	labels := make([]any, 0)
	for labelRows.Next() {
		var id, name, color string
		if err := labelRows.Scan(&id, &name, &color); err != nil {
			return nil, nil, err
		}
		labels = append(labels, map[string]any{"id": id, "name": name, "color": color})
	}

	repoRows, err := s.db.QueryContext(ctx, `
		select r.id, r.full_name, r.branch, r.description, r.language, r.last_synced_at
		from repositories r
		join projects p on p.id = r.project_id
		where p.workspace_id = ?`, wsID)
	if err != nil {
		return nil, nil, err
	}
	defer repoRows.Close()

	repositories := make([]any, 0)
	for repoRows.Next() {
		var id, fullName, branch string
		var description, language, lastSynced *string
		if err := repoRows.Scan(&id, &fullName, &branch, &description, &language, &lastSynced); err != nil {
			return nil, nil, err
		}
		repositories = append(repositories, map[string]any{
			"id":             id,
			"full_name":      fullName,
			"branch":         branch,
			"description":    description,
			"language":       language,
			"last_synced_at": lastSynced,
		})
	}
	return labels, repositories, nil
}

func (s *store) snapshotIntegrations(ctx context.Context, wsID string) ([]any, error) {
	rows, err := s.db.QueryContext(ctx, `
		select id, name, kind, connected, workspace, channels, events
		from integrations where workspace_id = ?`, wsID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]any, 0)
	for rows.Next() {
		var id, name, kind, channels, events string
		var connected int
		var workspaceName *string
		if err := rows.Scan(&id, &name, &kind, &connected, &workspaceName,
			&channels, &events); err != nil {
			return nil, err
		}
		out = append(out, map[string]any{
			"id":        id,
			"name":      name,
			"kind":      kind,
			"connected": connected != 0,
			"workspace": workspaceName,
			"channels":  decodeJSONArray(channels),
			"events":    decodeJSONArray(events),
		})
	}
	return out, rows.Err()
}

func (s *store) snapshotUserSurfaces(ctx context.Context, wsID, uid string) ([]any, []any, error) {
	notificationRows, err := s.db.QueryContext(ctx, `
		select id, kind, title, body, action_label, project_id, invite_id, is_read, created_at
		from notifications
		where user_uid = ? and workspace_id = ?
		order by created_at desc
		limit 100`, uid, wsID)
	if err != nil {
		return nil, nil, err
	}
	defer notificationRows.Close()

	notifications := make([]any, 0)
	for notificationRows.Next() {
		var id, kind, title, body, createdAt string
		var actionLabel, projectID, inviteID *string
		var isRead int
		if err := notificationRows.Scan(&id, &kind, &title, &body, &actionLabel,
			&projectID, &inviteID, &isRead, &createdAt); err != nil {
			return nil, nil, err
		}
		notifications = append(notifications, map[string]any{
			"id":           id,
			"kind":         kind,
			"title":        title,
			"body":         body,
			"action_label": actionLabel,
			"project_id":   projectID,
			"invite_id":    inviteID,
			"unread":       isRead == 0,
			"at":           createdAt,
		})
	}

	digestRows, err := s.db.QueryContext(ctx, `
		select id, section, text, meta, action_label, tone
		from digest_entries where workspace_id = ? and user_uid = ?`, wsID, uid)
	if err != nil {
		return nil, nil, err
	}
	defer digestRows.Close()

	digest := make([]any, 0)
	for digestRows.Next() {
		var id, section, text string
		var meta, actionLabel, tone *string
		if err := digestRows.Scan(&id, &section, &text, &meta, &actionLabel, &tone); err != nil {
			return nil, nil, err
		}
		digest = append(digest, map[string]any{
			"id":           id,
			"section":      section,
			"text":         text,
			"meta":         meta,
			"action_label": actionLabel,
			"tone":         tone,
		})
	}
	return notifications, digest, nil
}

func (s *store) snapshotClientReport(ctx context.Context, wsID, uid string, role Role) (any, error) {
	var (
		clientName, projectName        string
		period, nextMilestone          *string
		milestoneDate                  *string
		decisionQuestion, decisionChoice *string
		totalHours, hourlyRate, invoiceNumber *string
		decisionOptions, weeklyHighlights, deliveredItems, invoiceLines string
		progress                       float64
	)
	err := s.db.QueryRowContext(ctx, `
		select client_name, project_name, period, progress, next_milestone,
		       milestone_date, decision_question, decision_options,
		       weekly_highlights, invoice_lines, total_hours, hourly_rate,
		       invoice_number, delivered_items, decision_choice
		from client_reports where workspace_id = ? limit 1`, wsID,
	).Scan(&clientName, &projectName, &period, &progress, &nextMilestone,
		&milestoneDate, &decisionQuestion, &decisionOptions, &weeklyHighlights,
		&invoiceLines, &totalHours, &hourlyRate, &invoiceNumber, &deliveredItems,
		&decisionChoice)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	timeEntries, err := s.snapshotTimeEntries(ctx, wsID, uid)
	if err != nil {
		return nil, err
	}
	weekByClient := make([]any, 0, len(timeEntries))
	for _, entry := range timeEntries {
		asMap, ok := entry.(map[string]any)
		if !ok {
			continue
		}
		weekByClient = append(weekByClient, map[string]any{
			"client": asMap["client_name"],
			"hours":  asMap["span"],
		})
	}

	report := map[string]any{
		"client_name":       clientName,
		"project_name":      projectName,
		"period":            period,
		"progress":          progress,
		"next_milestone":    nextMilestone,
		"milestone_date":    milestoneDate,
		"decision_question": decisionQuestion,
		"decision_options":  decodeJSONArray(decisionOptions),
		"weekly_highlights": decodeJSONArray(weeklyHighlights),
		"invoice_lines":     decodeJSONArray(invoiceLines),
		"total_hours":       totalHours,
		"hourly_rate":       hourlyRate,
		"invoice_number":    invoiceNumber,
		"delivered_items":   decodeJSONArray(deliveredItems),
		"decision_choice":   decisionChoice,
		"time_entries":      timeEntries,
		"week_by_client":    weekByClient,
	}
	// Rates and invoices are between the agency and the client: admins and
	// the client (viewer) see them, the rest of the team does not.
	if !role.IsAdmin() && role != RoleViewer {
		report["invoice_lines"] = []any{}
		report["hourly_rate"] = nil
		report["invoice_number"] = nil
	}
	return report, nil
}

func (s *store) snapshotTimeEntries(ctx context.Context, wsID, uid string) ([]any, error) {
	rows, err := s.db.QueryContext(ctx, `
		select id, kind, span, branch, client_name, created_at
		from time_entries where workspace_id = ? and user_uid = ?`, wsID, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]any, 0)
	for rows.Next() {
		var id, kind, span, createdAt string
		var branch, clientName *string
		if err := rows.Scan(&id, &kind, &span, &branch, &clientName, &createdAt); err != nil {
			return nil, err
		}
		out = append(out, map[string]any{
			"id":          id,
			"kind":        kind,
			"span":        span,
			"branch":      branch,
			"client_name": clientName,
		})
	}
	return out, rows.Err()
}

// --- helpers ----------------------------------------------------------------

func firstNonEmpty(values ...*string) *string {
	for _, value := range values {
		if value != nil && *value != "" {
			return value
		}
	}
	return nil
}

func derefOr(value *string, fallback string) string {
	if value == nil {
		return fallback
	}
	return *value
}

// decodeJSONArray turns the stored text back into a slice. A malformed value
// degrades to an empty list rather than breaking the whole snapshot.
func decodeJSONArray(raw string) []any {
	if raw == "" {
		return []any{}
	}
	var out []any
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return []any{}
	}
	return out
}

// encodeJSONArray is the write side; a nil slice stores `[]`.
func encodeJSONArray(values []string) string {
	if values == nil {
		return "[]"
	}
	encoded, err := json.Marshal(values)
	if err != nil {
		return "[]"
	}
	return string(encoded)
}

var _ = strconv.Itoa
var _ = auth.FromContext
