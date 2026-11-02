# 6DX

منصة إدارة مشاريع ومهام (موبايل + ويب) — تطبيق Flutter مبني بـ **Clean Architecture**،
ومزوّد بـ Riverpod و Dio و GoRouter و AutoRoute و Freezed و Retrofit و
Awesome Notifications وتوطين عبر `flutter gen-l10n`.

The design source of truth is `6DX-all-screens.html` (92 mobile + 51 web screens).
The Flutter app currently implements the core mobile flow: onboarding → auth →
projects → task board → task detail → notifications → profile.

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
flutter run --dart-define=API_BASE_URL=https://api.example.com
flutter run --dart-define=GITHUB_CLIENT_ID=xxxx --dart-define=GITHUB_CLIENT_SECRET=yyyy
flutter run --dart-define=USE_MOCK=true           # demo catalogue (see below)
```

## No fake data in a normal build

The app **never invents workspace content**. `USE_MOCK` defaults to `false`,
so every screen renders exactly one of:

1. the API response,
2. an honest empty state (`AppEmptyState`), or
3. an error state (the workspace provider resolves to an empty snapshot and
   exposes the reason through `workspaceErrorProvider`).

All sample content lives in a single file — `lib/core/demo/demo_data.dart` —
and is only reachable with `--dart-define=USE_MOCK=true`. When demo mode is
on, a banner («بيانات تجريبية») appears on the main screens so the sample
content is never mistaken for real data. The demo catalogue is consumed
through the same repository/provider path as the real API, so nothing in the
UI layer is aware of the difference.

A regression test (`test/no_fake_data_test.dart`) asserts that the default
build serves an empty workspace instead of the demo records.

## Architecture

```
lib/
├── app/                 # composition root (SixDxApp + global providers)
├── core/
│   ├── config/          # AppConfig (mock mode, endpoints)
│   ├── demo/            # the demo catalogue + "demo data" banner
│   ├── constants/       # colors, constants, endpoints
│   ├── errors/          # Failure (sealed) + exceptions
│   ├── extensions/      # BuildContext.l10n
│   ├── network/         # Dio factory, auth interceptor, retry interceptor
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

The design export contains **92 mobile screens** and **51 web screens** (143 total).
This Flutter app implements **44 mobile screens** (~48 % of the mobile set);
**the 51 web screens are not implemented** — this repository is the mobile app.

### Implemented (44)

| Area | Screens |
|---|---|
| الدخول والتسجيل | `LoginPage`, `SignUpPage`, `VerifyOtpPage`, `OnboardingPage`, `SetupChecklistPage` |
| الحساب ومساحات العمل | `ProfilePage`, `AccountSettingsPage`, `WorkspaceCreatePage`, `NotifSettingsPage`, `FocusModePage`, `HelpPage` |
| المشاريع والربط بـ GitHub | `ProjectsPage`, `CreateProjectPage`, `ConnectRepositoryPage`, `ProjectSettingsPage`, `SyncSettingsPage`, `LabelsPage`, `IntegrationsPage`, `ActivityLogPage`, `ArchivePage` |
| الدعوات والأعضاء | `MembersPage`, `InvitePage` |
| المهام: العرض والتنظيم | `TaskBoardPage` (Kanban), `TaskListPage`, `TaskCalendarPage`, `TaskSearchPage`, `MyTasksPage`, `ReviewsPage` |
| المهمة الواحدة | `NewTaskPage`, `TaskDetailPage`, `SubtasksPage`, `CommentsPage` |
| الـ Sprints والتخطيط | `BacklogPage`, `SprintPlanPage`, `SprintSummaryPage` |
| المراجعة وGitHub | `PrDetailPage`, `CiFailurePage`, `ReviewSlaPage` |
| الإشعارات | `NotificationsPage` |
| الفريق والعمل | `WorkloadPage`, `DigestPage` |
| العملاء والوكالات | `ClientPortalPage`, `InvoicePage`, `TimeTrackingPage` |

### Not implemented yet (48 mobile + 51 web)

Workspace switching · GitHub App install · issue import · contributor mapping ·
multi-provider · invite acceptance/expiry/bulk · join requests · task editing ·
status sheet · dependencies · task context · bug report · sprint history ·
estimate learning · reviewer picker · big-PR warning · merge-from-app ·
commits · release tracker · rich notifications · home-screen widget ·
agents team · agent assignment · knowledge map · ask-project · project report ·
weekly summary · billing/invoices settings · export data · regional calendar ·
all empty/error/offline states (offline, sync-failed, access-revoked,
no-permission, not-found, skeleton) · English-LTR and light-mode showcase ·
components gallery · **and the 51 web screens**.

## GitHub authentication

`GithubAuthDataSource` implements the GitHub **OAuth device flow**, so no
redirect URI / browser callback is required on mobile, desktop or web:

1. `POST https://github.com/login/device/code` → user code + verification URI.
2. The user confirms the code on GitHub.
3. The app polls `POST https://github.com/login/oauth/access_token` until the
   token is issued, then loads `/user` and `/user/emails`.

The token is stored with `flutter_secure_storage` and attached to every API
call by `AuthInterceptor`.

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
