-- ---------------------------------------------------------------------------
-- 0008 — invitations end to end
--
-- Before this migration an invite was a row nobody could act on:
--   * no notification was created for the invitee,
--   * there was no way to accept it (RLS forbids adding yourself as a member),
--   * a pre-existing account and a brand-new one were treated the same.
--
-- All three are fixed here:
--   * `notifications.invite_id` links a notification to its invite (so it can be
--     deduplicated and marked read on accept),
--   * a trigger notifies an invitee who already has an account,
--   * `sync_my_invites()` delivers the notifications for invites that arrived
--     before the account existed (called when the app loads),
--   * `accept_invite()` turns a pending invite into a membership.
-- ---------------------------------------------------------------------------

alter table public.notifications
  add column if not exists invite_id uuid
    references public.workspace_invites (id) on delete cascade;

-- One notification per (user, invite): makes sync/tick idempotent.
create unique index if not exists notifications_invite_unique_idx
  on public.notifications (user_id, invite_id)
  where invite_id is not null;

/** The caller's email, falling back to the identity e-mail for GitHub users. */
create or replace function public.current_email()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(lower(u.email), ''),
    (select lower(i.email) from auth.identities i
      where i.user_id = u.id and i.email is not null
      order by i.created_at limit 1)
  )
  from auth.users u
  where u.id = (select auth.uid());
$$;

revoke all on function public.current_email() from anon, public;
grant execute on function public.current_email() to authenticated;

-- --- notify an existing account as soon as it is invited --------------------

create or replace function public.notify_invite()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  workspace_name text;
  inviter text;
begin
  select w.name into workspace_name from public.workspaces w where w.id = new.workspace_id;
  select coalesce(u.raw_user_meta_data->>'full_name', u.email)
    into inviter from auth.users u where u.id = new.invited_by;

  insert into public.notifications
    (workspace_id, user_id, kind, title, body, action_label, invite_id)
  select new.workspace_id,
         u.id,
         'invite',
         'دعوة للانضمام إلى ' || coalesce(workspace_name, 'مساحة عمل'),
         coalesce(inviter, 'أحد المدراء') || ' دعاك للانضمام بدور ' || new.role::text,
         'قبول الدعوة',
         new.id
  from auth.users u
  where lower(u.email) = lower(new.email)
  on conflict (user_id, invite_id) where invite_id is not null do nothing;

  return new;
end;
$$;

drop trigger if exists workspace_invites_notify on public.workspace_invites;
create trigger workspace_invites_notify
  after insert on public.workspace_invites
  for each row execute function public.notify_invite();

-- --- deliver invites that arrived before the account existed ----------------

create or replace function public.sync_my_invites()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := (select auth.uid());
  caller_email text := public.current_email();
  created integer := 0;
begin
  if caller is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if caller_email is null then
    return 0;
  end if;

  with pending as (
    select i.*
    from public.workspace_invites i
    where i.status = 'pending'
      and lower(i.email) = caller_email
      and i.expires_at > now()
      and not exists (
        select 1 from public.workspace_members m
        where m.workspace_id = i.workspace_id and m.user_id = caller
      )
  ), inserted as (
    insert into public.notifications
      (workspace_id, user_id, kind, title, body, action_label, invite_id)
    select p.workspace_id,
           caller,
           'invite',
           'دعوة للانضمام إلى ' || coalesce(w.name, 'مساحة عمل'),
           'تمت دعوتك للانضمام بدور ' || p.role::text,
           'قبول الدعوة',
           p.id
    from pending p
    left join public.workspaces w on w.id = p.workspace_id
    on conflict (user_id, invite_id) where invite_id is not null do nothing
    returning 1
  )
  select count(*) into created from inserted;

  return created;
end;
$$;

revoke all on function public.sync_my_invites() from anon, public;
grant execute on function public.sync_my_invites() to authenticated;

-- --- what the accept screen shows ------------------------------------------

create or replace function public.my_pending_invites()
returns table (
  invite_id uuid,
  workspace_id uuid,
  workspace_name text,
  role public.member_role,
  email text,
  sent_at timestamptz,
  expires_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select i.id, i.workspace_id, w.name, i.role, i.email, i.sent_at, i.expires_at
  from public.workspace_invites i
  join public.workspaces w on w.id = i.workspace_id
  where i.status = 'pending'
    and lower(i.email) = public.current_email()
    and i.expires_at > now()
    and not exists (
      select 1 from public.workspace_members m
      where m.workspace_id = i.workspace_id
        and m.user_id = (select auth.uid())
    )
  order by i.sent_at desc;
$$;

revoke all on function public.my_pending_invites() from anon, public;
grant execute on function public.my_pending_invites() to authenticated;

-- --- accept ----------------------------------------------------------------

create or replace function public.accept_invite(target uuid default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := (select auth.uid());
  caller_email text := public.current_email();
  invite public.workspace_invites;
begin
  if caller is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if caller_email is null then
    raise exception 'your account has no e-mail to match the invite against'
      using errcode = '22023';
  end if;

  if target is null then
    select * into invite
    from public.workspace_invites i
    where i.status = 'pending'
      and lower(i.email) = caller_email
      and i.expires_at > now()
    order by i.sent_at desc
    limit 1;
  else
    select * into invite
    from public.workspace_invites i
    where i.id = target;
  end if;

  if invite.id is null then
    raise exception 'no pending invite for this account' using errcode = 'P0002';
  end if;
  if lower(invite.email) <> caller_email then
    raise exception 'this invite belongs to another e-mail address'
      using errcode = '42501';
  end if;
  if invite.status <> 'pending' then
    raise exception 'invite is %', invite.status using errcode = '22023';
  end if;
  if invite.expires_at <= now() then
    update public.workspace_invites set status = 'expired' where id = invite.id;
    raise exception 'invite has expired' using errcode = '22023';
  end if;

  insert into public.workspace_members (workspace_id, user_id, role)
  values (invite.workspace_id, caller, invite.role)
  on conflict (workspace_id, user_id) do nothing;

  update public.workspace_invites
     set status = 'accepted'
   where id = invite.id;

  update public.notifications
     set is_read = true
   where user_id = caller and invite_id = invite.id;

  -- tell whoever sent the invite
  if invite.invited_by is not null then
    insert into public.notifications
      (workspace_id, user_id, kind, title, body)
    values (
      invite.workspace_id,
      invite.invited_by,
      'member_joined',
      'عضو جديد في مساحة العمل',
      coalesce(caller_email, 'مستخدم') || ' قبل الدعوة وانضم بدور ' || invite.role::text
    );
  end if;

  return invite.workspace_id;
end;
$$;

revoke all on function public.accept_invite(uuid) from anon, public;
grant execute on function public.accept_invite(uuid) to authenticated;
