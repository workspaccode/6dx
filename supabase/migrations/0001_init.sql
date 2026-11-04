-- 6DX — Supabase schema
-- Mirrors the Flutter `WorkspaceSnapshot` projection exactly:
-- GET /workspaces/{id}/snapshot  ->  select get_workspace_snapshot('<workspace_id>');

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.member_role      as enum ('owner', 'admin', 'developer', 'reviewer', 'viewer');
create type public.invite_status    as enum ('pending', 'accepted', 'expired', 'revoked');
create type public.task_status      as enum ('todo', 'in_progress', 'review', 'done');
create type public.task_priority    as enum ('low', 'medium', 'high', 'urgent');
create type public.dependency_state as enum ('blocked', 'blocking', 'review');
create type public.integration_kind as enum ('slack', 'discord', 'teams');

-- ---------------------------------------------------------------------------
-- Workspaces & members
-- ---------------------------------------------------------------------------
create table public.workspaces (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slug        text unique not null,
  owner_id    uuid not null references auth.users (id) on delete cascade,
  settings    jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.workspace_members (
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  role         public.member_role not null default 'developer',
  created_at   timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

create table public.workspace_invites (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  email        text not null,
  role         public.member_role not null default 'developer',
  status       public.invite_status not null default 'pending',
  invited_by   uuid references auth.users (id) on delete set null,
  sent_at      timestamptz not null default now(),
  expires_at   timestamptz not null default (now() + interval '7 days')
);

-- ---------------------------------------------------------------------------
-- Projects
-- ---------------------------------------------------------------------------
create table public.projects (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  name         text not null,
  description  text,
  icon         text,
  color        text,
  is_archived  boolean not null default false,
  created_by   uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table public.repositories (
  id             uuid primary key default gen_random_uuid(),
  project_id     uuid not null references public.projects (id) on delete cascade,
  provider       text not null default 'github',
  full_name      text not null,
  branch         text not null default 'main',
  description    text,
  language       text,
  last_synced_at timestamptz
);

create table public.project_labels (
  id         uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  name       text not null,
  color      text not null default '#9AA3B2',
  unique (project_id, name)
);

create table public.integrations (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  kind         public.integration_kind not null,
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
create table public.sprints (
  id          uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  project_id  uuid references public.projects (id) on delete cascade,
  name        text not null,
  goal        text,
  starts_at   date not null,
  ends_at     date not null,
  capacity    integer not null default 0,
  committed   integer not null default 0,
  created_at  timestamptz not null default now()
);

create table public.tasks (
  id              uuid primary key default gen_random_uuid(),
  workspace_id    uuid not null references public.workspaces (id) on delete cascade,
  project_id      uuid references public.projects (id) on delete cascade,
  sprint_id       uuid references public.sprints (id) on delete set null,
  key             text,
  title           text not null,
  description     text,
  status          public.task_status not null default 'todo',
  priority        public.task_priority not null default 'medium',
  points          integer not null default 0,
  assignee_id     uuid references auth.users (id) on delete set null,
  label           text,
  branch          text,
  pr_number       integer,
  due_at          timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table public.task_comments (
  id          uuid primary key default gen_random_uuid(),
  task_id     uuid not null references public.tasks (id) on delete cascade,
  author_id   uuid references auth.users (id) on delete set null,
  body        text not null,
  attachment  text,
  code        text,
  created_at  timestamptz not null default now()
);

create table public.task_subtasks (
  id        uuid primary key default gen_random_uuid(),
  task_id   uuid not null references public.tasks (id) on delete cascade,
  title     text not null,
  is_done   boolean not null default false
);

create table public.task_dependencies (
  id          uuid primary key default gen_random_uuid(),
  task_id     uuid not null references public.tasks (id) on delete cascade,
  blocked_by  uuid references public.tasks (id) on delete cascade,
  state       public.dependency_state not null default 'blocked',
  reason      text
);

create table public.pull_requests (
  id            uuid primary key default gen_random_uuid(),
  workspace_id  uuid not null references public.workspaces (id) on delete cascade,
  project_id    uuid references public.projects (id) on delete cascade,
  task_id       uuid references public.tasks (id) on delete set null,
  number        integer not null,
  title         text not null,
  author        text,
  branch        text not null default '',
  base_branch   text not null default 'main',
  state         text not null default 'open',
  checks        jsonb not null default '[]'::jsonb,
  files         jsonb not null default '[]'::jsonb,
  additions     integer not null default 0,
  deletions     integer not null default 0,
  reviewer_id   uuid references auth.users (id) on delete set null,
  last_commit   text,
  created_at    timestamptz not null default now()
);

create table public.sprint_items (
  sprint_id uuid not null references public.sprints (id) on delete cascade,
  task_id   uuid not null references public.tasks (id) on delete cascade,
  points    integer not null default 0,
  primary key (sprint_id, task_id)
);

create table public.notifications (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  kind         text not null default 'review',
  title        text not null,
  body         text not null,
  action_label text,
  project_id   uuid references public.projects (id) on delete cascade,
  is_read      boolean not null default false,
  created_at   timestamptz not null default now()
);

create table public.activity_events (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  project_id   uuid references public.projects (id) on delete cascade,
  type         text not null,
  text         text not null,
  actor_id     uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now()
);

create table public.client_reports (
  id                uuid primary key default gen_random_uuid(),
  workspace_id      uuid not null references public.workspaces (id) on delete cascade,
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
  delivered_items   text[] not null default '{}'
);

create table public.time_entries (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  kind         text not null,
  span         text not null,
  branch       text,
  client_name  text,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------
alter table public.workspaces          enable row level security;
alter table public.workspace_members  enable row level security;
alter table public.workspace_invites  enable row level security;
alter table public.projects           enable row level security;
alter table public.repositories       enable row level security;
alter table public.project_labels    enable row level security;
alter table public.integrations       enable row level security;
alter table public.sprints            enable row level security;
alter table public.tasks              enable row level security;
alter table public.task_comments      enable row level security;
alter table public.task_subtasks      enable row level security;
alter table public.task_dependencies  enable row level security;
alter table public.pull_requests      enable row level security;
alter table public.sprint_items       enable row level security;
alter table public.notifications      enable row level security;
alter table public.activity_events    enable row level security;
alter table public.client_reports     enable row level security;
alter table public.time_entries       enable row level security;

create or replace function public.is_workspace_member(target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.workspace_members m
    where m.workspace_id = target and m.user_id = auth.uid()
  );
$$;

create or replace function public.is_workspace_admin(target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.workspace_members m
    where m.workspace_id = target
      and m.user_id = auth.uid()
      and m.role in ('owner', 'admin')
  );
$$;

create or replace function public.is_workspace_owner(target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.workspace_members m
    where m.workspace_id = target
      and m.user_id = auth.uid()
      and m.role = 'owner'
  );
$$;

create policy workspaces_read   on public.workspaces
  for select using (public.is_workspace_member(id));
-- Renaming the workspace / changing its settings is an admin action.
create policy workspaces_update on public.workspaces
  for update
  using (public.is_workspace_admin(id))
  with check (public.is_workspace_admin(id));
-- Only the owner may drop the workspace.
create policy workspaces_delete on public.workspaces
  for delete using (public.is_workspace_owner(id));

create policy members_read       on public.workspace_members
  for select using (public.is_workspace_member(workspace_id));

-- Role management is layered on purpose:
--   * an owner manages the admins/developers/reviewers/viewers, never `owner`,
--   * an admin manages developers/reviewers/viewers only,
--   * `owner` is never handed out through the API, so nobody can promote
--     themselves (a single-owner workspace).
create policy members_insert     on public.workspace_members
  for insert with check (
    public.is_workspace_admin(workspace_id)
    and role <> 'owner'
    and (role <> 'admin' or public.is_workspace_owner(workspace_id))
  );

create policy members_update     on public.workspace_members
  for update
  using (
    (public.is_workspace_owner(workspace_id) and role <> 'owner')
    or (public.is_workspace_admin(workspace_id)
        and role in ('developer', 'reviewer', 'viewer'))
  )
  with check (
    role <> 'owner'
    and (
      public.is_workspace_owner(workspace_id)
      or (public.is_workspace_admin(workspace_id)
          and role in ('developer', 'reviewer', 'viewer'))
    )
  );

create policy members_delete     on public.workspace_members
  for delete using (
    (public.is_workspace_owner(workspace_id) and role <> 'owner')
    or (public.is_workspace_admin(workspace_id)
        and role in ('developer', 'reviewer', 'viewer'))
  );

create policy invites_read       on public.workspace_invites
  for select using (public.is_workspace_member(workspace_id));
-- Inviting people is an admin action; the inviter is recorded and `owner`
-- cannot be handed out by an invite.
create policy invites_insert     on public.workspace_invites
  for insert with check (
    public.is_workspace_admin(workspace_id)
    and role <> 'owner'
    and invited_by = auth.uid()
  );
create policy invites_update     on public.workspace_invites
  for update
  using (public.is_workspace_admin(workspace_id))
  with check (public.is_workspace_admin(workspace_id) and role <> 'owner');
create policy invites_delete     on public.workspace_invites
  for delete using (public.is_workspace_admin(workspace_id));

create policy projects_write      on public.projects
  for all
  using (public.is_workspace_member(workspace_id))
  with check (public.is_workspace_member(workspace_id));

create policy repositories_write  on public.repositories
  for all
  using (exists (
    select 1 from public.projects p
    where p.id = repositories.project_id
      and public.is_workspace_member(p.workspace_id)))
  with check (exists (
    select 1 from public.projects p
    where p.id = repositories.project_id
      and public.is_workspace_member(p.workspace_id)));
create policy labels_write        on public.project_labels
  for all
  using (exists (
    select 1 from public.projects p
    where p.id = project_labels.project_id
      and public.is_workspace_member(p.workspace_id)))
  with check (exists (
    select 1 from public.projects p
    where p.id = project_labels.project_id
      and public.is_workspace_member(p.workspace_id)));
create policy integrations_write  on public.integrations
  for all
  using (public.is_workspace_member(workspace_id))
  with check (public.is_workspace_member(workspace_id));

create policy sprints_write       on public.sprints
  for all
  using (public.is_workspace_member(workspace_id))
  with check (public.is_workspace_member(workspace_id));
create policy tasks_write         on public.tasks
  for all
  using (public.is_workspace_member(workspace_id))
  with check (public.is_workspace_member(workspace_id));
create policy comments_write      on public.task_comments
  for all
  using (exists (
    select 1 from public.tasks t
    where t.id = task_comments.task_id
      and public.is_workspace_member(t.workspace_id)))
  with check (exists (
    select 1 from public.tasks t
    where t.id = task_comments.task_id
      and public.is_workspace_member(t.workspace_id)));
create policy subtasks_write      on public.task_subtasks
  for all
  using (exists (
    select 1 from public.tasks t
    where t.id = task_subtasks.task_id
      and public.is_workspace_member(t.workspace_id)))
  with check (exists (
    select 1 from public.tasks t
    where t.id = task_subtasks.task_id
      and public.is_workspace_member(t.workspace_id)));
create policy dependencies_write  on public.task_dependencies
  for all
  using (exists (
    select 1 from public.tasks t
    where t.id = task_dependencies.task_id
      and public.is_workspace_member(t.workspace_id)))
  with check (exists (
    select 1 from public.tasks t
    where t.id = task_dependencies.task_id
      and public.is_workspace_member(t.workspace_id)));
create policy prs_write           on public.pull_requests
  for all
  using (public.is_workspace_member(workspace_id))
  with check (public.is_workspace_member(workspace_id));
create policy sprint_items_write  on public.sprint_items
  for all
  using (exists (
    select 1 from public.sprints s
    where s.id = sprint_items.sprint_id
      and public.is_workspace_member(s.workspace_id)))
  with check (exists (
    select 1 from public.sprints s
    where s.id = sprint_items.sprint_id
      and public.is_workspace_member(s.workspace_id)));
create policy notifications_write on public.notifications
  for all
  using (user_id = auth.uid()
    and public.is_workspace_member(workspace_id))
  with check (user_id = auth.uid()
    and public.is_workspace_member(workspace_id));
create policy activity_read      on public.activity_events
  for select using (public.is_workspace_member(workspace_id));
-- The app records actions (invites, approvals, client decisions) as activity.
create policy activity_insert    on public.activity_events
  for insert with check (
    public.is_workspace_member(workspace_id)
    and (actor_id is null or actor_id = auth.uid())
  );
create policy client_reports_read on public.client_reports
  for select using (public.is_workspace_member(workspace_id));
create policy time_entries_read on public.time_entries
  for select using (user_id = auth.uid()
    and public.is_workspace_member(workspace_id));

-- ---------------------------------------------------------------------------
-- The daily digest (per user + per workspace). Created before the snapshot
-- function below, which reads it.
-- ---------------------------------------------------------------------------
create table if not exists public.digest_entries (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  user_id      uuid not null references auth.users (id) on delete cascade,
  section      text not null default 'today',
  text         text not null,
  meta         text,
  action_label text,
  tone         text,
  created_at   timestamptz not null default now()
);

alter table public.digest_entries enable row level security;
create policy digest_write on public.digest_entries
  for all
  using (user_id = auth.uid()
    and public.is_workspace_member(workspace_id))
  with check (user_id = auth.uid()
    and public.is_workspace_member(workspace_id));

-- ---------------------------------------------------------------------------
-- The snapshot projection consumed by the Flutter app
-- ---------------------------------------------------------------------------
create or replace function public.get_workspace_snapshot(target uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'workspace_id', w.id,
    'name',         w.name,

    'members', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', m.user_id,
        'name', coalesce(u.raw_user_meta_data->>'full_name',
                         u.raw_user_meta_data->>'name',
                         u.email),
        'role', m.role,
        'email', u.email,
        'avatar_url', u.raw_user_meta_data->>'avatar_url',
        'open_tasks', (select count(*) from public.tasks t
                       where t.assignee_id = m.user_id and t.status <> 'done'),
        'is_online', false
      ))
      from public.workspace_members m
      join auth.users u on u.id = m.user_id
      where m.workspace_id = w.id
    ), '[]'::jsonb),

    'invites', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id, 'email', i.email, 'role', i.role,
        'status', i.status, 'sent_at', i.sent_at,
        'invited_by', (select u.email from auth.users u where u.id = i.invited_by)
      ))
      from public.workspace_invites i
      where i.workspace_id = w.id
    ), '[]'::jsonb),

    'tasks', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id, 'key', t.key, 'title', t.title,
        'description', t.description, 'status', t.status,
        'priority', t.priority, 'points', t.points,
        'project_id', t.project_id, 'project_name', p.name,
        'assignee_name', (select u.email from auth.users u where u.id = t.assignee_id),
        'label', t.label, 'branch', t.branch, 'pr_number', t.pr_number,
        'due_at', t.due_at, 'created_at', t.created_at
      ))
      from public.tasks t
      left join public.projects p on p.id = t.project_id
      where t.workspace_id = w.id
    ), '[]'::jsonb),

    'comments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id, 'task_id', c.task_id,
        'author', coalesce(u.raw_user_meta_data->>'full_name', u.email),
        'body', c.body, 'attachment', c.attachment, 'code', c.code,
        'created_at', c.created_at
      ))
      from public.task_comments c
      join public.tasks t on t.id = c.task_id
      left join auth.users u on u.id = c.author_id
      where t.workspace_id = w.id
    ), '[]'::jsonb),

    'subtasks', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'task_id', s.task_id,
        'title', s.title, 'is_done', s.is_done
      ))
      from public.task_subtasks s
      join public.tasks t on t.id = s.task_id
      where t.workspace_id = w.id
    ), '[]'::jsonb),

    'dependencies', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id, 'task_id', d.task_id, 'task_key', t.key,
        'title', t.title, 'state', d.state, 'reason', d.reason,
        'assignee_name', (select u.email from auth.users u where u.id = t.assignee_id)
      ))
      from public.task_dependencies d
      join public.tasks t on t.id = d.task_id
      where t.workspace_id = w.id
    ), '[]'::jsonb),

    'activity', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'type', a.type, 'text', a.text,
        'actor', (select u.email from auth.users u where u.id = a.actor_id),
        'at', a.created_at
      ))
      from public.activity_events a
      where a.workspace_id = w.id
      order by a.created_at desc
      limit 200
    ), '[]'::jsonb),

    'sprints', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'name', s.name, 'goal', s.goal,
        'start', s.starts_at, 'end', s.ends_at,
        'capacity', s.capacity, 'committed', s.committed,
        'items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'task_id', t.id, 'key', t.key, 'title', t.title,
            'points', si.points, 'assignee_id', t.assignee_id
          ))
          from public.sprint_items si
          join public.tasks t on t.id = si.task_id
          where si.sprint_id = s.id
        ), '[]'::jsonb)
      ))
      from public.sprints s
      where s.workspace_id = w.id
    ), '[]'::jsonb),

    'pull_requests', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', pr.id, 'number', pr.number, 'title', pr.title,
        'author', pr.author, 'branch', pr.branch, 'base_branch', pr.base_branch,
        'state', pr.state, 'issue_key', (select t.key from public.tasks t where t.id = pr.task_id),
        'project_name', (select p.name from public.projects p where p.id = pr.project_id),
        'checks', pr.checks, 'files', pr.files,
        'additions', pr.additions, 'deletions', pr.deletions,
        'reviewer_name', (select u.email from auth.users u where u.id = pr.reviewer_id),
        'last_commit', pr.last_commit,
        'last_commit_author', (select u.email from auth.users u where u.id = (select t.assignee_id from public.tasks t where t.id = pr.task_id)),
        'waiting_hours', 0
      ))
      from public.pull_requests pr
      where pr.workspace_id = w.id
    ), '[]'::jsonb),

    'labels', coalesce((
      select jsonb_agg(jsonb_build_object('id', l.id, 'name', l.name, 'color', l.color))
      from public.project_labels l
      join public.projects p on p.id = l.project_id
      where p.workspace_id = w.id
    ), '[]'::jsonb),

    'integrations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id, 'name', i.name, 'kind', i.kind,
        'connected', i.connected, 'workspace', i.workspace,
        'channels', i.channels, 'events', i.events
      ))
      from public.integrations i
      where i.workspace_id = w.id
    ), '[]'::jsonb),

    'repositories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'full_name', r.full_name, 'branch', r.branch,
        'description', r.description, 'language', r.language,
        'last_synced_at', r.last_synced_at
      ))
      from public.repositories r
      join public.projects p on p.id = r.project_id
      where p.workspace_id = w.id
    ), '[]'::jsonb),

    'notifications', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', n.id, 'kind', n.kind, 'title', n.title, 'body', n.body,
        'action_label', n.action_label, 'project_id', n.project_id,
        'unread', not n.is_read, 'at', n.created_at
      ))
      from public.notifications n
      where n.user_id = auth.uid()
    ), '[]'::jsonb),

    'digest', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id, 'section', d.section, 'text', d.text,
        'meta', d.meta, 'action_label', d.action_label, 'tone', d.tone
      ))
      from public.digest_entries d
      where d.workspace_id = w.id and d.user_id = auth.uid()
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
        'time_entries', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', te.id, 'kind', te.kind, 'span', te.span,
            'branch', te.branch, 'client_name', te.client_name
          )) from public.time_entries te
          where te.user_id = auth.uid()
        ), '[]'::jsonb),
        'week_by_client', coalesce((
          select jsonb_agg(jsonb_build_object('client', te.client_name, 'hours', te.span))
          from public.time_entries te
          where te.user_id = auth.uid() and te.created_at > now() - interval '7 days'
        ), '[]'::jsonb)
      )
      from public.client_reports c
      where c.workspace_id = w.id
      limit 1
    )
  )
  from public.workspaces w
  where w.id = target and public.is_workspace_member(w.id);
$$;

-- ---------------------------------------------------------------------------
-- Privileges
--
-- Supabase does not hand the API roles access to a `public` table implicitly:
-- without these grants PostgREST answers `42501 permission denied`. Row level
-- security is the gate for *which rows* a role may touch; the grants only open
-- the door to the table. Functions (all SECURITY DEFINER) stay off-limits to
-- `anon`.
-- ---------------------------------------------------------------------------
grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete on all tables in schema public
  to anon, authenticated;
grant usage, select on all sequences in schema public
  to anon, authenticated;
grant execute on all functions in schema public to authenticated;

alter default privileges in schema public
  grant select, insert, update, delete on tables to anon, authenticated;
alter default privileges in schema public
  grant usage, select on sequences to anon, authenticated;
alter default privileges in schema public
  grant execute on functions to authenticated;
