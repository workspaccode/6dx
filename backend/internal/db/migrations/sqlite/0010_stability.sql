-- 0010: stability fixes for the stable Software release (docs/roadmap.md, stage B).
--
-- 1. Pull requests are keyed by (workspace, repository, number): two
--    repositories' PR #5 no longer overwrite each other. SQLite cannot change
--    a table-level UNIQUE in place, so the table is rebuilt (nothing has a
--    foreign key into it). The repository is backfilled from the project.
-- 2. github_deliveries: every webhook delivery id once (GitHub retries and
--    redeliveries must not replay an old state).
-- 3. time_entries can be approved (who / when).
-- 4. Missing indexes on hot lookups.
-- 5. Timestamps: one fixed-width UTC format ("2006-01-02T15:04:05.000Z"),
--    so string order is time order. RFC3339Nano trimmed trailing zeros
--    (".1Z" sorted after ".12Z"). Date-only columns, lab booking slots (whole
--    seconds, compared as written) and the append-only stock movements are
--    left as they are.

create table pull_requests_new (
  id            text primary key,
  workspace_id  text not null references workspaces (id) on delete cascade,
  project_id    text references projects (id) on delete cascade,
  task_id       text references tasks (id) on delete set null,
  repository    text not null default '',
  number        integer not null,
  title         text not null,
  author        text,
  author_github_id integer,                 -- who opened it (no self-approval)
  branch        text not null default '',
  base_branch   text not null default 'main',
  state         text not null default 'open',
  checks        text not null default '[]',
  files         text not null default '[]',
  additions     integer not null default 0,
  deletions     integer not null default 0,
  reviewer_uid  text references users (uid) on delete set null,
  last_commit   text,
  gh_updated_at text,                       -- pull_request.updated_at from GitHub
  created_at    text not null,
  unique (workspace_id, repository, number)
);

insert into pull_requests_new
  (id, workspace_id, project_id, task_id, repository, number, title, author, branch, base_branch,
   state, checks, files, additions, deletions, reviewer_uid, last_commit, created_at)
select pr.id, pr.workspace_id, pr.project_id, pr.task_id,
       -- Only a project with exactly one repository says which one; otherwise
       -- '' and the first webhook for that number claims the row (github.go).
       case when (select count(*) from repositories r where r.project_id = pr.project_id) = 1
            then (select r.full_name from repositories r where r.project_id = pr.project_id)
            else '' end,
       pr.number, pr.title, pr.author, pr.branch, pr.base_branch, pr.state, pr.checks, pr.files,
       pr.additions, pr.deletions, pr.reviewer_uid, pr.last_commit, pr.created_at
from pull_requests pr;

drop table pull_requests;
alter table pull_requests_new rename to pull_requests;
create index pull_requests_project_idx on pull_requests (project_id);

create table github_deliveries (
  delivery_id text primary key,
  event       text not null,
  received_at text not null
);

alter table time_entries add column approved_at text;
alter table time_entries add column approved_by text references users (uid) on delete set null;

create index if not exists tasks_assignee_idx on tasks (assignee_uid);
create index if not exists task_comments_task_idx on task_comments (task_id);
create index if not exists task_subtasks_task_idx on task_subtasks (task_id);
create index if not exists task_dependencies_task_idx on task_dependencies (task_id);
create index if not exists activity_events_ws_created_idx on activity_events (workspace_id, created_at);

update users set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update users set updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at) where updated_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(updated_at) <> 24;
update workspaces set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update workspaces set updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at) where updated_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(updated_at) <> 24;
update workspace_members set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update workspace_invites set sent_at = strftime('%Y-%m-%dT%H:%M:%fZ', sent_at) where sent_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(sent_at) <> 24;
update workspace_invites set expires_at = strftime('%Y-%m-%dT%H:%M:%fZ', expires_at) where expires_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(expires_at) <> 24;
update projects set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update projects set updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at) where updated_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(updated_at) <> 24;
update repositories set last_synced_at = strftime('%Y-%m-%dT%H:%M:%fZ', last_synced_at) where last_synced_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(last_synced_at) <> 24;
update sprints set starts_at = strftime('%Y-%m-%dT%H:%M:%fZ', starts_at) where starts_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(starts_at) <> 24;
update sprints set ends_at = strftime('%Y-%m-%dT%H:%M:%fZ', ends_at) where ends_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(ends_at) <> 24;
update sprints set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update tasks set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update tasks set updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at) where updated_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(updated_at) <> 24;
update task_comments set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update notifications set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update activity_events set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update client_reports set decided_at = strftime('%Y-%m-%dT%H:%M:%fZ', decided_at) where decided_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(decided_at) <> 24;
update time_entries set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update digest_entries set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update github_installations set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update groups set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update groups set updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at) where updated_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(updated_at) <> 24;
update group_members set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update project_members set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update workflow_states set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update phase_templates set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update hw_phases set started_at = strftime('%Y-%m-%dT%H:%M:%fZ', started_at) where started_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(started_at) <> 24;
update hw_phases set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update hw_gate_decisions set decided_at = strftime('%Y-%m-%dT%H:%M:%fZ', decided_at) where decided_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(decided_at) <> 24;
update hw_parts set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update hw_parts set updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at) where updated_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(updated_at) <> 24;
update hw_bom_revs set released_at = strftime('%Y-%m-%dT%H:%M:%fZ', released_at) where released_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(released_at) <> 24;
update hw_bom_revs set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update hw_ecos set submitted_at = strftime('%Y-%m-%dT%H:%M:%fZ', submitted_at) where submitted_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(submitted_at) <> 24;
update hw_ecos set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update hw_ecos set updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at) where updated_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(updated_at) <> 24;
update hw_eco_approvals set at = strftime('%Y-%m-%dT%H:%M:%fZ', at) where at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(at) <> 24;
update hw_builds set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update hw_builds set updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at) where updated_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(updated_at) <> 24;
update hw_units set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update hw_units set updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at) where updated_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(updated_at) <> 24;
update hw_test_plans set approved_at = strftime('%Y-%m-%dT%H:%M:%fZ', approved_at) where approved_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(approved_at) <> 24;
update hw_test_plans set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update hw_test_results set recorded_at = strftime('%Y-%m-%dT%H:%M:%fZ', recorded_at) where recorded_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(recorded_at) <> 24;
update hw_fw_compat set verified_at = strftime('%Y-%m-%dT%H:%M:%fZ', verified_at) where verified_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(verified_at) <> 24;
update inv_settings set updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at) where updated_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(updated_at) <> 24;
update inv_vendors set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update inv_pos set ordered_at = strftime('%Y-%m-%dT%H:%M:%fZ', ordered_at) where ordered_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(ordered_at) <> 24;
update inv_pos set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update inv_pos set updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at) where updated_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(updated_at) <> 24;
update inv_reservations set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update inv_reservations set updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at) where updated_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(updated_at) <> 24;
update project_links set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update project_links set updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at) where updated_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(updated_at) <> 24;
update link_task_deps set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update hw_certs set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update hw_certs set updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at) where updated_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(updated_at) <> 24;
update lab_assets set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
update lab_bookings set created_at = strftime('%Y-%m-%dT%H:%M:%fZ', created_at) where created_at glob '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*' and length(created_at) <> 24;
