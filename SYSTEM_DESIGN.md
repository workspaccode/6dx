# 6DX — Full System Design

Everything needed to rebuild, operate, or **self-host the backend** for the 6DX
Flutter app. The two SQL files in [`supabase/migrations`](./supabase/migrations)
are the authoritative schema; this document explains what they contain, why,
and what the client expects from them.

* App: Flutter 3.x / Dart 3.13, Riverpod, go_router, auto_route
* Backend: **Supabase only** — Postgres + PostgREST + GoTrue, plus **one**
  Edge Function (`github-app`) that brokers GitHub App tokens, because a GitHub
  App's private key cannot live in a client (§6.3). No REST API of our own.
* Auth: GitHub OAuth through Supabase (PKCE) with a device-flow fallback.
* Current hosted project: `ifrpswaclrrsshspdmzd` (region `eu-central-2`, Postgres 17.11)

---

## 1. Architecture

```
┌─────────────────────────── Flutter app ────────────────────────────┐
│                                                                    │
│  presentation (pages, providers)                                   │
│        │  Riverpod providers = DI container                        │
│  domain (entities, repository contracts, use cases)                │
│        │                                                           │
│  data (data sources → Supabase, repositories → Result<T>)          │
│        │                                                           │
│  core (Supabase client, workspace resolver, logger, storage, Dio)  │
└───────┬────────────────────────────────────────────────────────────┘
        │  HTTPS (JWT = Supabase access token)
        ▼
┌──────────────────────────── Supabase ──────────────────────────────┐
│  GoTrue (auth)        →  JWT                                       │
│  PostgREST            →  RLS → public schema                       │
│  Postgres 17          →  functions, policies, grants               │
│  Edge Function github-app → GitHub App private key → api.github.com│
└────────────────────────────────────────────────────────────────────┘
```

There is **no server-side business layer**: every data read/write is a PostgREST
call executed as the signed-in user, and Row Level Security decides what that
user may touch. The only server logic is five SQL functions (§5.4) and the
`github-app` Edge Function that brokers GitHub (§6.3).

---

## 2. Client layout

```
lib/
├── app/                       # SixDxApp (MaterialApp.router) + app-wide providers
├── core/
│   ├── config/app_config.dart # Supabase URL/key, redirect URL, scopes
│   ├── constants/             # colors, endpoints, storage keys, OAuth client id
│   ├── errors/                # Failure (sealed) + exceptions
│   ├── network/
│   │   ├── supabase_client.dart     # lazy client + runSupabase(label, …) + error mapping
│   │   ├── current_workspace.dart   # resolves the member's workspace, bootstraps the first
│   │   ├── github_auth_interceptor.dart  # adds the GitHub token to GitHub calls
│   │   ├── dio_factory.dart / auth_interceptor.dart / retry_interceptor.dart
│   ├── storage/               # SecureStorageService (token, user, github_token), LocalStorage
│   ├── utils/                 # Result<T>, AppLogger
├── features/<feature>/{domain,data,presentation}
├── routes/                    # go_router paths + generated auto_route table
└── shared/widgets/            # ui_kit (AppScreen/AppPanel/SettingsTile…), states
```

Conventions that matter for the backend:

* **Repositories never throw** — they return `Result<T>` (`Success` /
  `FailureResult`). Failures carry a user-facing Arabic message.
* **Every Supabase query goes through `runSupabase(label, …)`**, which logs
  `label → start` / `→ ok (Nms)` / `→ FAILED [code] message` and maps
  `PostgrestException`/`AuthException` to `ServerException`/`UnauthorizedException`.
* **No mock data exists.** A failing query surfaces as an empty state plus a
  reason; nothing is invented client-side.

---

## 3. Runtime configuration (no secrets in the repo)

| Setting | Source | Default |
|---|---|---|
| `SUPABASE_URL` | `--dart-define` | `https://ifrpswaclrrsshspdmzd.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | `--dart-define` | project publishable key (safe to ship) |
| `SUPABASE_REDIRECT_URL` | `--dart-define` | `io.supabase.flutter://login-callback` |
| `GITHUB_CLIENT_ID` | `--dart-define` | `Ov23liw4p0LMObMu8l9b` (device-flow fallback only) |
| GitHub scopes | `AppConfig.githubScopes` | `read:user user:email` — **identity only**; repositories are granted through a GitHub App (§6.3) |


Supabase auth activates whenever both `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY` are non-empty (`AppConfig.useSupabaseAuth`).
Leaving the URL empty forces the GitHub **device-flow** backend instead.

**Never** put the `service_role` / `sb_secret_…` key in the app.

### Secure storage keys

| Key | Content |
|---|---|
| `access_token` | Supabase access token (JWT) — attached as `Authorization: Bearer` to app API calls |
| `user` | cached `UserModel` JSON |

**No GitHub credential is stored on the device.** Repository access is brokered
by the `github-app` Edge Function, which holds the App private key and mints a
short-lived installation token server-side (§6.3).

---

## 4. Authentication

Two `AuthBackend` implementations, chosen at start-up.

