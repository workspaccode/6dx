# 6DX

منصة إدارة مشاريع ومهام (موبايل + ويب) — تطبيق Flutter مبني بـ **Clean Architecture**،
ومزوّد بـ Riverpod و Dio و GoRouter و AutoRoute و Freezed و Retrofit و
Awesome Notifications وتوطين عبر `flutter gen-l10n`.

The design source of truth is `6DX-all-screens.html` (92 mobile + 51 web screens).
The Flutter app currently implements the core mobile flow: onboarding → auth →
projects → task board → task detail → notifications → profile.

📘 **Backend / self-hosting:** [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md) — full
schema, RLS policies, RPC contracts, auth flows and a step-by-step
self-hosted Supabase setup.

## Tech stack

| Concern            | Package                                                        |
|--------------------|----------------------------------------------------------------|
| State management   | `flutter_riverpod` 3.x (Notifier / AsyncNotifier + providers)    |
| Networking         | `dio` 5.x + `retrofit` 4.x, custom retry & auth interceptors   |
| Routing            | `go_router` 18 (app shell, guards, stateful bottom nav) + `auto_route` 11 (typed route table) |
| Models             | `freezed` 4 + `json_serializable`                              |
| Notifications      | `awesome_notifications` 0.12                                   |
| Localization       | `flutter_gen` / `flutter gen-l10n` (`lib/l10n`)                 |
| Codegen            | `build_runner`                                                 |
| Storage            | `flutter_secure_storage` (tokens) + `shared_preferences` (prefs) |

## Getting started

```bash
flutter pub get
flutter gen-l10n                 # regenerate lib/l10n/generated
dart run build_runner build      # freezed / json / retrofit / auto_route
flutter run
```

Useful flags:

```bash
flutter run --dart-define=SUPABASE_URL=https://<project>.supabase.co \
            --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key> \
            --dart-define=GITHUB_CLIENT_ID=<oauth app client id>
```

## No fake data, ever

The app ships **no sample content**. Every screen renders exactly one of:

1. the data the signed-in member is allowed to read (RLS decides), or
2. an honest empty state (`AppEmptyState`) — a new account starts with an
   empty workspace, no projects and no tasks.

There is no mock/demo mode and no fallback catalogue: a failing query surfaces
as an empty snapshot with the reason kept in `workspaceErrorProvider`, so the
UI never shows invented records. `test/no_fake_data_test.dart` guards that
contract.

## Architecture

```
lib/
├── app/                 # composition root (SixDxApp + global providers)
├── core/
│   ├── config/          # AppConfig (Supabase URL/key, redirect URL)
│   ├── constants/       # colors, constants, endpoints
│   ├── errors/          # Failure (sealed) + exceptions
│   ├── extensions/      # BuildContext.l10n
│   ├── network/         # Supabase client, current workspace, Dio interceptors
│   ├── notifications/   # awesome_notifications wrapper
│   ├── storage/         # secure + local storage
│   ├── theme/           # dark/light theme from the 6DX design tokens
│   ├── utils/           # Result<T>, logger
│   └── l10n/            # ARB files + generated localizations
├── features/<feature>/
│   ├── domain/          # entities, repository contracts, use cases
│   ├── data/            # models, data sources, repository implementations
│   └── presentation/    # pages, providers (Riverpod), widgets
├── features/workspace/  # one aggregated workspace projection
│   ├── domain/          # WorkspaceSnapshot + all sub-entities
│   ├── data/            # API data source + JSON mapper
│   └── presentation/    # providers used by every secondary screen
├── routes/              # go_router (AppRoutes) + auto_route typed table
└── shared/widgets/      # reusable UI (logo, badges, empty/error states)
```

### Patterns used

* **Clean architecture** — `domain` has no Flutter/Dio dependency; `data`
  implements the domain contracts; `presentation` only talks to use cases
  exposed as Riverpod providers.
* **Repository + Use case** — every write goes through a use case object.
* **`Result<T>`** — repositories never throw; they return
  `Success`/`FailureResult`, so the UI can render errors declaratively.
* **Repository pattern with a local cache** — projects/tasks keep an in-memory
  cache so the UI is instantly usable offline.
* **Riverpod providers as DI container** — `auth_providers.dart` wires the
  data sources into repositories, repositories into use cases.
* **Guard/redirect based routing** — `go_router` redirects to `/login` when the
  session is missing and to `/home` after a successful sign-in.
* **Typed routes (AutoRoute)** — every screen is annotated with `@RoutePage()`
  and listed in `AppRouterConfig`; the generated
  `auto_router_config.gr.dart` gives compile-time-safe route arguments.
