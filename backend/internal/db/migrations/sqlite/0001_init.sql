-- 6DX backend — SQLite schema.
--
-- SQLite is the default engine: one file, no server, no container. The schema
-- is the same model as the Postgres one with these substitutions:
--
--   uuid          → TEXT   (generated in Go)
--   timestamptz   → TEXT   (RFC3339, generated in Go)
--   jsonb / text[] → TEXT  (JSON encoded)
--   enum types    → TEXT + CHECK
--   SECURITY DEFINER functions → Go handlers (internal/api)
--
-- The snapshot projection the Flutter app consumes is also built in Go
-- (internal/api/snapshot.go): SQLite has no plpgsql.

create table users (
  uid          text primary key,
  email        text,
  display_name text,
  photo_url    text,
  -- The numeric GitHub id, taken from the Firebase token's `github.com`
  -- identity. It is the only trusted link for the install-recovery path.
  github_id    integer,
  created_at   text not null,
  updated_at   text not null
);

create unique index users_email_idx on users (lower(email)) where email is not null;
create unique index users_github_id_idx on users (github_id) where github_id is not null;

create table workspaces (
  id          text primary key,
  name        text not null,
  slug        text not null unique,
  owner_uid   text not null references users (uid),
  settings    text not null default '{}',
  created_at  text not null,
  updated_at  text not null
);

create table workspace_members (
  workspace_id text not null references workspaces (id) on delete cascade,
  user_uid     text not null references users (uid) on delete cascade,
  role         text not null default 'developer'
               check (role in ('owner', 'admin', 'developer', 'reviewer', 'viewer')),
  created_at   text not null,
  primary key (workspace_id, user_uid)
);

-- One owner per workspace, guaranteed by the database rather than by the API.
create unique index workspace_members_single_owner_idx
  on workspace_members (workspace_id)
  where role = 'owner';

create table workspace_invites (
  id           text primary key,
  workspace_id text not null references workspaces (id) on delete cascade,
  email        text not null,
  role         text not null default 'developer'
               check (role in ('owner', 'admin', 'developer', 'reviewer', 'viewer')),
  status       text not null default 'pending'
               check (status in ('pending', 'accepted', 'expired', 'revoked')),
  invited_by   text references users (uid) on delete set null,
  sent_at      text not null,
  expires_at   text not null
);

create index workspace_invites_email_idx on workspace_invites (lower(email), status);
create unique index workspace_invites_pending_idx
  on workspace_invites (workspace_id, lower(email))
  where status = 'pending';

create table projects (
  id           text primary key,
  workspace_id text not null references workspaces (id) on delete cascade,
  name         text not null,
  description  text,
  icon         text,
  color        text,
  is_archived  integer not null default 0,
  created_by   text references users (uid) on delete set null,
  created_at   text not null,
  updated_at   text not null
);

create index projects_workspace_idx on projects (workspace_id, updated_at desc);

create table repositories (
  id             text primary key,
  project_id     text not null references projects (id) on delete cascade,
  provider       text not null default 'github',
  full_name      text not null,
  branch         text not null default 'main',
  description    text,
  language       text,
  last_synced_at text
);

create table project_labels (
  id         text primary key,
  project_id text not null references projects (id) on delete cascade,
  name       text not null,
  color      text not null default '#9AA3B2',
  unique (project_id, name)
);

create table integrations (
  id           text primary key,
  workspace_id text not null references workspaces (id) on delete cascade,
  kind         text not null check (kind in ('slack', 'discord', 'teams')),
  name         text not null,
  connected    integer not null default 0,
  workspace    text,
  channels     text not null default '[]',
  events       text not null default '[]',
  unique (workspace_id, kind)
);

create table sprints (
  id           text primary key,
  workspace_id text not null references workspaces (id) on delete cascade,
  project_id   text references projects (id) on delete cascade,
  name         text not null,
  goal         text,
  starts_at    text not null,
  ends_at      text not null,
  capacity     integer not null default 0,
  committed    integer not null default 0,
  created_at   text not null
);

create table tasks (
  id           text primary key,
  workspace_id text not null references workspaces (id) on delete cascade,
  project_id   text references projects (id) on delete cascade,
  sprint_id    text references sprints (id) on delete set null,
  key          text,
  title        text not null,
  description  text,
  status       text not null default 'todo'
               check (status in ('todo', 'in_progress', 'review', 'done')),
  priority     text not null default 'medium'
               check (priority in ('low', 'medium', 'high', 'urgent')),
  points       integer not null default 0,
  assignee_uid text references users (uid) on delete set null,
  label        text,
  branch       text,
  pr_number    integer,
  due_at       text,
  created_at   text not null,
  updated_at   text not null
);

