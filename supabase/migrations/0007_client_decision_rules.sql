-- ---------------------------------------------------------------------------
-- 0007 — client decisions, tightened
--
-- Review of 0006 found four gaps:
--   1. `limit 1` without an ordering column picked an arbitrary report.
--   2. an out-of-range `option_index` was silently recorded as "the Nth option".
--   3. nothing stopped the same decision being submitted over and over.
--   4. the chosen option was only recoverable by reading free-text activity.
--
-- The report is now part of the data model (one per workspace, matching the
-- single report the snapshot returns), the index is validated, and the decision
-- is written once (an owner/admin may overwrite it).
-- ---------------------------------------------------------------------------

-- One client report per workspace, so "the report of this workspace" is well
-- defined — that is what the snapshot already assumes.
create unique index if not exists client_reports_one_per_workspace_idx
  on public.client_reports (workspace_id);

alter table public.client_reports
  add column if not exists decision_choice text,
  add column if not exists decided_by uuid references auth.users (id) on delete set null,
  add column if not exists decided_at timestamptz;

-- The return type changes (void → text), so the old function has to go first.
drop function if exists public.submit_client_decision(uuid, integer);

create or replace function public.submit_client_decision(
  target uuid,
  option_index integer
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := (select auth.uid());
  report public.client_reports;
  chosen text;
begin
  if caller is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if not public.is_workspace_member(target) then
    raise exception 'not a workspace member' using errcode = '42501';
  end if;

  select * into report
  from public.client_reports c
  where c.workspace_id = target
  limit 1;                      -- safe: one report per workspace (unique index)

  if report.id is null then
    raise exception 'no client report for this workspace' using errcode = 'P0002';
  end if;

  if option_index is null
     or option_index < 0
     or option_index >= coalesce(array_length(report.decision_options, 1), 0) then
    raise exception 'option_index % is out of range (0..%)',
      option_index, coalesce(array_length(report.decision_options, 1), 0) - 1
      using errcode = '22023';
  end if;

  chosen := report.decision_options[option_index + 1];

  -- One decision per report; an owner/admin may correct it.
  if report.decided_at is not null and not public.is_workspace_admin(target) then
    raise exception 'the client decision was already recorded' using errcode = '23505';
  end if;

  update public.client_reports
     set decision_choice = chosen,
         decided_by = caller,
         decided_at = now()
   where id = report.id;

  insert into public.activity_events (workspace_id, type, text, actor_id)
  values (target, 'client_decision', 'قرار العميل: ' || chosen, caller);

  return chosen;
end;
$$;

revoke all on function public.submit_client_decision(uuid, integer) from anon, public;
grant execute on function public.submit_client_decision(uuid, integer) to authenticated;