| Backend | Used when | Flow |
|---|---|---|
| `SupabaseAuthBackend` | Supabase configured (default) | browser OAuth + PKCE, session arrives via deep link |
| `DeviceFlowAuthBackend` | Supabase URL empty | GitHub device flow, user types a code on github.com |

### 4.1 Supabase (primary)

```
tap "Continue with GitHub"
   │
   ├─ auth.signInWithOAuth(github, redirectTo: <custom scheme>, scopes: …)
   │      → launches the browser at GitHub
   ├─ user approves on github.com
   ├─ GitHub → https://<project>.supabase.co/auth/v1/callback (code exchange)
   ├─ GoTrue → io.supabase.flutter://login-callback?code=…
   ├─ Android/iOS opens the app (intent filter / URL scheme)
   ├─ supabase_flutter handles the deep link (detectSessionInUri: true)
   └─ AuthChangeEvent.signedIn → backend resolves; app navigates home
```

Client requirements, all already in the repo:

* `Supabase.initialize(..., authOptions: FlutterAuthClientOptions(detectSessionInUri: true))`
  in `lib/main.dart`.
* Android intent filter on `MainActivity`:
  `scheme=io.supabase.flutter`, `host=login-callback`
  (`android/app/src/main/AndroidManifest.xml`), plus `launchMode="singleTop"`
  and no `taskAffinity` so the link lands in the running instance.
* iOS `CFBundleURLTypes` → `io.supabase.flutter`
  (`ios/Runner/Info.plist`).
* The backend waits on `onAuthStateChange` for a non-null session with a
  **2-minute** timeout; on timeout it reports that the redirect URL is not
  registered instead of hanging.

### 4.2 Server-side auth configuration (per environment)

GoTrue must know where to send users back:

| Setting | Hosted value | Notes |
|---|---|---|
| Site URL | `io.supabase.flutter://login-callback` | fallback target when `redirect_to` is not allow-listed |
| Additional redirect URLs (`uri_allow_list`) | **currently empty** | ⚠️ set it to `io.supabase.flutter://login-callback` so the flow does not depend on the Site-URL fallback |
| GitHub provider | enabled, client id `Ov23liw4p0LMObMu8l9b` | the GitHub client **secret** lives here, never in the app |
| Email provider | enabled, `mailer_autoconfirm = false` | sign-up expects an OTP confirmation |
| Leaked-password protection | off | opt-in in the dashboard |

The GitHub OAuth app must have callback URL
`https://<project>.supabase.co/auth/v1/callback` (hosted) or
`https://<self-hosted-host>/auth/v1/callback` (self-host).

### 4.3 Device flow (fallback)

Used only when Supabase is not configured. Needs a GitHub **client id** whose
OAuth app has *Enable Device Flow* turned on; otherwise GitHub answers
`400 device_flow_disabled` and the app shows that hint.

1. `POST https://github.com/login/device/code`
   body (form-encoded, **not** a query string — a query returns `404`):
   `client_id`, `scope` → `device_code`, `user_code`, `verification_uri`, `interval`, `expires_in`
2. User enters `user_code` on `verification_uri`.
3. Poll `POST https://github.com/login/oauth/access_token`
   body: `client_id`, `device_code`, `grant_type=urn:ietf:params:oauth:grant-type:device_code`
   * `authorization_pending` → wait `interval`, poll again
   * `slow_down` → increase the interval (the response carries a new one)
   * `expired_token` → restart
   * `access_token` → success
4. `GET https://api.github.com/user` and `/user/emails` (Bearer token).
5. The grant is stored as **both** `access_token` and `github_token`.

No client secret is used or shipped: GitHub's device flow does not require one.

---

## 5. Database (Supabase `public` schema)

### 5.1 Enums

| Enum | Values |
|---|---|
| `member_role` | `owner`, `admin`, `developer`, `reviewer`, `viewer` |
| `invite_status` | `pending`, `accepted`, `expired`, `revoked` |
| `task_status` | `todo`, `in_progress`, `review`, `done` |
| `task_priority` | `low`, `medium`, `high`, `urgent` |
| `dependency_state` | `blocked`, `blocking`, `review` |
| `integration_kind` | `slack`, `discord`, `teams` |

Dart ↔ Postgres mapping: `TaskStatus.inProgress` ⇄ `in_progress`
(`TaskRemoteDataSource.statusToDb` / `statusFromDb`). Everything else is
identical.

### 5.2 Tables
All tables have RLS enabled. `auth.users` is owned by GoTrue — the app never
writes it.