* **Either/or pattern with Freezed unions** — `TaskStatus`, `TaskPriority`,
  `Failure` and `Result` are sealed and exhaustively matched with `switch`.

## Screen coverage (honest numbers)

The design export contains **92 mobile screens** and **51 web screens** (143
total). The Flutter app now implements:

| Set | Designed | Implemented |
|---|---|---|
| Mobile | 92 | **92** |
| Web | 51 | **51** (as `/web/...` routes) |

Every screen is data-driven and shows an honest empty state when the API has
nothing yet — no invented content (see “No fake data in a normal build”).

### Mobile screens (92)

| Area | Screens |
|---|---|
| الدخول والتسجيل | `LoginPage`, `SignUpPage`, `VerifyOtpPage`, `OnboardingPage`, `SetupChecklistPage`, `PushPermissionPage` |
| الحساب ومساحات العمل | `ProfilePage`, `AccountSettingsPage`, `WorkspaceCreatePage`, `WorkspaceSwitchPage`, `RegionalCalendarPage`, `NotifSettingsPage`, `FocusModePage`, `HelpPage`, `BillingPage`, `ExportDataPage` |
| المشاريع والربط بـ GitHub | `ProjectsPage`, `EmptyProjectsPage`, `CreateProjectPage`, `ConnectRepositoryPage`, `ProjectSettingsPage`, `SyncSettingsPage`, `LabelsPage`, `IntegrationsPage`, `ActivityLogPage`, `ArchivePage`, `GhAppInstallPage`, `GhInstallingPage`, `ImportIssuesPage`, `MapContributorsPage`, `MultiProviderPage` |
| الدعوات والأعضاء | `MembersPage`, `InvitePage`, `BulkInvitePage`, `AcceptInvitePage`, `LinkGitHubPage`, `InviteExpiredPage`, `JoinRequestsPage` |
| المهام: العرض والتنظيم | `TaskBoardPage`, `TaskListPage`, `TaskCalendarPage`, `TaskSearchPage`, `MyTasksPage`, `ReviewsPage`, `BulkActionsPage` |
| المهمة الواحدة | `NewTaskPage`, `EditTaskPage`, `TaskDetailPage`, `StatusSheetPage`, `SubtasksPage`, `CommentsPage`, `DependenciesPage`, `TaskContextPage`, `BugReportPage` |
| الـ Sprints والتخطيط | `BacklogPage`, `SprintPlanPage`, `SprintSummaryPage`, `SprintHistoryPage`, `EstimateLearningPage` |
| المراجعة وGitHub والإصدارات | `PrDetailPage`, `CiFailurePage`, `ReviewSlaPage`, `ReviewerPickPage`, `BigPrWarningPage`, `MergeFromAppPage`, `CommitsPage`, `ReleaseTrackerPage` |
| الإشعارات والتركيز | `NotificationsPage`, `RichNotificationPage`, `DigestPage` |
| الفريق والـ AI Agents والمعرفة | `WorkloadPage`, `AgentsTeamPage`, `AssignAgentPage`, `KnowledgeMapPage`, `AskProjectPage`, `ProjectReportPage` |
| العملاء والوكالات | `ClientPortalPage`, `WeeklyClientSummaryPage`, `TimeTrackingPage`, `InvoicePage` |
| الحالات والأخطاء | `SkeletonPage`, `OfflinePage`, `SyncFailedPage`, `AccessRevokedPage`, `NoPermissionPage`, `NotFoundPage` |

### Web screens (51)

`lib/features/web/` ships the public website and the web app as a responsive
shell (sidebar on wide screens, top bar on narrow ones, always LTR). The 51
design screens are registered in `web_routes.dart` and served under `/web/...`.

## Authentication: Supabase

The app signs users in with **GitHub**. Two interchangeable backends sit behind
one interface (`features/auth/data/backends/auth_backend.dart`):

| Backend | When it is used | Notes |
|---|---|---|
| `SupabaseAuthBackend` | `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` are set (default choice) | GitHub OAuth with PKCE. **No GitHub client secret ever ships in the app** — Supabase performs the code exchange server side. The session (access token + refresh) is managed by Supabase and mirrored into the secure storage so the API layer can send `Authorization: Bearer …`. |
| `DeviceFlowAuthBackend` | Supabase is not configured | GitHub OAuth *device flow*: the app shows a short code, the user confirms it on github.com, the app polls until the grant is approved. |

Both backends implement the same contract, so the UI never knows which one is
active.

### 1. Supabase project

Create a project and add **GitHub** as an auth provider
(Authentication → Providers → GitHub). You need your own GitHub OAuth app:
*Authorization URL* `https://<project-ref>.supabase.co/auth/v1/authorize`,
*Callback URL* `https://<project-ref>.supabase.co/auth/v1/callback`.

