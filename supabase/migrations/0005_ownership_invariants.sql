-- ---------------------------------------------------------------------------
-- 0005 — invariants that belong in the database
--
--   1. A workspace has exactly one owner, enforced by the database instead of
--      relying on the policies alone.
--   2. Deleting a user no longer deletes their workspace (and with it every
--      member's work): the FK is RESTRICT, so ownership has to be transferred
--      first with `transfer_ownership()`.
-- ---------------------------------------------------------------------------

-- One owner per workspace. Safe to add after 0004 because every workspace has
-- at most one `owner` row (verified: transfer_ownership swaps atomically).
create unique index if not exists workspace_members_single_owner_idx
  on public.workspace_members (workspace_id)
  where role = 'owner';

-- `workspaces.owner_id` was `on delete cascade`: deleting the owner's account
-- wiped the whole workspace. Refuse the delete instead and require a transfer.
alter table public.workspaces
  drop constraint if exists workspaces_owner_id_fkey;

alter table public.workspaces
  add constraint workspaces_owner_id_fkey
  foreign key (owner_id) references auth.users (id) on delete restrict;
