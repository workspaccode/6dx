-- ---------------------------------------------------------------------------
-- 0003 — GitHub App installation
--
-- Authorization is separated from identity:
--   * identity  → Supabase Auth (GitHub OAuth app, scopes `read:user user:email`)
--   * repo access → a GitHub App installed by the user/org admin on the
--     repositories they choose. The App private key never leaves the server
--     (Edge Function `github-app`), so the client holds no GitHub token.
--
-- One workspace may have several installations (personal + org); the Edge
-- Function picks the one that can see the requested repository.
-- ---------------------------------------------------------------------------

create table if not exists public.github_installations (
  id              uuid primary key default gen_random_uuid(),
  workspace_id    uuid not null references public.workspaces (id) on delete cascade,
  installation_id bigint not null,
  account_login   text not null,
  account_type    text not null default 'User',
  created_by      uuid references auth.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  unique (workspace_id, installation_id)
);

create index if not exists github_installations_workspace_idx
  on public.github_installations (workspace_id);
create index if not exists github_installations_installation_idx
  on public.github_installations (installation_id);

-- Which installation the linked repository belongs to (needed for API calls
-- and for matching webhooks back to a project).
alter table public.repositories
  add column if not exists installation_id bigint;

-- The webhook upserts a pull request by (`workspace_id`, `number`), which needs
-- a unique key to conflict on.
create unique index if not exists pull_requests_workspace_number_idx
  on public.pull_requests (workspace_id, number);

alter table public.github_installations enable row level security;

create policy github_installations_read on public.github_installations
  for select using (public.is_workspace_member(workspace_id));
create policy github_installations_insert on public.github_installations
  for insert with check (
    public.is_workspace_admin(workspace_id)
    and (created_by is null or created_by = auth.uid())
  );
create policy github_installations_delete on public.github_installations
  for delete using (public.is_workspace_admin(workspace_id));

-- The Edge Function writes with the service role, but the table stays
-- reachable for authenticated reads (the picker shows the connected account).
grant select, insert, update, delete on public.github_installations
  to anon, authenticated;