### 2. Redirect URL

Add the callback that the app receives to
*Authentication → URL Configuration → Redirect URLs*:

```
io.supabase.flutter://login-callback
```

The scheme is already registered for Android (`AndroidManifest.xml` intent
filter) and iOS (`Info.plist` → `CFBundleURLTypes`).

### 3. Run the app

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>
```

The publishable key is safe to ship in the app; never put the service-role key
in the client.

### Database

`supabase/migrations/` contains the whole 6DX schema:

* `0001_init.sql` — tables, RLS policies, `get_workspace_snapshot()` and the
  API privileges:

  * `workspaces`, `workspace_members`, `workspace_invites`
  * `projects`, `repositories`, `project_labels`, `integrations`
  * `sprints`, `sprint_items`, `tasks`, `task_comments`, `task_subtasks`,
    `task_dependencies`, `pull_requests`
  * `notifications`, `activity_events`, `digest_entries`, `client_reports`,
    `time_entries`
  * row level security on every table, scoped by `is_workspace_member()`
  * `get_workspace_snapshot(workspace_id)` — a `jsonb` function that returns
    the exact payload the Flutter app expects (the same shape as
    `WorkspaceSnapshot` in `features/workspace/domain/entities`)
  * the grants PostgREST needs (`select/insert/update/delete` for the
    `authenticated` role) — without them every query answers `42501`

* `0002_workspace_bootstrap.sql` — `ensure_my_workspace()`, which creates the
  first workspace for a new account, because RLS has no insert policy on
  `workspaces` (a member has to exist first)

Apply them with the Supabase MCP (`execute_sql`) or the CLI:

```bash
supabase link --project-ref ifrpswaclrrsshspdmzd
supabase db push
```

A project whose tables exist but whose functions and grants are missing was
migrated half way. Start from a clean schema, then push:

```sql
drop schema public cascade;
create schema public;
grant usage on schema public to anon, authenticated, service_role;
```

The app reads and writes every screen through Supabase, under the member's own
JWT (so RLS applies):

| Screen | Query |
|--------|-------|
| workspace projection | `rpc get_workspace_snapshot` |
| projects | `projects` + embedded `repositories` / `tasks(status)` |
| tasks | `tasks` + embedded `projects(name)` |
| workspace id | first `workspace_members` row, else `rpc ensure_my_workspace` |

### Limits of the free plan

The free plan is comfortable for an early release: 50,000 monthly active
users in Auth, 500 MB of database, 1 GB of file storage and 5 GB of egress.
GitHub sign-ins count towards the MAU limit, so the only number to watch is
the number of *active* users per month — not the number of registered
accounts.

## GitHub authentication

Two backends live behind `AuthBackend`; the app picks one at start-up:

| Backend | Used when | Flow |
|---------|-----------|------|
| `SupabaseAuthBackend` | `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` are set (the default) | browser OAuth, the session comes back through the `io.supabase.flutter://login-callback` deep link |
| `DeviceFlowAuthBackend` | Supabase is not configured | GitHub OAuth **device flow**, no redirect URI and no secret |

The GitHub OAuth **client secret** must live only in the Supabase dashboard
(Authentication → Providers → GitHub). It is never read by the app.

### Supabase (default)

1. `signInWithOAuth(OAuthProvider.github, redirectTo: SUPABASE_REDIRECT_URL)`
   opens github.com in the browser.
2. GitHub redirects to the Supabase callback, which exchanges the code and
   sends the session to the app with the custom scheme.
3. `supabase_flutter` handles the deep link (`detectSessionInUri: true`) and
   emits `AuthChangeEvent.signedIn`; `SupabaseAuthBackend` waits for that
   event.

Both URLs have to be registered in the Supabase dashboard:

* Authentication → URL Configuration → Redirect URLs:
  `io.supabase.flutter://login-callback`
* `android/app/src/main/AndroidManifest.xml` already declares the
  `io.supabase.flutter://login-callback` intent filter, and `ios/Runner/Info.plist`
  the matching URL scheme.

### Device flow (fallback)

Used when Supabase is not configured — e.g. a local build with
`--dart-define=SUPABASE_URL=`. The app only needs a client **id**:

1. `POST https://github.com/login/device/code` → user code + verification URI
   (parameters are form-encoded, a query string answers `404`).
2. The user confirms the code on github.com.
3. The app polls `POST https://github.com/login/oauth/access_token` until the
   token is issued (honouring `authorization_pending` and `slow_down`), then
   loads `/user` and `/user/emails`.

