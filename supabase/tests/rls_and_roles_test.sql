-- Row level security, roles and ownership — pgTAP.
--
-- Run against a LOCAL database only:
--     supabase start && supabase test db
--
-- Everything happens inside one transaction that is rolled back, so the probe
-- users/rows never survive the run. Never point this at production.

begin;

create extension if not exists pgtap;

create schema if not exists tests;

-- Impersonates a user exactly the way PostgREST does.
create or replace function tests.authenticate_as(uid uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text,
    true
  );
end;
$$;

create or replace function tests.reset_role()
returns void
language plpgsql
as $$
begin
  perform set_config('role', 'postgres', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

select no_plan();

-- ---------------------------------------------------------------------------
-- Fixtures: one owner, one admin, one developer, one viewer
-- ---------------------------------------------------------------------------
insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner@test.local', now(), now()),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@test.local', now(), now()),
  ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dev@test.local', now(), now()),
  ('44444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'viewer@test.local', now(), now());

insert into public.workspaces (id, name, slug, owner_id)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test', 'test-ws', '11111111-1111-1111-1111-111111111111');

insert into public.workspace_members (workspace_id, user_id, role)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'owner'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'admin'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '33333333-3333-3333-3333-333333333333', 'developer'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '44444444-4444-4444-4444-444444444444', 'viewer');

-- ---------------------------------------------------------------------------
-- 1. Role escalation is impossible
-- ---------------------------------------------------------------------------
select tests.authenticate_as('22222222-2222-2222-2222-222222222222');

select results_eq(
  $$ update public.workspace_members set role = 'owner'
      where workspace_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        and user_id = '22222222-2222-2222-2222-222222222222'
      returning user_id $$,
  $$ select null::uuid where false $$,
  'admin cannot promote themselves to owner'
);

select results_eq(
  $$ update public.workspace_members set role = 'developer'
      where workspace_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        and role = 'owner'
      returning user_id $$,
  $$ select null::uuid where false $$,
  'admin cannot demote the owner'
);

select results_eq(
  $$ delete from public.workspace_members
      where workspace_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        and role = 'owner'
      returning user_id $$,
  $$ select null::uuid where false $$,
  'admin cannot delete the owner'
);

select throws_ok(
  $$ insert into public.workspace_members (workspace_id, user_id, role)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
             '33333333-3333-3333-3333-333333333333', 'owner') $$,
  '23505',
  null,
  'the database rejects a second owner (partial unique index)'
);

select throws_ok(
  $$ insert into public.workspace_members (workspace_id, user_id, role)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
             '44444444-4444-4444-4444-444444444444', 'admin') $$,
  '23505',
  null,
  'admin cannot re-insert an existing member to change the role'
);

-- ---------------------------------------------------------------------------
-- 2. Viewers are read-only, editors can write
-- ---------------------------------------------------------------------------
select tests.authenticate_as('44444444-4444-4444-4444-444444444444');

select throws_ok(
  $$ insert into public.projects (workspace_id, name)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'viewer project') $$,
  '42501',
  null,
  'viewer cannot create a project'
);

select throws_ok(
  $$ insert into public.tasks (workspace_id, title)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'viewer task') $$,
  '42501',
  null,
  'viewer cannot create a task'
);

select lives_ok(
  $$ select 1 from public.projects
      where workspace_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' $$,
  'viewer can still read projects'
);

select tests.authenticate_as('33333333-3333-3333-3333-333333333333');

select lives_ok(
  $$ insert into public.projects (workspace_id, name)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'dev project') $$,
  'developer can create a project'
);

-- ---------------------------------------------------------------------------
-- 3. Activity must be attributed to the caller
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.activity_events (workspace_id, type, text, actor_id)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'forged', 'x',
             '11111111-1111-1111-1111-111111111111') $$,
  '42501',
  null,
  'a member cannot write activity on behalf of somebody else'
);

select throws_ok(
  $$ insert into public.activity_events (workspace_id, type, text, actor_id)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'anon', 'x', null) $$,
  '42501',
  null,
  'activity without an actor is rejected'
);

select lives_ok(
  $$ insert into public.activity_events (workspace_id, type, text, actor_id)
     values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ok', 'x',
             '33333333-3333-3333-3333-333333333333') $$,
  'a member can write their own activity'
);

