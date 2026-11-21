-- 0005: hardware MVP — docs/design/groups-and-roles.md §7.
--
--   group (hardware) ── phase_templates (editable)
--        └─ project ─┬─ hw_phases (copied from the template) ── hw_gate_decisions
--                    ├─ hw_parts ── hw_bom_revs ── hw_bom_lines
--                    ├─ hw_ecos ─┬─ hw_eco_items
--                    │           └─ hw_eco_approvals
--                    ├─ hw_builds ── hw_units ── hw_test_results
--                    ├─ hw_test_plans
--                    └─ hw_fw_compat (firmware tag ↔ BOM revision)
--
-- Every row hangs off a project; the API reaches a project through its group
-- (projectAccess), so the workspace / group / private checks apply to all of
-- it. Money is integer cents.

-- --- phase templates (group level) -------------------------------------------

create table phase_templates (
  id         text primary key,
  group_id   text not null references groups (id) on delete cascade,
  name       text not null check (length(name) between 1 and 40),
  ord        integer not null default 0,
  -- json array of strings: the default deliverables / exit criteria.
  checklist  text not null default '[]',
  archived   integer not null default 0,
  created_at text not null default ''
);
create index phase_templates_group_idx on phase_templates (group_id, archived, ord);

-- The default template (§7.1). Editable afterwards.
create trigger groups_seed_phases after insert on groups when new.type = 'hardware'
begin
  insert into phase_templates (id, group_id, name, ord, checklist, created_at) values
    (new.id || ':proto', new.id, 'Proto', 0, '["الوظيفة الأساسية شغالة"]', new.created_at),
    (new.id || ':evt',   new.id, 'EVT',   1, '["التحقق الهندسي","تصميم واحد على بُعد 3 iterations أو أقل من الإنتاج"]', new.created_at),
    (new.id || ':dvt',   new.id, 'DVT',   2, '["كل المتطلبات (وظيفة، أداء، اعتمادية)","Pre-compliance (FCC / CE)"]', new.created_at),
    (new.id || ':pvt',   new.id, 'PVT',   3, '["Yield بسرعة الإنتاج على خط واحد","الشهادات"]', new.created_at),
    (new.id || ':mp',    new.id, 'MP',    4, '["Ramp الإنتاج"]', new.created_at);
end;

insert into phase_templates (id, group_id, name, ord, checklist, created_at)
select g.id || ':proto', g.id, 'Proto', 0, '["الوظيفة الأساسية شغالة"]', g.created_at from groups g where g.type = 'hardware'
union all
select g.id || ':evt', g.id, 'EVT', 1, '["التحقق الهندسي","تصميم واحد على بُعد 3 iterations أو أقل من الإنتاج"]', g.created_at from groups g where g.type = 'hardware'
union all
select g.id || ':dvt', g.id, 'DVT', 2, '["كل المتطلبات (وظيفة، أداء، اعتمادية)","Pre-compliance (FCC / CE)"]', g.created_at from groups g where g.type = 'hardware'
union all
select g.id || ':pvt', g.id, 'PVT', 3, '["Yield بسرعة الإنتاج على خط واحد","الشهادات"]', g.created_at from groups g where g.type = 'hardware'
union all
select g.id || ':mp', g.id, 'MP', 4, '["Ramp الإنتاج"]', g.created_at from groups g where g.type = 'hardware';

-- --- project phases and gates ------------------------------------------------

create table hw_phases (
  id           text primary key,
  project_id   text not null references projects (id) on delete cascade,
  template_id  text references phase_templates (id) on delete set null,
  name         text not null,
  ord          integer not null,
  status       text not null default 'not_started'
               check (status in ('not_started', 'in_progress', 'ready_for_review',
                                 'on_hold', 'passed', 'killed')),
  -- json array of {"text": "...", "done": false}: the project's own copy.
  checklist    text not null default '[]',
  started_at   text,
  gate_due_at  text,
  created_at   text not null default ''
);
create index hw_phases_project_idx on hw_phases (project_id, ord);

-- Every gate decision is kept: a phase can be recycled several times
-- (EVT1, EVT2…) before it passes.
create table hw_gate_decisions (
  id         text primary key,
  phase_id   text not null references hw_phases (id) on delete cascade,
  decision   text not null check (decision in ('go', 'recycle', 'hold', 'kill')),
  note       text check (note is null or length(note) <= 2000),
  decided_by text references users (uid) on delete set null,
  decided_at text not null
);
create index hw_gate_decisions_phase_idx on hw_gate_decisions (phase_id, decided_at);

