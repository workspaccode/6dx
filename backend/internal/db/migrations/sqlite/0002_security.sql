-- 0002: security fixes from docs/review (second pass).

-- One installation belongs to exactly one workspace. Webhooks resolve the
-- workspace by installation id, so a duplicate would leak one org's pull
-- requests into another workspace. Keep the oldest row if duplicates exist.
delete from github_installations
 where rowid not in (
   select min(rowid) from github_installations group by installation_id
 );
create unique index github_installations_installation_idx
  on github_installations (installation_id);

-- Webhook lookups by installation and the hot member lookups.
create index if not exists workspace_members_user_idx on workspace_members (user_uid);
