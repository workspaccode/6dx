-- ---------------------------------------------------------------------------
-- 0002 — workspace bootstrap
--
-- A fresh account owns nothing yet. `workspaces` only has a read and an update
-- policy (a member has to exist before a row can be read), so the client cannot
-- insert the first workspace itself: RLS would reject it. This SECURITY DEFINER
-- function creates the workspace and the owner membership in one step.
-- ---------------------------------------------------------------------------

create or replace function public.ensure_my_workspace(
  workspace_name text default 'مساحة عملي'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  uid      uuid := auth.uid();
  existing uuid;
  created  uuid;
  slug     text;
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;

  select m.workspace_id into existing
  from public.workspace_members m
  where m.user_id = uid
  limit 1;

  if existing is not null then
    return existing;
  end if;

  -- `slug` is unique: the user id plus a timestamp keeps concurrent first
  -- sign-ins from colliding.
  slug := 'ws-' || left(replace(uid::text, '-', ''), 8)
          || '-' || to_char(now(), 'YYMMDDHH24MISS');

  insert into public.workspaces (name, slug, owner_id)
  values (workspace_name, slug, uid)
  returning id into created;

  insert into public.workspace_members (workspace_id, user_id, role)
  values (created, uid, 'owner');

  return created;
end;
$$;

revoke all on function public.ensure_my_workspace(text) from public;
grant execute on function public.ensure_my_workspace(text) to authenticated;