| Table | Columns (type · default) |
|---|---|
| `workspaces` | `id` uuid pk · `name` text · `slug` text **unique** · `owner_id` uuid → auth.users · `settings` jsonb `'{}'` · `created_at` · `updated_at` |
| `workspace_members` | pk (`workspace_id`, `user_id`) · `role` member_role `developer` · `created_at` |
| `workspace_invites` | `id` uuid pk · `workspace_id` · `email` text · `role` member_role `developer` · `status` invite_status `pending` · `invited_by` uuid → auth.users null · `sent_at` · `expires_at` `now()+7d` |
| `projects` | `id` uuid pk · `workspace_id` · `name` text · `description` · `icon` · `color` · `is_archived` bool `false` · `created_by` uuid → auth.users null · `created_at` · `updated_at` |
| `repositories` | `id` uuid pk · `project_id` · `provider` text `github` · `full_name` text · `branch` text `main` · `description` · `language` · `last_synced_at` · `installation_id` bigint (which GitHub App installation owns it) |
| `project_labels` | `id` uuid pk · `project_id` · `name` · `color` `#9AA3B2` · unique (`project_id`,`name`) |
| `integrations` | `id` uuid pk · `workspace_id` · `kind` integration_kind · `name` · `connected` bool · `workspace` text · `channels` text[] · `events` text[] · unique (`workspace_id`,`kind`) |
| `sprints` | `id` uuid pk · `workspace_id` · `project_id` null · `name` · `goal` · `starts_at` date · `ends_at` date · `capacity` int · `committed` int · `created_at` |
| `tasks` | `id` uuid pk · `workspace_id` · `project_id` null · `sprint_id` null · `key` text · `title` · `description` · `status` task_status `todo` · `priority` task_priority `medium` · `points` int · `assignee_id` uuid → auth.users null · `label` · `branch` · `pr_number` int · `due_at` · `created_at` · `updated_at` |
| `task_comments` | `id` uuid pk · `task_id` · `author_id` null · `body` · `attachment` · `code` · `created_at` |
| `task_subtasks` | `id` uuid pk · `task_id` · `title` · `is_done` bool |
| `task_dependencies` | `id` uuid pk · `task_id` · `blocked_by` → tasks · `state` dependency_state `blocked` · `reason` |
| `pull_requests` | `id` uuid pk · `workspace_id` · `project_id` null · `task_id` null · `number` int · `title` · `author` · `branch` · `base_branch` `main` · `state` text `open` · `checks` jsonb `[]` · `files` jsonb `[]` · `additions` int · `deletions` int · `reviewer_id` null · `last_commit` · `created_at` |
| `sprint_items` | pk (`sprint_id`,`task_id`) · `points` int |
| `notifications` | `id` uuid pk · `workspace_id` · `user_id` · `kind` text `review` · `title` · `body` · `action_label` · `project_id` null · `is_read` bool · `created_at` |
| `activity_events` | `id` uuid pk · `workspace_id` · `project_id` null · `type` text · `text` · `actor_id` null · `created_at` |
| `client_reports` | `id` uuid pk · `workspace_id` · `client_name` · `project_name` · `period` · `progress` numeric `0` · `next_milestone` · `milestone_date` date · `decision_question` · `decision_options` text[] · `weekly_highlights` text[] · `invoice_lines` jsonb `[]` · `total_hours` · `hourly_rate` · `invoice_number` · `delivered_items` text[] |
| `time_entries` | `id` uuid pk · `workspace_id` · `user_id` · `kind` text · `span` text · `branch` · `client_name` · `created_at` |
| `digest_entries` | `id` uuid pk · `workspace_id` · `user_id` · `section` text `today` · `text` · `meta` · `action_label` · `tone` · `created_at` |
| `github_installations` | `id` uuid pk · `workspace_id` · `installation_id` bigint · `account_login` text · `account_type` text `User` · `created_by` uuid → auth.users null · `created_at` · unique (`workspace_id`,`installation_id`) |

Foreign keys use `ON DELETE CASCADE` for workspace-scoped children and
`ON DELETE SET NULL` for actor/assignee/reviewer columns.

There are **no triggers**: `updated_at` is only what the client/DB default
writes. Do not rely on it as a modification timestamp if you add background
jobs.

### 5.3 Indexes

Primary keys and the uniques above, plus:

```
projects(workspace_id)            projects(created_by)
tasks(workspace_id)               tasks(project_id)  tasks(assignee_id)  tasks(sprint_id)
sprints(workspace_id)             sprints(project_id)
sprint_items(task_id)
workspace_members(user_id)
workspace_invites(workspace_id)   workspace_invites(invited_by)
repositories(project_id)
project_labels(project_id, name)
pull_requests(workspace_id)  pull_requests(project_id)  pull_requests(task_id)  pull_requests(reviewer_id)
task_comments(task_id)      task_comments(author_id)
task_subtasks(task_id)      task_dependencies(task_id)  task_dependencies(blocked_by)
notifications(workspace_id) notifications(user_id)     notifications(project_id)
activity_events(workspace_id) activity_events(project_id) activity_events(actor_id)
client_reports(workspace_id)
time_entries(workspace_id)  time_entries(user_id)
digest_entries(workspace_id) digest_entries(user_id)
workspaces(owner_id)        workspaces(slug)
```

### 5.4 Functions

All seven are `SECURITY DEFINER` with a pinned `search_path = public`. Only
`authenticated` may execute them — `EXECUTE` is revoked from `anon` **and**
`public` explicitly, because the platform grants `anon` by default.

