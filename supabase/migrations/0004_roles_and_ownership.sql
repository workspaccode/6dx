-- ---------------------------------------------------------------------------
-- 0004 — role enforcement, activity attribution, ownership transfer
--
-- Fixes three gaps found while auditing 0001:
--   1. `viewer` was decorative: every member could write projects/tasks/… .
--   2. `activity_events` accepted rows without an actor (`actor_id is null`),
--      so activity could be written anonymously.
--   3. A workspace could never change hands: only the owner may delete it, and
--      no API path can create/grant `owner`.
-- ---------------------------------------------------------------------------

-- Members who may *write*; viewers are read-only.
create or replace function public.is_workspace_editor(target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.workspace_members m
    where m.workspace_id = target
      and m.user_id = (select auth.uid())
      and m.role <> 'viewer'
  );
$$;

revoke all on function public.is_workspace_editor(uuid) from anon, public;
grant execute on function public.is_workspace_editor(uuid) to authenticated;

-- --- write policies now require "editor" ----------------------------------

drop policy if exists projects_write on public.projects;
create policy projects_write on public.projects
  for all
  using (public.is_workspace_editor(workspace_id))
  with check (public.is_workspace_editor(workspace_id));

drop policy if exists repositories_write on public.repositories;
create policy repositories_write on public.repositories
  for all
  using (exists (
    select 1 from public.projects p
    where p.id = repositories.project_id
      and public.is_workspace_editor(p.workspace_id)))
  with check (exists (
    select 1 from public.projects p
    where p.id = repositories.project_id
      and public.is_workspace_editor(p.workspace_id)));

drop policy if exists labels_write on public.project_labels;
create policy labels_write on public.project_labels
  for all
  using (exists (
    select 1 from public.projects p
    where p.id = project_labels.project_id
      and public.is_workspace_editor(p.workspace_id)))
  with check (exists (
    select 1 from public.projects p
    where p.id = project_labels.project_id
      and public.is_workspace_editor(p.workspace_id)));

drop policy if exists integrations_write on public.integrations;
create policy integrations_write on public.integrations
  for all
  using (public.is_workspace_editor(workspace_id))
  with check (public.is_workspace_editor(workspace_id));

drop policy if exists sprints_write on public.sprints;
create policy sprints_write on public.sprints
  for all
  using (public.is_workspace_editor(workspace_id))
  with check (public.is_workspace_editor(workspace_id));

drop policy if exists tasks_write on public.tasks;
create policy tasks_write on public.tasks
  for all
  using (public.is_workspace_editor(workspace_id))
  with check (public.is_workspace_editor(workspace_id));

drop policy if exists comments_write on public.task_comments;
create policy comments_write on public.task_comments
  for all
  using (exists (
    select 1 from public.tasks t
    where t.id = task_comments.task_id
      and public.is_workspace_editor(t.workspace_id)))
  with check (exists (
    select 1 from public.tasks t
    where t.id = task_comments.task_id
      and public.is_workspace_editor(t.workspace_id)));

drop policy if exists subtasks_write on public.task_subtasks;
create policy subtasks_write on public.task_subtasks
  for all
  using (exists (
    select 1 from public.tasks t
    where t.id = task_subtasks.task_id
      and public.is_workspace_editor(t.workspace_id)))
  with check (exists (
    select 1 from public.tasks t
    where t.id = task_subtasks.task_id
      and public.is_workspace_editor(t.workspace_id)));

drop policy if exists dependencies_write on public.task_dependencies;
create policy dependencies_write on public.task_dependencies
  for all
  using (exists (
    select 1 from public.tasks t
    where t.id = task_dependencies.task_id
      and public.is_workspace_editor(t.workspace_id)))
  with check (exists (
    select 1 from public.tasks t
    where t.id = task_dependencies.task_id
      and public.is_workspace_editor(t.workspace_id)));

drop policy if exists prs_write on public.pull_requests;
create policy prs_write on public.pull_requests
  for all
  using (public.is_workspace_editor(workspace_id))
  with check (public.is_workspace_editor(workspace_id));

drop policy if exists sprint_items_write on public.sprint_items;
create policy sprint_items_write on public.sprint_items
  for all
  using (exists (
    select 1 from public.sprints s
    where s.id = sprint_items.sprint_id
      and public.is_workspace_editor(s.workspace_id)))
  with check (exists (
    select 1 from public.sprints s
    where s.id = sprint_items.sprint_id
      and public.is_workspace_editor(s.workspace_id)));

-- --- activity must always be attributed ------------------------------------

drop policy if exists activity_insert on public.activity_events;
create policy activity_insert on public.activity_events
  for insert with check (
    public.is_workspace_editor(workspace_id)
    and actor_id = (select auth.uid())
  );

-- --- ownership transfer ----------------------------------------------------

create or replace function public.transfer_ownership(target uuid, new_owner uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := (select auth.uid());
  current_owner uuid;
begin
  if caller is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if new_owner is null then
    raise exception 'new_owner is required' using errcode = '22023';
  end if;

  select m.user_id into current_owner
  from public.workspace_members m
  where m.workspace_id = target and m.role = 'owner'
  limit 1;

  if current_owner is null then
    raise exception 'workspace has no owner' using errcode = '22023';
  end if;
  if current_owner <> caller then
    raise exception 'only the current owner can transfer ownership'
      using errcode = '42501';
  end if;
  if new_owner = caller then
    return;
  end if;
  if not exists (
    select 1 from public.workspace_members m
    where m.workspace_id = target and m.user_id = new_owner
  ) then
    raise exception 'the new owner must already be a member' using errcode = '22023';
  end if;

  -- Serialise concurrent transfers of the same workspace.
  perform pg_advisory_xact_lock(hashtextextended(target::text, 0));

  update public.workspace_members set role = 'owner'
   where workspace_id = target and user_id = new_owner;
  update public.workspace_members set role = 'admin'
   where workspace_id = target and user_id = caller;
  update public.workspaces set owner_id = new_owner, updated_at = now()
   where id = target;
end;
$$;

revoke all on function public.transfer_ownership(uuid, uuid) from anon, public;
grant execute on function public.transfer_ownership(uuid, uuid) to authenticated;

-- --- keep the earlier functions off-limits to `anon` too -------------------
-- The platform grants EXECUTE to `anon` through its default privileges, so
-- `revoke ... from public` alone is not enough.
revoke all on function public.is_workspace_member(uuid) from anon, public;
revoke all on function public.is_workspace_admin(uuid) from anon, public;
revoke all on function public.is_workspace_owner(uuid) from anon, public;
revoke all on function public.get_workspace_snapshot(uuid) from anon, public;
revoke all on function public.ensure_my_workspace(text) from anon, public;

grant execute on function public.is_workspace_member(uuid) to authenticated;
grant execute on function public.is_workspace_admin(uuid) to authenticated;
grant execute on function public.is_workspace_owner(uuid) to authenticated;
grant execute on function public.get_workspace_snapshot(uuid) to authenticated;
grant execute on function public.ensure_my_workspace(text) to authenticated;