**Device Flow has to be enabled** on the GitHub OAuth app
(github.com/settings/developers → the app → *Enable Device Flow*); otherwise
GitHub answers `400 device_flow_disabled` and the login screen shows that
hint. The client id is read from `--dart-define=GITHUB_CLIENT_ID=...`
(default `Ov23liw4p0LMObMu8l9b`).

The token is stored with `flutter_secure_storage` and attached to every API
call by `AuthInterceptor`.

## Repository access (GitHub App)

Login only asks for the profile (`read:user user:email`). Reading a user's
repositories uses a **GitHub App** installed on the repositories the user (or
the org admin) picks, so the app never receives a credential for the whole
account — unlike an OAuth app with the `repo` scope.

* Broker: `supabase/functions/github-app` holds the App private key and mints a
  one-hour installation token per request. The client never talks to
  `api.github.com` and stores no GitHub token.
* Flow: *ربط مستودع GitHub* → «تثبيت التطبيق على GitHub» → choose repositories
  → «ثبّتته؟ حدّث الحالة».
* Webhooks (`pull_request`) are verified with `x-hub-signature-256` and upsert
  into `pull_requests`.
* Deploy: fill in `scripts/github-app.local.json` (copy the `.example`) and run
  `.\scripts\setup-github-app.ps1` — it stores the secrets and deploys with
  `--no-verify-jwt` (the function authenticates callers itself; GitHub's setup
  redirect and webhook carry no JWT). The manual equivalent is
  `supabase functions deploy github-app --no-verify-jwt`.

See [SYSTEM_DESIGN.md](./SYSTEM_DESIGN.md) §6.3 and §7.3 for the permissions,
secrets and self-hosting steps.

### Reading the log when something fails

Every operation prints one always-on line (`AppLogger.action` — it is *not*
stripped in release builds), so a tester log shows exactly which step broke:

```
[ACTION] LoginPage: tapped "continue with GitHub"
[ACTION] Auth: sign-in with GitHub: opening the browser, redirect io.supabase.flutter://login-callback
[ACTION] Auth: sign-in with GitHub: the deep link arrived
[ACTION] Data: workspace.resolve → ok (12ms)
[ACTION] Data: workspace.snapshot → FAILED [42501] permission denied for table projects
[ACTION] Workspace: snapshot FAILED ...
[ACTION] Projects: load → FAILED: لا توجد صلاحيات على قاعدة البيانات …
```

| Tag | Covers |
|-----|--------|
| `LoginPage`, `AuthSession` | what the user tapped, session restore |
| `Auth`, `DeviceFlow` | sign-in steps, device-code polling, provider token capture |
| `Data` | every Supabase query — `label → ok (Nms)` or `FAILED [code] message` |
| `GitHub` | every GitHub API request, its status and item count (never the token) |
| `Workspace`, `Projects`, `Tasks` | provider-level results and failures |

No token, e-mail or personal data is ever printed.


## Notifications

`NotificationService` wraps `awesome_notifications`:

* channel `sixdx_channel` with the 6DX accent color,
* permission request helper,
* `show()` for instant notifications and `schedule()` for calendar schedules,
* action/display listeners.

Android permissions (`POST_NOTIFICATIONS`, `VIBRATE`, `SCHEDULE_EXACT_ALARM`)
are already declared in `android/app/src/main/AndroidManifest.xml`, and iOS
background modes are set in `ios/Runner/Info.plist`.

## Localization

`lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb` are compiled by
`flutter gen-l10n` into `lib/l10n/generated/`. The app ships English and
Arabic; the Arabic locale renders RTL automatically. Use
`context.l10n.someKey` inside widgets.

## Generated code

The `build_runner` output (`*.freezed.dart`, `*.g.dart`, `*.gr.dart`) and the
`flutter gen-l10n` output (`lib/l10n/generated/`) are **committed** so a fresh
clone builds without running the generators. Re-run them after changing a
model, a route or an ARB file.

## Tests

```bash
flutter analyze
flutter test
```

## Design tokens

Taken from the design export (`6DX-all-screens.html`):

| Token         | Value     |
|---------------|-----------|
| background    | `#0F1115` |
| surface       | `#171A21` |
| surface alt   | `#1F232C` |
| border        | `#2A2F3A` |
| text          | `#E8EAF0` |
| text muted    | `#9AA3B2` |
| accent        | `#B8F25A` |
| success       | `#7EE2A8` |
| warning       | `#F5B54A` |
| danger        | `#FF9A7F` |
| info          | `#8FB8FF` |

Fonts: IBM Plex Sans Arabic (UI) and JetBrains Mono (keys, chips, counters).
