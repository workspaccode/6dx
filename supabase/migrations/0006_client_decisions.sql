-- ---------------------------------------------------------------------------
-- 0006 — client decisions
--
-- `activity_events` is writable by editors only (0004), but recording what the
-- *client* decided is a read-mostly action that a `viewer` (an external client)
-- must be able to perform. Instead of widening the activity policy, the action
-- gets its own SECURITY DEFINER entry point that always attributes the row to
-- the caller.
-- ---------------------------------------------------------------------------

create or replace function public.submit_client_decision(
  target uuid,
  option_index integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := (select auth.uid());
  options text[];
  chosen text;
begin
  if caller is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if not public.is_workspace_member(target) then
    raise exception 'not a workspace member' using errcode = '42501';
  end if;

  select c.decision_options into options
  from public.client_reports c
  where c.workspace_id = target
  limit 1;

  if options is not null and option_index >= 0 and option_index < array_length(options, 1) then
    chosen := options[option_index + 1];
  else
    chosen := 'الخيار ' || (option_index + 1);
  end if;

  insert into public.activity_events (workspace_id, type, text, actor_id)
  values (target, 'client_decision', 'قرار العميل: ' || chosen, caller);
end;
$$;

revoke all on function public.submit_client_decision(uuid, integer) from anon, public;
grant execute on function public.submit_client_decision(uuid, integer) to authenticated;