| Function | Returns | Purpose |
|---|---|---|
| `is_workspace_member(target uuid)` | bool | caller is any member of the workspace |
| `is_workspace_editor(target uuid)` | bool | caller is a member and not a `viewer` (write gate) |
| `is_workspace_admin(target uuid)` | bool | caller is `owner` or `admin` |
| `is_workspace_owner(target uuid)` | bool | caller is `owner` |
| `get_workspace_snapshot(target uuid)` | jsonb | the whole UI projection (§5.5) |
| `ensure_my_workspace(workspace_name text default 'مساحة عملي')` | uuid | returns the caller's first workspace, creating one on first sign-in |
| `transfer_ownership(target uuid, new_owner uuid)` | void | the current owner hands the workspace over (old owner becomes `admin`) |
| `submit_client_decision(target uuid, option_index integer)` | text | records the client decision on the report (one per workspace): validates the index, stores the choice, logs activity attributed to the caller; an owner/admin may overwrite |
| `current_email()` | text | the caller's e-mail, falling back to the identity e-mail (GitHub users) |
| `sync_my_invites()` | integer | (re)creates the notifications for invites that predate the account — idempotent |
| `my_pending_invites()` | table | pending invites addressed to the caller (accept screen) |
| `accept_invite(target uuid default null)` | uuid | turns a pending invite into a membership; returns the joined workspace |

`ensure_my_workspace` is the only way a workspace can come into existence:
RLS has no INSERT policy on `workspaces` (a member must already exist to see
one), so the bootstrap runs inside the function with owner rights. It takes a
`pg_advisory_xact_lock` on the user id so two concurrent first sign-ins cannot
create two workspaces, builds a unique slug (`ws-<uid8>-<timestamp>-<rand8>`),
and inserts the `owner` membership.

### 5.5 Snapshot payload contract

`rpc get_workspace_snapshot({ "target": "<workspace uuid>" })` returns a single
jsonb object. The Flutter mapper (`WorkspaceSnapshotMapper`) reads exactly
these keys — **renaming a key silently empties a screen**:

| Key | Shape |
|---|---|
| `workspace_id`, `name` | string |
| `members` | `[{id, name, role, email, avatar_url, open_tasks, is_online}]` |
| `invites` | `[{id, email, role, status, sent_at, invited_by}]` |
| `tasks` | `[{id, key, title, description, status, priority, points, project_id, project_name, assignee_name, label, branch, pr_number, due_at, created_at}]` |
| `comments` | `[{id, task_id, author, body, attachment, code, created_at}]` |
| `subtasks` | `[{id, task_id, title, is_done}]` |
| `dependencies` | `[{id, task_id, task_key, title, state, reason, assignee_name}]` |
| `activity` | `[{id, type, text, actor, at}]` (newest 200) |
| `sprints` | `[{id, name, goal, start, end, capacity, committed, items[]}]` |
| `pull_requests` | `[{id, number, title, author, branch, base_branch, state, issue_key, project_name, checks, files, additions, deletions, reviewer_name, last_commit, last_commit_author, waiting_hours}]` |
| `labels` | `[{id, name, color}]` |
| `integrations` | `[{id, name, kind, connected, workspace, channels, events}]` |
| `repositories` | `[{id, full_name, branch, description, language, last_synced_at}]` |
| `notifications` | `[{id, kind, title, body, action_label, project_id, unread, at}]` (caller only) |
| `digest` | `[{id, section, text, meta, action_label, tone}]` (caller only) |
| `client_report` | object or `null`: `{client_name, project_name, period, progress, next_milestone, milestone_date, decision_question, decision_options, weekly_highlights, invoice_lines, total_hours, hourly_rate, invoice_number, delivered_items, time_entries:[{id,kind,span,branch,client_name}], week_by_client:[{client,hours}]}` |

Optional keys the mapper tolerates but the current function does not produce:
`workload`, `workload_suggestions`, `rate_limit`. The app renders those screens
empty until a SQL source exists.

Every section is `coalesce(..., '[]')` so a new workspace gets a valid payload
instead of `null`s. The function returns **no rows** (null) for a workspace the
caller is not a member of.

### 5.6 Row Level Security — 31 policies

Names and expressions mirror the hosted project exactly.

