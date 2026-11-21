# 04 — مشاكل الـ Backend (Go)

**نتيجة التشغيل على commit `7c6a2d7`:**

```
go build ./...                    ✅
go vet ./...                      ✅
go test -tags=integration ./...   ✅  (internal/api و internal/auth)
```

مشاكل الحماية في [03-security.md](03-security.md). الملف ده عن **صحة المنطق** و**العقد بين التطبيق والسيرفر** و**الإعدادات**.

---

## 🔴 مساحة العمل (workspace)

### بعد قبول الدعوة المستخدم بيرجع لمساحة العمل بتاعته

- [x] [`lib/features/workspace/data/datasources/workspace_remote_data_source.dart:77`](../../lib/features/workspace/data/datasources/workspace_remote_data_source.dart#L77) بيعمل `reset()` وبعدها `resolve()`.
- `resolve()` بينادي `/v1/me` **من غير** `X-Workspace-Id`، والسيرفر في الحالة دي بيرجّع **أول عضوية** (`order by m.created_at limit 1`، [`workspace.go:93-101`](../../backend/internal/api/workspace.go#L93))، ودي مساحة العمل الخاصة بالمستخدم مش اللي انضم ليها لسه.
- ده بالظبط اللي التعليق في الكود بيقول إنه عايز يتجنبه.
- **الحل:** خلّي `CurrentWorkspace` عنده دالة عامة `activate(String id)` ونادِيها بـ `joined` بدل `reset()` + `resolve()`.

### تسجيل الخروج مش بيمسح مساحة العمل

- [x] `CurrentWorkspace._id` و `ApiClient.activeWorkspaceId` مش بيتمسحوا عند `signOut`.
- لو مستخدم تاني دخل على نفس الجهاز، هيتبعت `X-Workspace-Id` بتاع الأول، والسيرفر هيرد **403 `not_workspace_member`** على كل الطلبات لحد ما التطبيق يتقفل ويتفتح.
- **الحل:** في `AuthNotifier.signOut()` وبعد أي دخول جديد نادِ `ref.read(currentWorkspaceProvider).reset()` واعمل invalidate للـ providers بتاعة البيانات.
- [x] **(المراجعة التانية) الحل ده ناقص:** لازم كمان `githubSdk.reset()`، لأن توكن تثبيت GitHub المحفوظ هو اللي بيسرّب بيانات بين المستخدمين ([03-security.md](03-security.md) بند 13). أما `workspaceSnapshotProvider` فهو أصلًا بيعيد التحميل لما الحساب يتغير ([`workspace_providers.dart:60`](../../lib/features/workspace/presentation/providers/workspace_providers.dart#L60)).

### إنشاء مساحة العمل فيه race

- [ ] [`workspace.go:94-143`](../../backend/internal/api/workspace.go#L94): الـ bootstrap بيعمل check وبعدين insert **برا** الـ transaction، ومفيش أي unique على `owner_uid`. التطبيق بيبعت `/me` و `/snapshot` مع بعض في أول دخول، فالمستخدم ممكن يطلع عنده workspaceين "مساحة عملي"، وساعتها "أول عضوية" بتبقى عشوائية.
- **الحل:** حط الـ select جوه الـ transaction (`BEGIN IMMEDIATE`)، أو unique index على الـ workspace الشخصي.

---

## 🟠 اختلافات العقد بين التطبيق والسيرفر

دي بتكسر من غير أي خطأ ظاهر.

| المشكلة | السيرفر | التطبيق | النتيجة |
|---|---|---|---|
| لون الـ label | `"#9AA3B2"` (نص) — [`snapshot.go:516`](../../backend/internal/api/snapshot.go#L516) | `_int(json['color'])` — [`workspace_snapshot_mapper.dart:176`](../../lib/features/workspace/data/models/workspace_snapshot_mapper.dart#L176) | كل الـ labels رمادي |
| مفتاح المهمة `key` | `/v1/tasks` مش بيرجّعه (`scanTask` في [`tasks.go`](../../backend/internal/api/tasks.go)) | `Task.key` بيتعمل `PROJECTNAME-<uuid>` | مش بيطابق `issue_key` في الـ PR ولا عناصر الـ sprint |
| المسؤول عن المهمة | `/v1/tasks` مش بيرجّعه | بيظهر "—" دايمًا | ومكان "المراجِع" بيستخدم `assigneeName` غلط |
| `invite_id` في الإشعار | بيتبعت | الـ mapper بيرميه | قبول الدعوة من الإشعار بيقبل "أحدث دعوة" مش اللي المستخدم داس عليها |
| `decision_choice` | بيتبعت في `client_report` | بيترمي | القرار المسجّل بيظهر كأنه لسه معلّق |
| `dependencies[].task_id` | بيتبعت | بيترمي | الاعتماديات مش مربوطة بمهمة |
| `workload`، `workload_suggestions`، `rate_limit` | **مش بيتبعتوا** | الـ mapper بيقراهم | صفحة حجم الشغل فاضية دايمًا |
| أكواد الأخطاء | كود نصي + رسالة عربي (`admin_requires_owner`) | بيطابق أكواد Postgres (`42501`، `22023`، `P0002`) — [`member_pages.dart:259-263`](../../lib/features/members/presentation/pages/member_pages.dart#L259) و [`workspace_flow_pages.dart:105-111`](../../lib/features/workspace/presentation/pages/workspace_flow_pages.dart#L105) | رسالة عامة دايمًا ورسالة السيرفر بتضيع (بقايا من أيام Supabase) |

- [ ] **الحل طويل المدى:** اعمل ملف عقد واحد (OpenAPI مثلًا) وولّد منه الـ models في Dart والـ structs في Go، أو على الأقل اعمل integration test يتأكد إن الـ snapshot JSON بيتقري صح بالـ mapper.

---

## 🟠 منطق الصلاحيات والبيانات

- [ ] **الأدمن يقدر ينزّل أدمن تاني** — [`members.go:98-116`](../../backend/internal/api/members.go#L98). صف الـ owner بس محمي. الـ README بيقول الأدمن يدير developer/reviewer/viewer بس، و `handleRemoveMember` (سطر 159) بيشترط owner لحذف أدمن، يعني تغيير الدور مش متسق مع الحذف.
- [ ] **مهمة ممكن تتربط بمشروع في workspace تاني** — [`tasks.go:115-130`](../../backend/internal/api/tasks.go#L115).
  - `project_id` مش بيتشيّك إنه تابع لـ `ws.ID`، والـ foreign key بيشاور على `projects(id)` بس.
  - **النتيجة:** اسم مشروع B بيظهر لـ A، وعدّادات B بتزيد (`projects.go:25-26` مش مقيّد بالـ workspace). ولو B حذف المشروع، مهمة A بتتحذف بالـ cascade.
  - **الحل:** `select 1 from projects where id = ? and workspace_id = ?` قبل الـ insert/update.
- [ ] **PRs من repos مختلفة بتكتب فوق بعض:** الـ unique key `(workspace_id, number)` من غير عمود repo (الـ migration سطر 200، والـ webhook [`github.go:584`](../../backend/internal/api/github.go#L584)). PR #5 من repo X بيمسح PR #5 من repo Y.
  - **الحل:** ضيف `repository_full_name` للـ unique key (migration جديدة `0002_...sql`).
- [x] `open_tasks` للأعضاء بيعدّ مهام كل الـ workspaces (`members.go:25-26`، `snapshot.go:114`).
- [ ] `handleApproveTimeEntries` ([`tasks.go:269-294`](../../backend/internal/api/tasks.go#L269)) **مش بيعتمد حاجة**، بيعدّ بس entries المستخدم نفسه.
- [x] قرار العميل check-then-update برا transaction ([`decisions.go:57-82`](../../backend/internal/api/decisions.go#L57)): طلبين في نفس اللحظة ينجحوا الاتنين.
- [x] الـ webhook body محدود بـ 2MB ([`github.go:513`](../../backend/internal/api/github.go#L513)). payloads الـ PRs الكبيرة بتتقص، فالتوقيع يفشل والحدث يضيع. GitHub ممكن يبعت لحد 25MB.

### إضافات المراجعة التانية

- [x] **ربط تثبيت GitHub تاني بيفشل دايمًا** — [`github.go:372-381`](../../backend/internal/api/github.go#L372). الـ upsert بيعمل `on conflict (workspace_id, installation_id)`، بس الـ index اللي بيرفض فعلًا هو `github_installations_one_per_workspace_idx` (migration سطر 303). يعني أي workspace عنده تثبيت ويحاول يربط تثبيت تاني بياخد "تعذّر حفظ التثبيت" لحد ما حد يعمل disconnect. **الحل:** `on conflict (workspace_id) do update set installation_id = excluded.installation_id, ...`.
- [ ] **أحداث `installation` بتتجاهل** — [`github.go:526`](../../backend/internal/api/github.go#L526). لو الـ App اتشال أو اتعمله suspend، الصف بيفضل موجود، والـ UI بيقول "متصل"، وكل طلب توكن بيفشل. اعمل handle لـ `installation.deleted` و `suspend`.
- [ ] **الـ webhook مفيهوش dedupe ولا ترتيب** — [`github.go:579-592`](../../backend/internal/api/github.go#L579). مفيش تخزين لـ `X-GitHub-Delivery` ومفيش مقارنة بـ `pull_request.updated_at`، فأي delivery قديمة أو متعادة بترجّع PR متدمج لحالة مفتوح. خزّن الـ delivery ids واكتب بس لو `updated_at` أحدث.
- [ ] **الـ developer يقدر يعتمد الـ PR بتاعه** — [`tasks.go:228-265`](../../backend/internal/api/tasks.go#L228). أي editor يقدر يعمل approve، والـ handler بيكتب `approved` فوق حالة `merged`/`closed` اللي جاية من GitHub. **الحل:** اشترط دور reviewer (أو admin)، وامنع `author == caller`، واسمح بس لو `state = 'open'`.
- [ ] **مفيش إلغاء للدعوة** — [`members.go:175-307`](../../backend/internal/api/members.go#L175). مفيش `DELETE /v1/invites/{id}`، والدعوات بتفضل صالحة حتى بعد ما اللي دعا يتنزّل دوره أو يتشال. وتغيير الدور والحذف check-then-act برا transaction ([`members.go:58-173`](../../backend/internal/api/members.go#L58)).
- [ ] **`requireOwner` مش مستخدم** ([`authz.go:96`](../../backend/internal/api/authz.go#L96))، ومفيش endpoint لنقل الملكية، مع إن `members.go:66` بيشاور على `transferOwnership`.
- [ ] **ترتيب الوقت غلط:** `nowString()` بيستخدم `RFC3339Nano` ([`authz.go:158,162`](../../backend/internal/api/authz.go#L158)، [`db.go:138`](../../backend/internal/db/db.go#L138))، وده بيشيل الأصفار في الآخر، فمقارنة الـ strings مش بتبقى بالترتيب جوه نفس الثانية (`…:00.5Z` < `…:00Z`). ده بيأثر على انتهاء الدعوات وكل `order by created_at`. استخدم صيغة ثابتة الطول `2006-01-02T15:04:05.000000000Z`.
- [ ] **مستخدم Firebase قديم ممكن يتقفل برا** ([`authz.go:110-123`](../../backend/internal/api/authz.go#L110)): لو صفه `github_id` فيه NULL، الدخول بالـ device flow بيعمل uid جديد بنفس الإيميل، فيصطدم بـ `users_email_idx` وكل `/v1` بترجع 500. اعمل fallback للمطابقة بالإيميل المُوثّق.
- [ ] **مفيش حد لطول الحقول:** اسم ووصف المشروع، عنوان ووصف المهمة، `repository_full_name`، والإيميلات. حط max length لكل حقل.

### Migration `0002` المطلوبة

كل التعديلات دي لازم تبقى في ملف جديد، **ما تعدّلش `0001`**:

- [x] unique على `github_installations(installation_id)` ([03-security.md](03-security.md) بند 14).
- [ ] unique key للـ PRs يبقى `(workspace_id, repository_full_name, number)`.
- [ ] شيل `'owner'` من الـ CHECK بتاع `workspace_invites.role` (سطر 59).
- [ ] indexes ناقصة: `workspace_members(user_uid)`، `tasks(assignee_uid)` (بيتعمله scan لكل عضو علشان `open_tasks`)، `task_comments(task_id)`، `task_subtasks(task_id)`، `task_dependencies(task_id)`، `time_entries(workspace_id, user_uid)`، `notifications(workspace_id)`.
- [ ] جدول `github_deliveries` للـ dedupe، وسياسة تنضيف لـ `activity_events` (مش بيتمسح أبدًا).

---

## 🟡 الإعدادات

- [x] **`GITHUB_CLIENT_ID` متكرر في [`.env.example`](../../backend/.env.example)** (سطر 37 وسطر 46).
  - `loadDotEnv` ([`config.go:145-148`](../../backend/internal/config/config.go#L145)) بيعمل `Setenv` لأول قيمة (الفاضية)، والتانية بتتخطى لأن `LookupEnv` بيلاقيها موجودة.
  - **النتيجة:** لو ملّيت قسم الـ GitHub App بس، الـ client id هيفضل فاضي والـ device flow والـ broker الاتنين هيقفوا.
  - **الحل:** احذف السطر المكرر، وخلّي `loadDotEnv` يتخطى القيم الفاضية أو آخر قيمة هي اللي تكسب.
- [x] `FIREBASE_CREDENTIALS_FILE` في `.env.example` بيشاور على ملف. لو مش موجود `Load` بيقفل السيرفر، مع إن Firebase مكتوب إنه اختياري. خلّيه فاضي في المثال.
- [ ] `GitHubStateTTL` في [`config.go:74`](../../backend/internal/config/config.go#L74) إعداد ميت: الكود بيستخدم الثابت `stateTTL`.
- [ ] Firebase Admin SDK (`firebase.google.com/go/v4`) لسه في `go.mod` علشان "الجلسات القديمة" بس. ده بيجيب dependencies تقيلة كتير (grpc، opentelemetry، google auth). حدّد تاريخ وشيله.

---

## ✅ حاجات معمولة صح

- SQLite بالـ pragmas الصح (`foreign_keys`، `WAL`، `busy_timeout`) — [`db.go:30-56`](../../backend/internal/db/db.go#L30).
- إنشاء الـ workspace + الـ owner جوه transaction.
- قاعدة "owner واحد" محمية بـ partial unique index، وصف الـ owner مش بيتعدّل ولا يتحذف.
- `X-Workspace-Id` دايمًا بيتشيّك على العضوية.
- كل UPDATE/DELETE فيه `workspace_id` في الـ WHERE.
- `MaxBytesReader` (1MB) على الـ JSON bodies (ما عدا `/auth/github/device-token`، شوف [03-security.md](03-security.md) بند 17)، و graceful shutdown.
- Integration tests بتعمل SQLite مؤقت، فمحتاجة صفر إعداد.