create index tasks_workspace_created_idx on tasks (workspace_id, created_at desc);
create index tasks_project_idx on tasks (project_id);

create table task_comments (
  id         text primary key,
  task_id    text not null references tasks (id) on delete cascade,
  author_uid text references users (uid) on delete set null,
  body       text not null,
  attachment text,
  code       text,
  created_at text not null
);

create table task_subtasks (
  id      text primary key,
  task_id text not null references tasks (id) on delete cascade,
  title   text not null,
  is_done integer not null default 0
);

create table task_dependencies (
  id         text primary key,
  task_id    text not null references tasks (id) on delete cascade,
  blocked_by text references tasks (id) on delete cascade,
  state      text not null default 'blocked'
             check (state in ('blocked', 'blocking', 'review')),
  reason     text
);

create table pull_requests (
  id           text primary key,
  workspace_id text not null references workspaces (id) on delete cascade,
  project_id   text references projects (id) on delete cascade,
  task_id      text references tasks (id) on delete set null,
  number       integer not null,
  title        text not null,
  author       text,
  branch       text not null default '',
  base_branch  text not null default 'main',
  state        text not null default 'open',
  checks       text not null default '[]',
  files        text not null default '[]',
  additions    integer not null default 0,
  deletions    integer not null default 0,
  reviewer_uid text references users (uid) on delete set null,
  last_commit  text,
  created_at   text not null,
  unique (workspace_id, number)
);

create table sprint_items (
  sprint_id text not null references sprints (id) on delete cascade,
  task_id   text not null references tasks (id) on delete cascade,
  points    integer not null default 0,
  primary key (sprint_id, task_id)
);

create table notifications (
  id           text primary key,
  workspace_id text not null references workspaces (id) on delete cascade,
  user_uid     text not null references users (uid) on delete cascade,
  kind         text not null default 'review',
  title        text not null,
  body         text not null,
  action_label text,
  project_id   text references projects (id) on delete cascade,
  invite_id    text references workspace_invites (id) on delete cascade,
  is_read      integer not null default 0,
  created_at   text not null
);

-- One notification per (user, invite): makes the sync idempotent.
create unique index notifications_invite_unique_idx
  on notifications (user_uid, invite_id)
  where invite_id is not null;

create index notifications_user_idx on notifications (user_uid, created_at desc);

create table activity_events (
  id           text primary key,
  workspace_id text not null references workspaces (id) on delete cascade,
  project_id   text references projects (id) on delete cascade,
  type         text not null,
  text         text not null,
  actor_uid    text references users (uid) on delete set null,
  created_at   text not null
);

create index activity_workspace_idx on activity_events (workspace_id, created_at desc);

create table client_reports (
  id                text primary key,
  workspace_id      text not null references workspaces (id) on delete cascade,
  client_name       text not null,
  project_name      text not null,
  period            text,
  progress          real not null default 0,
  next_milestone    text,
  milestone_date    text,
  decision_question text,
  decision_options  text not null default '[]',
  weekly_highlights text not null default '[]',
  invoice_lines     text not null default '[]',
  total_hours       text,
  hourly_rate       text,
  invoice_number    text,
  delivered_items   text not null default '[]',
  decision_choice   text,
  decided_by        text references users (uid) on delete set null,
  decided_at        text
);

-- One client report per workspace (the snapshot assumes exactly one).
create unique index client_reports_one_per_workspace_idx
  on client_reports (workspace_id);

create table time_entries (
  id           text primary key,
  workspace_id text not null references workspaces (id) on delete cascade,
  user_uid     text not null references users (uid) on delete cascade,
  kind         text not null,
  span         text not null,
  branch       text,
  client_name  text,
  created_at   text not null
);

create table digest_entries (
  id           text primary key,
  workspace_id text not null references workspaces (id) on delete cascade,
  user_uid     text not null references users (uid) on delete cascade,
  section      text not null default 'today',
  text         text not null,
  meta         text,
  action_label text,
  tone         text,
  created_at   text not null
);

create table github_installations (
  id              text primary key,
  workspace_id    text not null references workspaces (id) on delete cascade,
  installation_id integer not null,
  account_login   text not null,
  account_type    text not null default 'User',
  created_by      text references users (uid) on delete set null,
  created_at      text not null,
  unique (workspace_id, installation_id)
);

create unique index github_installations_one_per_workspace_idx
  on github_installations (workspace_id);