| Table | Policy | Cmd | Rule |
|---|---|---|---|
| `workspaces` | `workspaces_read` | SELECT | `is_workspace_member(id)` |
| | `workspaces_update` | UPDATE | `is_workspace_admin(id)` (using + check) |
| | `workspaces_delete` | DELETE | `is_workspace_owner(id)` |
| `workspace_members` | `members_read` | SELECT | `is_workspace_member(workspace_id)` |
| | `members_insert` | INSERT | `is_workspace_admin(ws)` ∧ `role<>'owner'` ∧ (`role<>'admin'` ∨ `is_workspace_owner(ws)`) |
| | `members_update` | UPDATE | using: (`is_workspace_owner` ∧ `role<>'owner'`) ∨ (`is_workspace_admin` ∧ `role in (developer,reviewer,viewer)`); check adds `role<>'owner'` |
| | `members_delete` | DELETE | same shape as `members_update` using |
| `workspace_invites` | `invites_read` | SELECT | `is_workspace_member(workspace_id)` |
| | `invites_insert` | INSERT | `is_workspace_admin(ws)` ∧ `role<>'owner'` ∧ `invited_by=auth.uid()` |
| | `invites_update` | UPDATE | `is_workspace_admin(ws)`; check also `role<>'owner'` |
| | `invites_delete` | DELETE | `is_workspace_admin(ws)` |
| `projects` | `projects_write` | ALL | `is_workspace_editor(workspace_id)` |
| `repositories` | `repositories_write` | ALL | project belongs to a workspace the caller belongs to |
| `project_labels` | `labels_write` | ALL | same as repositories (via `project_id`) |
| `integrations` | `integrations_write` | ALL | `is_workspace_editor(workspace_id)` |
| `sprints` | `sprints_write` | ALL | `is_workspace_editor(workspace_id)` |
| `tasks` | `tasks_write` | ALL | `is_workspace_editor(workspace_id)` |
| `task_comments` | `comments_write` | ALL | parent task in a member workspace |
| `task_subtasks` | `subtasks_write` | ALL | parent task in a member workspace |
| `task_dependencies` | `dependencies_write` | ALL | parent task in a member workspace |
| `pull_requests` | `prs_write` | ALL | `is_workspace_editor(workspace_id)` |
| `sprint_items` | `sprint_items_write` | ALL | parent sprint in a member workspace |
| `notifications` | `notifications_write` | ALL | `user_id = auth.uid()` ∧ `is_workspace_member(workspace_id)` |
| `activity_events` | `activity_read` | SELECT | `is_workspace_member(workspace_id)` |
| | `activity_insert` | INSERT | `is_workspace_editor(workspace_id)` ∧ `actor_id = auth.uid()` |
| `client_reports` | `client_reports_read` | SELECT | `is_workspace_member(workspace_id)` |
| `time_entries` | `time_entries_read` | SELECT | `user_id = auth.uid()` ∧ `is_workspace_member(workspace_id)` |
| `digest_entries` | `digest_write` | ALL | `user_id = auth.uid()` ∧ `is_workspace_member(workspace_id)` |
| `github_installations` | `github_installations_read` | SELECT | `is_workspace_member(workspace_id)` |
| | `github_installations_insert` | INSERT | `is_workspace_admin(workspace_id)` ∧ `created_by = auth.uid()` |
| | `github_installations_delete` | DELETE | `is_workspace_admin(workspace_id)` |

Design decisions encoded here:

* **Roles are never escalated through the API.** `owner` cannot be granted by
  `members_insert`/`members_update`/`invites_*`; only `ensure_my_workspace`
  creates one owner, and it does so past RLS as `SECURITY DEFINER`. A workspace
  therefore has exactly one owner (single-owner model).
* `admin` manages developers/reviewers/viewers; only an `owner` may create
  another `admin`.
* `activity_events` rows may only be inserted by a member, and only as
  themselves (`actor_id = auth.uid()`); `client_reports`, `time_entries` and
  every derived table stay read-only through the API.
* Any member may create projects, tasks, sprints and pull requests
  (`*_write` = `is_workspace_member`), which matches how the UI is used.

### 5.7 Grants

```sql
grant usage on schema public to anon, authenticated, service_role;

grant select, insert, update, delete on all tables in schema public
  to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;
grant execute on all functions in schema public to authenticated;

alter default privileges in schema public
  grant select, insert, update, delete on tables to anon, authenticated;
alter default privileges in schema public
  grant usage, select on sequences to anon, authenticated;
alter default privileges in schema public
  grant execute on functions to authenticated;
```

