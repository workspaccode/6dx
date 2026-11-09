-- 6DX backend — Postgres schema.
--
-- Ported from the Supabase migrations (supabase/migrations/0001..0008) with two
-- deliberate changes:
--   * `auth.users (uuid)` becomes `users (uid text)` — the Firebase UID is the
--     primary key, so no local auth table is needed;
--   * row level security is gone: the API is the only client of this database
--     and it enforces the same rules in Go (see internal/api/authz.go). All
--     policies are reproduced as explicit checks there.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type member_role      as enum ('owner', 'admin', 'developer', 'reviewer', 'viewer');
create type invite_status     as enum ('pending', 'accepted', 'expired', 'revoked');
create type task_status       as enum ('todo', 'in_progress', 'review', 'done');
create type task_priority     as enum ('low', 'medium', 'high', 'urgent');
create type dependency_state  as enum ('blocked', 'blocking', 'review');
create type integration_kind  as enum ('slack', 'discord', 'teams');

-- ---------------------------------------------------------------------------
-- Users (Firebase identities)
-- ---------------------------------------------------------------------------
create table users (
  uid          text primary key,
  email        text,
  display_name text,
  photo_url    text,
  -- The numeric GitHub id, taken from the Firebase token's `github.com`
  -- identity. It is what links a GitHub account to a 6DX account, and it is
  -- the only trusted source for the recovery path of the install flow.
  github_id    bigint,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create unique index users_email_idx on users (lower(email)) where email is not null;
create unique index users_github_id_idx on users (github_id) where github_id is not null;

-- ---------------------------------------------------------------------------
-- Workspaces & members
-- ---------------------------------------------------------------------------
create table workspaces (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slug        text unique not null,
  owner_uid   text not null references users (uid) on delete restrict,
  settings    jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table workspace_members (
  workspace_id uuid not null references workspaces (id) on delete cascade,
  user_uid     text not null references users (uid) on delete cascade,
  role         member_role not null default 'developer',
  created_at   timestamptz not null default now(),
  primary key (workspace_id, user_uid)
);

-- One owner per workspace, guaranteed by the database rather than by the API
-- (the Supabase backend called this `workspace_members_single_owner_idx`).
create unique index workspace_members_single_owner_idx
  on workspace_members (workspace_id)
  where role = 'owner';

create table workspace_invites (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  email        text not null,
  role         member_role not null default 'developer',
  status       invite_status not null default 'pending',
  invited_by   text references users (uid) on delete set null,
  sent_at      timestamptz not null default now(),
  expires_at   timestamptz not null default (now() + interval '7 days')
);

create index workspace_invites_email_idx on workspace_invites (lower(email), status);
create unique index workspace_invites_pending_idx
  on workspace_invites (workspace_id, lower(email))
  where status = 'pending';

-- ---------------------------------------------------------------------------
-- Projects
-- ---------------------------------------------------------------------------
create table projects (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  name         text not null,
  description  text,
  icon         text,
  color        text,
  is_archived  boolean not null default false,
  created_by   text references users (uid) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table repositories (
  id             uuid primary key default gen_random_uuid(),
  project_id     uuid not null references projects (id) on delete cascade,
  provider       text not null default 'github',
  full_name      text not null,
  branch         text not null default 'main',
  description    text,
  language       text,
  last_synced_at timestamptz
);

create table project_labels (
  id         uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects (id) on delete cascade,
  name       text not null,
  color      text not null default '#9AA3B2',
  unique (project_id, name)
);

create table integrations (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  kind         integration_kind not null,
  name         text not null,
  connected    boolean not null default false,
  workspace    text,
  channels     text[] not null default '{}',
  events       text[] not null default '{}',
  unique (workspace_id, kind)
);

-- ---------------------------------------------------------------------------
-- Sprints & tasks
-- ---------------------------------------------------------------------------
create table sprints (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  project_id   uuid references projects (id) on delete cascade,
  name         text not null,
  goal         text,
  starts_at    date not null,
  ends_at      date not null,
  capacity     integer not null default 0,
  committed    integer not null default 0,
  created_at   timestamptz not null default now()
);

create table tasks (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  project_id   uuid references projects (id) on delete cascade,
  sprint_id    uuid references sprints (id) on delete set null,
  key          text,
  title        text not null,
  description  text,
  status       task_status not null default 'todo',
  priority     task_priority not null default 'medium',
  points       integer not null default 0,
  assignee_uid text references users (uid) on delete set null,
  label        text,
  branch       text,
  pr_number    integer,
  due_at       timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index tasks_workspace_created_idx on tasks (workspace_id, created_at desc);
create index tasks_project_idx on tasks (project_id);

create table task_comments (
  id          uuid primary key default gen_random_uuid(),
  task_id     uuid not null references tasks (id) on delete cascade,
  author_uid  text references users (uid) on delete set null,
  body        text not null,
  attachment  text,
  code        text,
  created_at  timestamptz not null default now()
);

create table task_subtasks (
  id      uuid primary key default gen_random_uuid(),
  task_id uuid not null references tasks (id) on delete cascade,
  title   text not null,
  is_done boolean not null default false
);

create table task_dependencies (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid not null references tasks (id) on delete cascade,
  blocked_by uuid references tasks (id) on delete cascade,
  state      dependency_state not null default 'blocked',
  reason     text
);

create table pull_requests (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  project_id   uuid references projects (id) on delete cascade,
  task_id      uuid references tasks (id) on delete set null,
  number       integer not null,
  title        text not null,
  author       text,
  branch       text not null default '',
  base_branch  text not null default 'main',
  state        text not null default 'open',
  checks       jsonb not null default '[]'::jsonb,
  files        jsonb not null default '[]'::jsonb,
  additions    integer not null default 0,
  deletions    integer not null default 0,
  reviewer_uid text references users (uid) on delete set null,
  last_commit  text,
  created_at   timestamptz not null default now(),
  unique (workspace_id, number)
);

create table sprint_items (
  sprint_id uuid not null references sprints (id) on delete cascade,
  task_id   uuid not null references tasks (id) on delete cascade,
  points    integer not null default 0,
  primary key (sprint_id, task_id)
);

create table notifications (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  user_uid     text not null references users (uid) on delete cascade,
  kind         text not null default 'review',
  title        text not null,
  body         text not null,
  action_label text,
  project_id   uuid references projects (id) on delete cascade,
  invite_id    uuid references workspace_invites (id) on delete cascade,
  is_read      boolean not null default false,
  created_at   timestamptz not null default now()
);

-- One notification per (user, invite): makes the sync idempotent.
create unique index notifications_invite_unique_idx
  on notifications (user_uid, invite_id)
  where invite_id is not null;

create index notifications_user_idx on notifications (user_uid, created_at desc);

create table activity_events (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  project_id   uuid references projects (id) on delete cascade,
  type         text not null,
  text         text not null,
  actor_uid    text references users (uid) on delete set null,
  created_at   timestamptz not null default now()
);

create index activity_workspace_idx on activity_events (workspace_id, created_at desc);

create table client_reports (
  id                uuid primary key default gen_random_uuid(),
  workspace_id      uuid not null references workspaces (id) on delete cascade,
  client_name       text not null,
  project_name      text not null,
  period            text,
  progress          numeric(4,3) not null default 0,
  next_milestone    text,
  milestone_date    date,
  decision_question text,
  decision_options  text[] not null default '{}',
  weekly_highlights text[] not null default '{}',
  invoice_lines     jsonb not null default '[]'::jsonb,
  total_hours       text,
  hourly_rate       text,
  invoice_number    text,
  delivered_items   text[] not null default '{}',
  decision_choice   text,
  decided_by        text references users (uid) on delete set null,
  decided_at        timestamptz
);

-- One client report per workspace (the snapshot assumes exactly one).
create unique index client_reports_one_per_workspace_idx
  on client_reports (workspace_id);

create table time_entries (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  user_uid     text not null references users (uid) on delete cascade,
  kind         text not null,
  span         text not null,
  branch       text,
  client_name  text,
  created_at   timestamptz not null default now()
);

create table digest_entries (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  user_uid     text not null references users (uid) on delete cascade,
  section      text not null default 'today',
  text         text not null,
  meta         text,
  action_label text,
  tone         text,
  created_at   timestamptz not null default now()
);

create table github_installations (
  id               uuid primary key default gen_random_uuid(),
  workspace_id     uuid not null references workspaces (id) on delete cascade,
  installation_id  bigint not null,
  account_login    text not null,
  account_type     text not null default 'User',
  created_by       text references users (uid) on delete set null,
  created_at       timestamptz not null default now(),
  unique (workspace_id, installation_id)
);

create unique index github_installations_one_per_workspace_idx
  on github_installations (workspace_id);

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
create or replace function touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger users_touch      before update on users      for each row execute function touch_updated_at();
create trigger workspaces_touch before update on workspaces for each row execute function touch_updated_at();
create trigger projects_touch   before update on projects   for each row execute function touch_updated_at();
create trigger tasks_touch      before update on tasks      for each row execute function touch_updated_at();

-- ---------------------------------------------------------------------------
-- The one payload every screen reads.
--
-- Same JSON shape as the Supabase `get_workspace_snapshot(uuid)`, so the
-- Flutter `WorkspaceSnapshotMapper` did not change. The caller is a parameter
-- now (there is no `auth.uid()`), and membership is checked here as a second
-- line of defence after the Go middleware.
-- ---------------------------------------------------------------------------
create or replace function get_workspace_snapshot(target uuid, caller text)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'workspace_id', w.id,
    'name',         w.name,

    'members', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.user_uid,
        'name', coalesce(nullif(u.display_name, ''), u.email),
        'role', m.role,
        'email', u.email,
        'avatar_url', u.photo_url,
        'open_tasks', (select count(*) from tasks t
                       where t.assignee_uid = m.user_uid and t.status <> 'done'),
        'is_online', false
      ))
      from workspace_members m
      join users u on u.uid = m.user_uid
      where m.workspace_id = w.id
    ), '[]'::jsonb),

    'invites', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id, 'email', i.email, 'role', i.role,
        'status', i.status, 'sent_at', i.sent_at,
        'invited_by', (select coalesce(nullif(u.display_name,''), u.email)
                       from users u where u.uid = i.invited_by)
      ))
      from workspace_invites i
      where i.workspace_id = w.id
    ), '[]'::jsonb),

    'tasks', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id, 'key', t.key, 'title', t.title,
        'description', t.description, 'status', t.status,
        'priority', t.priority, 'points', t.points,
        'project_id', t.project_id, 'project_name', p.name,
        'assignee_id', t.assignee_uid,
        'assignee_name', (select coalesce(nullif(u.display_name,''), u.email)
                          from users u where u.uid = t.assignee_uid),
        'label', t.label, 'branch', t.branch, 'pr_number', t.pr_number,
        'due_at', t.due_at, 'created_at', t.created_at
      ) order by t.created_at desc)
      from tasks t
      left join projects p on p.id = t.project_id
      where t.workspace_id = w.id
    ), '[]'::jsonb),

    'comments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id, 'task_id', c.task_id,
        'author', coalesce(nullif(u.display_name,''), u.email),
        'body', c.body, 'attachment', c.attachment, 'code', c.code,
        'created_at', c.created_at
      ))
      from task_comments c
      join tasks t on t.id = c.task_id
      left join users u on u.uid = c.author_uid
      where t.workspace_id = w.id
    ), '[]'::jsonb),

    'subtasks', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'task_id', s.task_id,
        'title', s.title, 'is_done', s.is_done
      ))
      from task_subtasks s
      join tasks t on t.id = s.task_id
      where t.workspace_id = w.id
    ), '[]'::jsonb),

    'dependencies', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id, 'task_id', d.task_id, 'task_key', t.key,
        'title', t.title, 'state', d.state, 'reason', d.reason,
        'assignee_name', (select coalesce(nullif(u.display_name,''), u.email)
                          from users u where u.uid = t.assignee_uid)
      ))
      from task_dependencies d
      join tasks t on t.id = d.task_id
      where t.workspace_id = w.id
    ), '[]'::jsonb),

    'activity', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'type', a.type, 'text', a.text,
        'actor', (select coalesce(nullif(u.display_name,''), u.email)
                  from users u where u.uid = a.actor_uid),
        'at', a.created_at
      ) order by a.created_at desc)
      from (
        select * from activity_events
        where workspace_id = w.id
        order by created_at desc
        limit 200
      ) a
    ), '[]'::jsonb),

    'sprints', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'name', s.name, 'goal', s.goal,
        'start', s.starts_at, 'end', s.ends_at,
        'capacity', s.capacity, 'committed', s.committed,
        'items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'task_id', t.id, 'key', t.key, 'title', t.title,
            'points', si.points, 'assignee_id', t.assignee_uid
          ))
          from sprint_items si
          join tasks t on t.id = si.task_id
          where si.sprint_id = s.id
        ), '[]'::jsonb)
      ))
      from sprints s
      where s.workspace_id = w.id
    ), '[]'::jsonb),

    'pull_requests', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', pr.id, 'number', pr.number, 'title', pr.title,
        'author', pr.author, 'branch', pr.branch, 'base_branch', pr.base_branch,
        'state', pr.state, 'issue_key', (select t.key from tasks t where t.id = pr.task_id),
        'project_name', (select p.name from projects p where p.id = pr.project_id),
        'checks', pr.checks, 'files', pr.files,
        'additions', pr.additions, 'deletions', pr.deletions,
        'reviewer_name', (select coalesce(nullif(u.display_name,''), u.email)
                          from users u where u.uid = pr.reviewer_uid),
        'last_commit', pr.last_commit,
        'last_commit_author', (select coalesce(nullif(u.display_name,''), u.email)
                               from users u
                               where u.uid = (select t.assignee_uid from tasks t where t.id = pr.task_id)),
        'waiting_hours', 0
      ))
      from pull_requests pr
      where pr.workspace_id = w.id
    ), '[]'::jsonb),

    'labels', coalesce((
      select jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name, 'color', l.color))
      from project_labels l
      join projects p on p.id = l.project_id
      where p.workspace_id = w.id
    ), '[]'::jsonb),

    'integrations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id, 'name', i.name, 'kind', i.kind,
        'connected', i.connected, 'workspace', i.workspace,
        'channels', i.channels, 'events', i.events
      ))
      from integrations i
      where i.workspace_id = w.id
    ), '[]'::jsonb),

    'repositories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'full_name', r.full_name, 'branch', r.branch,
        'description', r.description, 'language', r.language,
        'last_synced_at', r.last_synced_at
      ))
      from repositories r
      join projects p on p.id = r.project_id
      where p.workspace_id = w.id
    ), '[]'::jsonb),

    'notifications', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', n.id, 'kind', n.kind, 'title', n.title, 'body', n.body,
        'action_label', n.action_label, 'project_id', n.project_id,
        'invite_id', n.invite_id,
        'unread', not n.is_read, 'at', n.created_at
      ) order by n.created_at desc)
      from notifications n
      where n.user_uid = caller and n.workspace_id = w.id
    ), '[]'::jsonb),

    'digest', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id, 'section', d.section, 'text', d.text,
        'meta', d.meta, 'action_label', d.action_label, 'tone', d.tone
      ))
      from digest_entries d
      where d.workspace_id = w.id and d.user_uid = caller
    ), '[]'::jsonb),

    'client_report', (
      select jsonb_build_object(
        'client_name', c.client_name, 'project_name', c.project_name,
        'period', c.period, 'progress', c.progress,
        'next_milestone', c.next_milestone, 'milestone_date', c.milestone_date,
        'decision_question', c.decision_question,
        'decision_options', c.decision_options,
        'weekly_highlights', c.weekly_highlights,
        'invoice_lines', c.invoice_lines, 'total_hours', c.total_hours,
        'hourly_rate', c.hourly_rate, 'invoice_number', c.invoice_number,
        'delivered_items', c.delivered_items,
        'decision_choice', c.decision_choice,
        'time_entries', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', te.id, 'kind', te.kind, 'span', te.span,
            'branch', te.branch, 'client_name', te.client_name
          ))
          from time_entries te
          where te.user_uid = caller and te.workspace_id = c.workspace_id
        ), '[]'::jsonb),
        'week_by_client', coalesce((
          select jsonb_agg(jsonb_build_object('client', te.client_name, 'hours', te.span))
          from time_entries te
          where te.user_uid = caller
            and te.workspace_id = c.workspace_id
            and te.created_at > now() - interval '7 days'
        ), '[]'::jsonb)
      )
      from client_reports c
      where c.workspace_id = w.id
      limit 1
    )
  )
  from workspaces w
  where w.id = target
    and exists (
      select 1 from workspace_members m
      where m.workspace_id = w.id and m.user_uid = caller
    );
$$;