-- ---------------------------------------------------------------------------
-- 4. Ownership transfer
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ select public.transfer_ownership('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                                      '33333333-3333-3333-3333-333333333333') $$,
  '42501',
  'only the current owner can transfer ownership',
  'a developer cannot transfer ownership'
);

select tests.authenticate_as('11111111-1111-1111-1111-111111111111');

select lives_ok(
  $$ select public.transfer_ownership('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
                                      '22222222-2222-2222-2222-222222222222') $$,
  'the owner can transfer ownership'
);

select tests.reset_role();

select is(
  (select role::text from public.workspace_members
    where workspace_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      and user_id = '22222222-2222-2222-2222-222222222222'),
  'owner',
  'the new owner has the owner role'
);

select is(
  (select role::text from public.workspace_members
    where workspace_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      and user_id = '11111111-1111-1111-1111-111111111111'),
  'admin',
  'the previous owner is demoted to admin'
);

select is(
  (select owner_id from public.workspaces
    where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  '22222222-2222-2222-2222-222222222222'::uuid,
  'workspaces.owner_id follows the transfer'
);

-- ---------------------------------------------------------------------------
-- 5. `anon` cannot reach the helper functions
-- ---------------------------------------------------------------------------
select ok(
  not has_function_privilege('anon', 'public.get_workspace_snapshot(uuid)', 'EXECUTE'),
  'anon cannot execute get_workspace_snapshot'
);

select ok(
  not has_function_privilege('anon', 'public.ensure_my_workspace(text)', 'EXECUTE'),
  'anon cannot execute ensure_my_workspace'
);

-- ---------------------------------------------------------------------------
-- 6. Client decisions are allowed for every member (incl. viewer)
-- ---------------------------------------------------------------------------
insert into public.client_reports (workspace_id, client_name, project_name, decision_options)
values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Acme', 'Test', array['Ship', 'Wait']);

select tests.authenticate_as('44444444-4444-4444-4444-444444444444');

select throws_ok(
  $$ select public.submit_client_decision('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 5) $$,
  '22023',
  null,
  'an out-of-range option index is rejected'
);

select lives_ok(
  $$ select public.submit_client_decision('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 0) $$,
  'a viewer can record the client decision through the RPC'
);

select throws_ok(
  $$ select public.submit_client_decision('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 1) $$,
  '23505',
  null,
  'a non-admin cannot overwrite an already recorded decision'
);

select tests.reset_role();

select is(
  (select count(*)::int from public.activity_events
    where workspace_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      and type = 'client_decision'
      and actor_id = '44444444-4444-4444-4444-444444444444'),
  1,
  'the decision is attributed to the viewer who submitted it'
);

-- ---------------------------------------------------------------------------
-- 7. Invitations: notify on insert, accept exactly once
-- ---------------------------------------------------------------------------
select tests.authenticate_as('11111111-1111-1111-1111-111111111111');

insert into auth.users (id, instance_id, aud, role, email, created_at, updated_at)
values ('55555555-5555-5555-5555-555555555555',
        '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'invitee@test.local', now(), now());

insert into public.workspace_invites (id, workspace_id, email, role, invited_by)
values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'invitee@test.local',
        'developer', '11111111-1111-1111-1111-111111111111');

select tests.reset_role();

select is(
  (select count(*)::int from public.notifications
    where invite_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  1,
  'inviting an existing account creates exactly one notification'
);

select tests.authenticate_as('55555555-5555-5555-5555-555555555555');

select is(
  (select count(*)::int from public.my_pending_invites()),
  1,
  'the invitee sees the pending invite'
);

select is(
  public.accept_invite(null),
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid,
  'accepting returns the joined workspace'
);

select is(
  (select role::text from public.workspace_members
    where workspace_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      and user_id = '55555555-5555-5555-5555-555555555555'),
  'developer',
  'the membership carries the invited role'
);

select throws_ok(
  $$ select public.accept_invite(null) $$,
  'P0002',
  null,
  'an invite cannot be accepted twice'
);

select tests.reset_role();

select is(
  (select status::text from public.workspace_invites
    where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  'accepted',
  'the invite is marked as accepted'
);

select is(
  (select is_read from public.notifications
    where invite_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  true,
  'accepting marks the notification as read'
);

select * from finish();
rollback;