Table grants are deliberately open (Supabase's own default) — **RLS is the
gate**. Without these grants PostgREST answers `42501 permission denied` even
for the correct user; this is the most common "nothing loads" cause in a fresh
environment.

---

## 6. Client ↔ backend contract

### 6.1 Queries the app runs

| Feature | Operation |
|---|---|
| workspace id | `from('workspace_members').select('workspace_id').eq('user_id', uid).limit(1)`; if empty → `rpc ensure_my_workspace` |
| workspace screen | `rpc get_workspace_snapshot {target}` |
| projects list | `from('projects').select('id,name,description,icon,color,is_archived,updated_at,repositories(full_name),tasks(status)').eq('workspace_id', id).order('updated_at', desc)` |
| project create | `insert {workspace_id, name, description, created_by}` → `.select(<same>).single()`; then `repositories insert {project_id, full_name}` |
| project archive | `update {is_archived: true}` by id + workspace |
| tasks list | `from('tasks').select('id,title,description,status,priority,project_id,label,branch,pr_number,due_at,created_at,projects(name)').eq('workspace_id', id).order('created_at', desc)` (+ optional `project_id`) |
| task create | `insert {workspace_id, title, description, project_id, priority}` → `.single()` |
| task status | `update {status}` by id + workspace → `.single()` |
| task delete | `delete` by id + workspace |
| invites | `insert [{workspace_id, email, role, invited_by}]` |
| PR review | `update pull_requests {state: approved|changes_requested, reviewer_id}` by workspace + `number` |
| client decision | `select decision_options` from `client_reports`, then `insert activity_events` |
| time approval | `select id` from `time_entries`, then `insert activity_events` |

The embedded selects (`repositories(full_name)`, `tasks(status)`,
`projects(name)`) rely on the foreign keys above; renaming a FK breaks them.

### 6.2 Postgres error → UI message

`describePostgresError()` maps configuration failures to actionable Arabic:

| Code | Meaning | Message |
|---|---|---|
| `42P01` / `PGRST205` | table missing | «جداول قاعدة البيانات غير مثبّتة — طبّق ملفات supabase/migrations» |
| `42883` / `PGRST202` | function missing | «دوال قاعدة البيانات غير مثبّتة — طبّق ملفات supabase/migrations» |
| `42501` | grant/RLS refusal | «لا توجد صلاحيات على قاعدة البيانات — أعد تطبيق supabase/migrations لضبط الـ grants» |
| `PGRST301` / expired JWT | session gone | «انتهت الجلسة، سجّل الدخول من جديد» |

### 6.3 GitHub access — GitHub App (no credential in the client)

Identity and repository access are deliberately separated:

| | Identity (login) | Repository access |
|---|---|---|
| Mechanism | Supabase OAuth → GitHub **OAuth App** | GitHub **App** installed on selected repos |
| Scopes | `read:user user:email` | App permissions: `Metadata:R`, `Contents:R`, `Issues:RW`, `Pull requests:RW` |
| Who sees what | the user's profile only | **only** the repositories picked at installation |
| Token location | Supabase session JWT | minted per request inside the Edge Function, never sent to the client |

The client calls one Supabase function and never `api.github.com`:

```
app → POST /functions/v1/github-app  { action: 'repositories' }
        │  (Supabase JWT in Authorization)
        ▼
   github-app (Edge Function, holds GITHUB_PRIVATE_KEY)
        ├─ App JWT (RS256, ≤10 min)
        ├─ POST /app/installations/{id}/access_tokens   → 1 hour token
        └─ GET  /installation/repositories               → the allowed repos
```

Actions: `installation` · `repositories` · `install-url` · `disconnect`.
Plus two GitHub-facing routes that carry no Supabase JWT:

* `GET ?installation_id=…&state=…` — the post-install redirect. `state` is an
  HMAC (30 min TTL) carrying `workspace_id.user_id`, so the function knows where
  to store the installation without trusting the browser.
* `POST /webhook` — `x-hub-signature-256` verified with `GITHUB_WEBHOOK_SECRET`;
  `pull_request` events are upserted into `pull_requests`.

Because the GitHub-facing routes carry no Supabase JWT, the function is deployed
with `--no-verify-jwt` (it authenticates everything itself).

**Ownership proof (fail closed).** `installation_id` on the Setup URL is
user-controllable, so the function does *not* store anything there. It answers
with a 302 to `github.com/login/oauth/authorize` (keeping the signed `state`),
and only after the code exchange does it verify:

* **the same person**: the GitHub `user.id` from the token must equal
  `auth.identities.provider_id` (provider `github`) of the 6DX user named in the
  signed state — otherwise a crafted install link could attach a victim's
  installation to the attacker's workspace (CSRF)
* personal account → `account.id === user.id`
* organization → `GET /user/memberships/orgs/{org}` returns `role: admin`

The user token is revoked right after (`DELETE /applications/{client_id}/token`)
and is never stored.

Without `GITHUB_CLIENT_ID`/`GITHUB_CLIENT_SECRET` the install is refused —
there is no weak fallback. Do **not** enable "Request user authorization (OAuth)
during installation": GitHub then redirects to the callback URL without our
`state`, so the workspace can no longer be identified.

**GitHub App permissions** (least privilege for what the UI does):

| Permission | Level | Used for |
|---|---|---|
| Metadata | read | always required by GitHub |
| Contents | read | repository list and branch names |
| Issues | read & write | task ↔ issue sync |
| Pull requests | read & write | PR list, review state |
| Members (organization) | read | `GET /user/memberships/orgs/{org}` to prove the caller administers the org |

`Administration: write` is **not** requested: it is needed to create
repositories and is only available for organization-owned repos, not personal
accounts — so the app links existing repositories instead (§10).

---

## 7. Self-hosting checklist

### 7.1 Bring up Supabase

Use the official self-host bundle (`docker compose` from
`supabase/supabase/docker`) or the hosted free plan. Required services: `db`,
`auth` (GoTrue), `rest` (PostgREST), `kong` (gateway), `functions` (Edge
Functions runtime, for `github-app`), `studio` (optional).

Environment you must set (names from the official `.env.example`):

```dotenv
POSTGRES_PASSWORD=<strong>
JWT_SECRET=<32+ chars>          # signs access tokens
ANON_KEY=<jwt with role=anon>   # or the newer sb_publishable_… key
SERVICE_ROLE_KEY=<jwt role=service_role>
SITE_URL=io.supabase.flutter://login-callback
ADDITIONAL_REDIRECT_URLS=io.supabase.flutter://login-callback
API_EXTERNAL_URL=https://<your-host>
GOTRUE_SITE_URL=${SITE_URL}
GOTRUE_EXTERNAL_GITHUB_ENABLED=true
GOTRUE_EXTERNAL_GITHUB_CLIENT_ID=<github oauth client id>
GOTRUE_EXTERNAL_GITHUB_SECRET=<github oauth client secret>
GOTRUE_EXTERNAL_GITHUB_REDIRECT_URI=https://<your-host>/auth/v1/callback
```

Generate the two JWTs with the `JWT_SECRET` (payload `{"role":"anon"}` /
`{"role":"service_role"}`, `exp` far in the future). The **publishable** key is
the only one that ships inside the app.

### 7.2 Apply the schema

`supabase/migrations/` must run in order — `0001_init.sql`, then
`0002_workspace_bootstrap.sql`, then `0003_github_app.sql`, then
`0004_roles_and_ownership.sql`, then
`0005_ownership_invariants.sql`, `0006_client_decisions.sql`, `0007_client_decision_rules.sql`, then `0008_invitations.sql`. Either:

```bash
supabase link --project-ref <ref>     # or --db-url for self-host
supabase db push
```

or paste all five files into the SQL editor, in order.

A database that was migrated halfway (tables present, functions/grants missing)
must be reset first — `create type` is not idempotent:

```sql
drop schema public cascade;
create schema public;
grant usage on schema public to anon, authenticated, service_role;
```

Then apply the files in order. All eight together produce 20 tables, 6 enums,
31 policies and 14 functions.

### 7.3 Deploy the GitHub App function

Fast path: fill in `scripts/github-app.local.json` (copy
`scripts/github-app.local.example.json`) and run

```powershell
.\scripts\setup-github-app.ps1            # add -DryRun to preview the commands
```

It stores the four secrets, deploys with `--no-verify-jwt` and probes the
endpoint. The equivalent manual steps:

1. Create the GitHub App (Settings → Developer settings → GitHub Apps → *New
   GitHub App*), owned by your personal account or by an organization:

   * **Homepage URL**: any real URL (e.g. `https://6dx.app`).
   * **User authorization callback URL**: add `https://<host>/functions/v1/github-app`.
     GitHub allows up to 10 callback URLs: **add** the function URL, never
     remove an existing one (e.g. `/auth/v1/callback` if Supabase Auth signs in
     with the same client). The function always passes `redirect_uri`, so GitHub
     picks the right one.
   * **Setup URL**: `https://<host>/functions/v1/github-app` (leave *Redirect on
     update* off).
   * **Webhook URL**: `https://<host>/functions/v1/github-app/webhook`
   * **Webhook secret**: the same random string you store as
     `GITHUB_WEBHOOK_SECRET`.
   * **Permissions**: Metadata `R`, Contents `R`, Issues `RW`, Pull requests `RW`;
     subscribe to the **Pull request** event.
   * **Where can this GitHub App be installed?**: either any account, or only
     yours while testing.

   > GitHub itself warns that `installation_id` on the setup URL can be spoofed.
   > The function therefore only accepts an installation *created after* the
   > signed `state` was issued (30-minute window), so nobody can attach somebody
   > else's installation — and therefore their repositories — to their workspace.

2. Store the secrets and deploy. The two GitHub-facing routes carry no Supabase
   JWT, so `--no-verify-jwt` is required — the function authenticates callers
   itself:

   ```bash
   supabase secrets set \
     GITHUB_APP_ID=<app id> \
     GITHUB_APP_SLUG=<app slug> \
     GITHUB_PRIVATE_KEY="$(cat app-private-key.pem)" \
     GITHUB_WEBHOOK_SECRET=<random 32+ chars> \
     GITHUB_CLIENT_ID=<App OAuth client id> \
     GITHUB_CLIENT_SECRET=<App OAuth client secret>

   supabase functions deploy github-app --no-verify-jwt
   ```

3. In the app: *ربط مستودع GitHub* → «تثبيت التطبيق على GitHub» → pick the
   repositories → «ثبّتته؟ حدّث الحالة».

### 7.4 Point the app at the new backend

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<your-host> \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<anon/publishable key> \
  --dart-define=SUPABASE_REDIRECT_URL=io.supabase.flutter://login-callback
```

Register the same scheme as redirect URL / Site URL on the new instance.

> The **OAuth App** used by Supabase for identity stays as it is — the GitHub
> App is a *separate* registration used only for repository access. Do not point
> the Supabase provider at the App's credentials: that would force every user to
> authorize again for no benefit (§6.3).

### 7.5 Verify

```bash
# functions exist (401/42501 = present, 404 PGRST202 = missing)
curl -s -X POST "https://<host>/rest/v1/rpc/ensure_my_workspace" \
  -H "apikey: <key>" -H "Authorization: Bearer <key>" \
  -H "Content-Type: application/json" -d '{}'

# columns exist (42501/[] = exists, 42703 = missing column)
curl -s "https://<host>/rest/v1/projects?select=icon&limit=1" \
  -H "apikey: <key>" -H "Authorization: Bearer <key>"

# the broker is deployed (401 unauthenticated = alive)
curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  "https://<host>/functions/v1/github-app" -d '{"action":"installation"}'
```

Then sign in inside the app and confirm the log shows
`Data: workspace.resolve → ok`, `Data: workspace.snapshot → ok`, and
`GitHubApp: opening the installation page` when linking a repository.

---

## 8. Observability

Every operation prints one always-on line (also in release builds):

```
[ACTION] LoginPage: tapped "continue with GitHub"
[ACTION] Auth: sign-in with GitHub: opening the browser, redirect io.supabase.flutter://login-callback
[ACTION] Auth: sign-in with GitHub: the deep link arrived
[ACTION] Data: workspace.resolve → ok (12ms)
[ACTION] Data: projects.list → FAILED [42501] permission denied for table projects
[ACTION] GitHubApp: opening the installation page
[ACTION] Workspace: snapshot loaded: 1 members, 0 PRs, 0 notifications
```

| Tag | Covers |
|---|---|
| `LoginPage`, `AuthSession` | taps, session restore |
| `Auth`, `DeviceFlow` | sign-in steps, polling, provider-token capture |
| `Data` | every Supabase query with label, duration, error code |
| `GitHub`, `GitHubApp` | GitHub operations through the `github-app` function (no token, no payload) |
| `Workspace`, `Projects`, `Tasks` | provider results |

Never logged: tokens, e-mails, personal data.

### Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| browser ends on `localhost:3000` | redirect not allow-listed and Site URL left at default | set Site URL / redirect URLs to the custom scheme |
| `42501 permission denied for table …` | grants not applied | run the grants block (end of `0001`) |
| `PGRST202 could not find the function` | functions missing | apply `0001` + `0002` |
| app waits ~2 min then "did not come back" | deep link never arrived | redirect URL + rebuild app (manifest changed) |
| repository picker empty | `no_installation` — the App is not installed | tap «تثبيت التطبيق على GitHub», then «حدّث الحالة» |
| `github_not_configured` | App secrets missing on the function | `supabase secrets set GITHUB_APP_ID=… GITHUB_APP_SLUG=… GITHUB_PRIVATE_KEY=… GITHUB_WEBHOOK_SECRET=…` |
| `github_error_401` from the function | App private key / App id mismatch | regenerate the key, update `GITHUB_PRIVATE_KEY` |
| install page returns “expired” | the `state` link is older than 30 min | start the install again from the app |
| snapshot loads but a screen is empty | payload key renamed / table empty | compare with §5.5 |

---

## 9. Security notes

* **Rotate the GitHub client secret.** An earlier commit (`ab5117a`) contained
  a GitHub OAuth client secret in `app_constants.dart`. It is gone from the
  code, but it is still in git history — revoke it in GitHub and update the
  secret in Supabase Auth.
* The app ships only the publishable/anon key. `service_role` and
  `sb_secret_…` must never reach a client.
* All seven helper functions are `SECURITY DEFINER`; keep `search_path` pinned and
  restrict `execute` to `authenticated` (as the migration does). The dashboard
  linter flags them — that is expected and required for RLS helpers.
* RLS is enabled on every table. If you add a table, enable RLS *and* write
  policies in the same migration, and add it to the grants block.
* Ownership is protected twice: policies (`members_update`/`members_delete` filter
  `role <> 'owner'`) plus a partial unique index
  (`workspace_members_single_owner_idx`). `workspaces.owner_id` is
  `on delete restrict`, so deleting the owner's account fails until
  `transfer_ownership()` has run.
* The RLS/role matrix is covered by pgTAP in `supabase/tests/` — run it on a
  local database (`supabase start && supabase test db`), never against
  production.
* Consider enabling Auth → Password Security (leaked password protection) if
  you ever enable e-mail sign-in.

---

## 10. Known gaps

| Area | State |
|---|---|
| E-mail/password sign-in + OTP | **implemented on Supabase** (`signInWithPassword` / `signUp` / `verifyOTP(signup)`). The confirmation e-mail must contain `{{ .Token }}` for the in-app 6-digit step — otherwise rely on the confirmation link. Needs working SMTP. |
| Snapshot sections without SQL | `workload`, `workload_suggestions`, `rate_limit`, `agents`, `commits`, `releases`, `code_platforms`, `project_reports`, `sprint_retros`, `billing` — the mapper accepts them, nothing produces them. |
| GitHub sync | `pull_request` webhooks upsert into `pull_requests`, but nothing imports issues, branches or commit history yet. |
| Creating a repository | not supported: a GitHub App token cannot create repositories on a personal account (`Administration` only covers organizations). The app links existing repositories. |
| One workspace per account | `ensure_my_workspace` and `CurrentWorkspace` use the first membership; the “switch workspace” screen exists in the design but is not wired. |
| Invites | implemented end to end (invite → notification → accept → membership). Nothing sends an **e-mail** yet, and the invite link is not shareable outside the app. |
| Realtime | not used; screens refresh manually. |
| `updated_at` | no trigger maintains it. |