-- A new project in a hardware group copies the group's live template. The
-- first phase starts right away.
create trigger projects_seed_phases after insert on projects
when exists (select 1 from groups g where g.id = new.group_id and g.type = 'hardware')
begin
  insert into hw_phases (id, project_id, template_id, name, ord, status, checklist, started_at, created_at)
  select new.id || ':' || t.id, new.id, t.id, t.name, t.ord,
         case when t.ord = (select min(x.ord) from phase_templates x
                             where x.group_id = new.group_id and x.archived = 0)
              then 'in_progress' else 'not_started' end,
         (select coalesce(json_group_array(json_object('text', j.value, 'done', json('false'))), '[]')
            from json_each(t.checklist) j),
         case when t.ord = (select min(x.ord) from phase_templates x
                             where x.group_id = new.group_id and x.archived = 0)
              then new.created_at end,
         new.created_at
  from phase_templates t
  where t.group_id = new.group_id and t.archived = 0;
end;

-- Projects that already sit in a hardware group.
insert into hw_phases (id, project_id, template_id, name, ord, status, checklist, started_at, created_at)
select p.id || ':' || t.id, p.id, t.id, t.name, t.ord,
       case when t.ord = 0 then 'in_progress' else 'not_started' end,
       (select coalesce(json_group_array(json_object('text', j.value, 'done', json('false'))), '[]')
          from json_each(t.checklist) j),
       case when t.ord = 0 then p.created_at end,
       p.created_at
from projects p
join groups g on g.id = p.group_id and g.type = 'hardware'
join phase_templates t on t.group_id = g.id and t.archived = 0;

-- --- parts and BOM -----------------------------------------------------------

create table hw_parts (
  id              text primary key,
  project_id      text not null references projects (id) on delete cascade,
  part_number     text not null check (length(part_number) between 1 and 64),
  revision        text not null default 'A' check (length(revision) between 1 and 8),
  description     text not null check (length(description) between 1 and 200),
  category        text check (category is null or length(category) <= 40),
  lifecycle       text not null default 'draft'
                  check (lifecycle in ('draft', 'prototype', 'production', 'obsolete')),
  mpn             text check (mpn is null or length(mpn) <= 80),
  vendor          text check (vendor is null or length(vendor) <= 80),
  unit_cost_cents integer check (unit_cost_cents is null or unit_cost_cents >= 0),
  created_at      text not null,
  updated_at      text not null,
  unique (project_id, part_number, revision)
);

create table hw_bom_revs (
  id          text primary key,
  project_id  text not null references projects (id) on delete cascade,
  rev         text not null,
  status      text not null default 'draft' check (status in ('draft', 'released')),
  note        text check (note is null or length(note) <= 2000),
  eco_id      text,                                  -- the ECO that produced it
  created_by  text references users (uid) on delete set null,
  released_by text references users (uid) on delete set null,
  released_at text,
  created_at  text not null,
  unique (project_id, rev)
);
-- One draft at a time per project: releases stay a straight line.
create unique index hw_bom_one_draft_idx on hw_bom_revs (project_id) where status = 'draft';

create table hw_bom_lines (
  bom_rev_id      text not null references hw_bom_revs (id) on delete cascade,
  part_id         text not null references hw_parts (id) on delete restrict,
  quantity        integer not null check (quantity between 1 and 100000),
  ref_designators text check (ref_designators is null or length(ref_designators) <= 500),
  primary key (bom_rev_id, part_id)
);

-- A released revision is a fixed snapshot.
create trigger hw_bom_lines_frozen_insert before insert on hw_bom_lines
when (select status from hw_bom_revs where id = new.bom_rev_id) = 'released'
begin select raise(abort, 'bom_revision_released'); end;
create trigger hw_bom_lines_frozen_update before update on hw_bom_lines
when (select status from hw_bom_revs where id = old.bom_rev_id) = 'released'
begin select raise(abort, 'bom_revision_released'); end;
create trigger hw_bom_lines_frozen_delete before delete on hw_bom_lines
when (select status from hw_bom_revs where id = old.bom_rev_id) = 'released'
  and exists (select 1 from hw_bom_revs where id = old.bom_rev_id)
begin select raise(abort, 'bom_revision_released'); end;

-- --- ECO / ECR ---------------------------------------------------------------

