-- 0003: groups (teams) inside a workspace — docs/design/groups-and-roles.md.
--
--   workspace ─┬─ group (software | hardware) ─┬─ group_members (group_role + functional_role)
--              │                               └─ project ── project_members (override)
--              └─ plan (free: 10 groups, pro: 50 groups, members unlimited)
--
-- Every existing workspace gets one default software group holding its
-- members and projects, so nothing that works today changes.

-- --- plans -------------------------------------------------------------------

create table plans (
  id                  text primary key,
  name                text not null,
  max_groups          integer not null,
  price_cents_monthly integer not null default 0
);

insert into plans (id, name, max_groups, price_cents_monthly) values
  ('free', 'العادية', 10, 0),
  ('pro',  'المدفوعة', 50, 6000);

-- SQLite cannot add a REFERENCES column with a non-NULL default while foreign
-- keys are on, so the plan id is checked by the API (and by this CHECK).
alter table workspaces add column plan_id text not null default 'free'
  check (plan_id in ('free', 'pro'));

-- --- groups ------------------------------------------------------------------

create table groups (
  id           text primary key,
  workspace_id text not null references workspaces (id) on delete cascade,
  name         text not null check (length(name) between 1 and 80),
  description  text check (description is null or length(description) <= 2000),
  type         text not null check (type in ('software', 'hardware')),
  template     text not null default 'scrum',
  settings     text not null default '{}',
  is_default   integer not null default 0,
  is_archived  integer not null default 0,
  created_by   text references users (uid) on delete set null,
  created_at   text not null,
  updated_at   text not null
);
create index groups_workspace_idx on groups (workspace_id, is_archived);
-- At most one default group per workspace (the one legacy endpoints use).
create unique index groups_one_default_idx on groups (workspace_id) where is_default = 1;

create table group_members (
  group_id        text not null references groups (id) on delete cascade,
  user_uid        text not null references users (uid) on delete cascade,
  group_role      text not null check (group_role in ('lead', 'admin', 'member', 'guest')),
  functional_role text not null,
  created_at      text not null,
  primary key (group_id, user_uid)
);
-- Exactly one lead per group, guaranteed by the database.
create unique index group_members_single_lead_idx
  on group_members (group_id) where group_role = 'lead';
create index group_members_user_idx on group_members (user_uid);

-- --- projects ----------------------------------------------------------------

alter table projects add column group_id text references groups (id) on delete cascade;
alter table projects add column visibility text not null default 'group'
  check (visibility in ('group', 'private'));
create index projects_group_idx on projects (group_id);

create table project_members (
  project_id      text not null references projects (id) on delete cascade,
  user_uid        text not null references users (uid) on delete cascade,
  functional_role text,
  access          text not null check (access in ('edit', 'read')),
  created_at      text not null,
  primary key (project_id, user_uid)
);

-- --- invites -----------------------------------------------------------------

alter table workspace_invites add column group_id text references groups (id) on delete cascade;
alter table workspace_invites add column group_role text;
alter table workspace_invites add column functional_role text;

-- --- backfill ----------------------------------------------------------------

insert into groups (id, workspace_id, name, type, template, is_default, created_by, created_at, updated_at)
select 'grp-' || w.id, w.id, w.name, 'software', 'scrum', 1, w.owner_uid, w.created_at, w.updated_at
from workspaces w;

insert into group_members (group_id, user_uid, group_role, functional_role, created_at)
select 'grp-' || m.workspace_id, m.user_uid,
       case m.role
         when 'owner'  then 'lead'
         when 'admin'  then 'admin'
         when 'viewer' then 'guest'
         else 'member'
       end,
       case m.role
         when 'owner'    then 'tech_lead'
         when 'admin'    then 'tech_lead'
         when 'reviewer' then 'reviewer'
         when 'viewer'   then 'client'
         else 'developer'
       end,
       m.created_at
from workspace_members m;

update projects set group_id = 'grp-' || workspace_id where group_id is null;

update workspace_invites
   set group_id = 'grp-' || workspace_id,
       group_role = case role when 'admin' then 'admin' when 'viewer' then 'guest' else 'member' end,
       functional_role = case role
         when 'admin' then 'tech_lead' when 'reviewer' then 'reviewer'
         when 'viewer' then 'client' else 'developer' end
 where status = 'pending' and group_id is null;
