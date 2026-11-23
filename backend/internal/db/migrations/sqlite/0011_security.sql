-- Stage C (security) of the stable release.

-- Each GitHub connect state (signed or recovery) is accepted once: a callback
-- URL that leaks (browser history, a proxy log, a screenshot) cannot be
-- replayed while it is still within its 10 minutes. Rows older than the state
-- lifetime are pruned as new ones arrive.
create table github_state_uses (
  state_hash text primary key,              -- sha256 of the raw state
  used_at    text not null
);
create index github_state_uses_used_idx on github_state_uses (used_at);
