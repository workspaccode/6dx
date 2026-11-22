-- 0007: links between projects of different groups (the exceptional case) —
-- docs/design/groups-and-roles.md §3.1.
--
-- A link is requested by the lead / an admin of one group and approved by
-- the lead / an admin of the other; both groups are in the same workspace
-- (checked by the API). A link gives a summary view only — never
-- membership — and either side can revoke it.

create table project_links (
  id           text primary key,
  from_project text not null references projects (id) on delete cascade,
  to_project   text not null references projects (id) on delete cascade,
  status       text not null default 'requested' check (status in ('requested', 'active', 'revoked')),
  note         text check (note is null or length(note) <= 500),
  requested_by text references users (uid) on delete set null,
  approved_by  text references users (uid) on delete set null,
  revoked_by   text references users (uid) on delete set null,
  created_at   text not null,
  updated_at   text not null,
  check (from_project <> to_project)
);
-- One live link per pair, whichever side asked.
create unique index project_links_pair_idx on project_links (
  min(from_project, to_project), max(from_project, to_project)
) where status <> 'revoked';
create index project_links_to_idx on project_links (to_project, status);
create index project_links_from_idx on project_links (from_project, status);

-- A task depends on a task of the linked project. Each side sees only the
-- other task's title and status.
create table link_task_deps (
  id         text primary key,
  link_id    text not null references project_links (id) on delete cascade,
  task_id    text not null references tasks (id) on delete cascade,     -- the waiting task
  depends_on text not null references tasks (id) on delete cascade,     -- in the other project
  created_by text references users (uid) on delete set null,
  created_at text not null,
  unique (task_id, depends_on)
);
create index link_task_deps_link_idx on link_task_deps (link_id);