create table hw_ecos (
  id           text primary key,
  project_id   text not null references projects (id) on delete cascade,
  number       integer not null,
  kind         text not null default 'eco' check (kind in ('eco', 'ecr')),
  title        text not null check (length(title) between 1 and 200),
  reason       text check (reason is null or length(reason) <= 5000),
  impact       text check (impact is null or length(impact) <= 5000),
  status       text not null default 'draft'
               check (status in ('draft', 'design_review', 'production_review', 'approved',
                                 'released', 'rejected', 'cancelled')),
  created_by   text references users (uid) on delete set null,
  submitted_by text references users (uid) on delete set null,
  submitted_at text,
  bom_rev_id   text references hw_bom_revs (id) on delete set null,  -- released result
  created_at   text not null,
  updated_at   text not null,
  unique (project_id, number)
);

create table hw_eco_items (
  id           text primary key,
  eco_id       text not null references hw_ecos (id) on delete cascade,
  action       text not null check (action in ('add', 'change', 'remove')),
  from_part_id text references hw_parts (id) on delete restrict,   -- change / remove
  to_part_id   text references hw_parts (id) on delete restrict,   -- add / change
  quantity     integer check (quantity is null or quantity between 1 and 100000),
  ref_designators text check (ref_designators is null or length(ref_designators) <= 500),
  check ((action = 'add'    and to_part_id is not null and from_part_id is null)
      or (action = 'change' and to_part_id is not null and from_part_id is not null)
      or (action = 'remove' and from_part_id is not null and to_part_id is null))
);

create table hw_eco_approvals (
  id         text primary key,
  eco_id     text not null references hw_ecos (id) on delete cascade,
  stage      text not null check (stage in ('design', 'production')),
  user_uid   text references users (uid) on delete set null,
  decision   text not null check (decision in ('approve', 'reject')),
  comment    text check (comment is null or length(comment) <= 2000),
  at         text not null
);
create index hw_eco_approvals_eco_idx on hw_eco_approvals (eco_id, at);

-- --- builds, units, tests ----------------------------------------------------

create table hw_builds (
  id         text primary key,
  project_id text not null references projects (id) on delete cascade,
  phase_id   text references hw_phases (id) on delete set null,
  name       text not null check (length(name) between 1 and 40),     -- EVT1, DVT2…
  bom_rev_id text not null references hw_bom_revs (id) on delete restrict,
  quantity   integer not null check (quantity between 1 and 100000),
  cm         text check (cm is null or length(cm) <= 80),
  status     text not null default 'planned'
             check (status in ('planned', 'parts_ordered', 'assembling', 'received',
                               'testing', 'complete', 'cancelled')),
  planned_at text,
  created_by text references users (uid) on delete set null,
  created_at text not null,
  updated_at text not null,
  unique (project_id, name)
);

create table hw_units (
  id               text primary key,
  build_id         text not null references hw_builds (id) on delete cascade,
  serial           text not null check (length(serial) between 1 and 64),
  firmware_version text check (firmware_version is null or length(firmware_version) <= 64),
  location         text check (location is null or length(location) <= 80),
  status           text not null default 'untested'
                   check (status in ('untested', 'passed', 'failed', 'rework', 'scrapped')),
  created_at       text not null,
  updated_at       text not null,
  unique (build_id, serial)
);

create table hw_test_plans (
  id          text primary key,
  project_id  text not null references projects (id) on delete cascade,
  phase_id    text references hw_phases (id) on delete set null,
  title       text not null check (length(title) between 1 and 200),
  criteria    text check (criteria is null or length(criteria) <= 5000),
  approved_by text references users (uid) on delete set null,
  approved_at text,
  created_by  text references users (uid) on delete set null,
  created_at  text not null
);

create table hw_test_results (
  id               text primary key,
  plan_id          text not null references hw_test_plans (id) on delete cascade,
  unit_id          text not null references hw_units (id) on delete cascade,
  result           text not null check (result in ('pass', 'fail')),
  notes            text check (notes is null or length(notes) <= 2000),
  firmware_version text,             -- what the unit ran, copied at record time
  recorded_by      text references users (uid) on delete set null,
  recorded_at      text not null
);
create index hw_test_results_unit_idx on hw_test_results (unit_id, recorded_at);

-- --- firmware ↔ hardware -----------------------------------------------------

create table hw_fw_compat (
  project_id   text not null references projects (id) on delete cascade,
  firmware_tag text not null check (length(firmware_tag) between 1 and 64),
  bom_rev_id   text not null references hw_bom_revs (id) on delete cascade,
  note         text check (note is null or length(note) <= 500),
  verified_by  text references users (uid) on delete set null,
  verified_at  text not null,
  primary key (project_id, firmware_tag, bom_rev_id)
);
