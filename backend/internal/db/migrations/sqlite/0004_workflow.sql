-- 0004: editable workflow states per group — docs/design/groups-and-roles.md.
--
-- A group owns its task states (name, colour, order, category). The legacy
-- screens still read tasks.status (todo / in_progress / review / done), so
-- every state carries the legacy status it shows as, and triggers keep
-- tasks.state_id and tasks.status in step whichever one a writer sets:
--
--   * new code sets state_id and status = that state's legacy_status;
--   * old code (the board, the GitHub webhook) sets status only, and the
--     trigger picks the group's first state for it.

create table workflow_states (
  id            text primary key,
  group_id      text not null references groups (id) on delete cascade,
  entity        text not null default 'task' check (entity in ('task', 'eco', 'build', 'po')),
  name          text not null check (length(name) between 1 and 40),
  category      text not null
                check (category in ('backlog', 'active', 'blocked', 'done', 'cancelled')),
  color         text not null default '#64748B'
                check (length(color) = 7 and substr(color, 1, 1) = '#'),
  legacy_status text not null default 'todo'
                check (legacy_status in ('todo', 'in_progress', 'review', 'done')),
  ord           integer not null default 0,
  is_locked     integer not null default 0,
  archived      integer not null default 0,
  created_at    text not null default ''
);
create index workflow_states_group_idx on workflow_states (group_id, entity, archived, ord);

alter table tasks add column state_id text references workflow_states (id) on delete set null;
create index tasks_state_idx on tasks (state_id);

-- --- default states ----------------------------------------------------------

-- Every group starts with the four states the app always had; a hardware
-- group also gets «متوقف» (waiting on parts or a test rig is the norm there).
create trigger groups_seed_workflow after insert on groups
begin
  insert into workflow_states (id, group_id, entity, name, category, color, legacy_status, ord, created_at)
  values
    (new.id || ':todo',        new.id, 'task', 'للتنفيذ', 'backlog', '#64748B', 'todo',        0, new.created_at),
    (new.id || ':in_progress', new.id, 'task', 'جاري',    'active',  '#2563EB', 'in_progress', 1, new.created_at),
    (new.id || ':review',      new.id, 'task', 'مراجعة',  'active',  '#D97706', 'review',      2, new.created_at),
    (new.id || ':done',        new.id, 'task', 'تم',      'done',    '#16A34A', 'done',        4, new.created_at);
  insert into workflow_states (id, group_id, entity, name, category, color, legacy_status, ord, created_at)
  select new.id || ':blocked', new.id, 'task', 'متوقف', 'blocked', '#DC2626', 'in_progress', 3, new.created_at
  where new.type = 'hardware';
end;

-- Groups that exist already (0003 made one per workspace).
insert into workflow_states (id, group_id, entity, name, category, color, legacy_status, ord, created_at)
select g.id || ':todo', g.id, 'task', 'للتنفيذ', 'backlog', '#64748B', 'todo', 0, g.created_at from groups g
union all
select g.id || ':in_progress', g.id, 'task', 'جاري', 'active', '#2563EB', 'in_progress', 1, g.created_at from groups g
union all
select g.id || ':review', g.id, 'task', 'مراجعة', 'active', '#D97706', 'review', 2, g.created_at from groups g
union all
select g.id || ':blocked', g.id, 'task', 'متوقف', 'blocked', '#DC2626', 'in_progress', 3, g.created_at
  from groups g where g.type = 'hardware'
union all
select g.id || ':done', g.id, 'task', 'تم', 'done', '#16A34A', 'done', 4, g.created_at from groups g;

-- --- keeping state_id and status in step -------------------------------------

-- The group of a task is its project's; a task without a project belongs to
-- the workspace's default group. The state picked is the first live one
-- showing that legacy status, else the first one of the matching category.
create trigger tasks_state_after_insert after insert on tasks
when new.state_id is null
  or not exists (select 1 from workflow_states s
                  where s.id = new.state_id and s.legacy_status = new.status)
begin
  update tasks set state_id = (
    select s.id from workflow_states s
    where s.entity = 'task' and s.archived = 0
      and s.group_id = coalesce(
            (select p.group_id from projects p where p.id = new.project_id),
            (select g.id from groups g where g.workspace_id = new.workspace_id and g.is_default = 1))
      and (s.legacy_status = new.status
           or s.category = case new.status when 'todo' then 'backlog'
                                           when 'done' then 'done' else 'active' end)
    order by (s.legacy_status = new.status) desc, s.ord
    limit 1)
  where id = new.id;
end;

create trigger tasks_state_after_status after update of status, project_id on tasks
when new.state_id is null
  or new.project_id is not old.project_id
  or not exists (select 1 from workflow_states s
                  where s.id = new.state_id and s.legacy_status = new.status)
begin
  update tasks set state_id = (
    select s.id from workflow_states s
    where s.entity = 'task' and s.archived = 0
      and s.group_id = coalesce(
            (select p.group_id from projects p where p.id = new.project_id),
            (select g.id from groups g where g.workspace_id = new.workspace_id and g.is_default = 1))
      and (s.legacy_status = new.status
           or s.category = case new.status when 'todo' then 'backlog'
                                           when 'done' then 'done' else 'active' end)
    order by (s.legacy_status = new.status) desc, s.ord
    limit 1)
  where id = new.id;
end;

-- Existing tasks: map their status onto their group's default states.
update tasks set state_id = coalesce(
  (select p.group_id from projects p where p.id = tasks.project_id),
  (select g.id from groups g where g.workspace_id = tasks.workspace_id and g.is_default = 1)
) || ':' || status;
