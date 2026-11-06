# 6DX — System Design (Firebase)

هذا المستند يحل محل نسخة Supabase السابقة. القرار المعماري: **Firebase
Auth + Firestore + Cloud Functions** بدل Postgres/RLS، والقرار متخذ
لتبسيط التشغيل. الهدف هنا أن يبقى نفس المستوى الأمني — كل سياسة من
السياسات الثلاث والثلاثين موجودة ومترجمة أدناه.

## 1. المعمارية

```
Flutter (Riverpod)
  │  firebase_auth      ← تسجيل الدخول (GitHub / بريد)
  │  cloud_firestore    ← القراءة والكتابة تحت قواعد firestore.rules
  │  cloud_functions    ← الأوامر الحساسة (callables)
  ▼
Firebase
  ├── Auth
  ├── Firestore + security rules
  └── Cloud Functions (Admin SDK) ──► GitHub API (GitHub App)
```

## 2. الأمان — ترجمة RLS

| سياسة Postgres الأصلية | المكافئ في Firebase | ملاحظات |
|---|---|---|
| `is_workspace_member` | `exists(memberDoc(ws))` في القواعد | نفس الفحص، lazy `&&` |
| `is_workspace_admin` | `role(ws) in ['owner','admin']` | |
| `is_workspace_owner` | `role(ws) == 'owner'` | |
| `is_workspace_editor` (0004) | `role(ws) != 'viewer'` | viewer للقراءة فقط |
| projects/tasks/sprints/labels/repositories/integrations write | `isEditor` | |
| members insert/update/delete (طبقي 0001) | قواعد على /members | لا يمكن منح `owner` بالكتابة المباشرة |
| workspaces update (admin) / delete (owner) | قواعد على /workspaces | الإنشاء عبر callable فقط |
| notifications (user_id = auth.uid) | `/users/{uid}/notifications` | الإنشاء من callables فقط |
| activity insert (actor = caller) | `request.resource.data.actorId == request.auth.uid` | |
| client_reports read (member) | `/clientReport/report` read member | الكتابة من callable |
| pull_requests (member + webhook) | read member / update editor محدود | الإنشاء من webhook فقط |
| time_entries read (own) | `/users/{uid}/timeEntries` | |
| digest (own + member) | `/users/{uid}/digest` | |
| invitations (trigger + accept) | `sendInvites`/`acceptInvite` callables | idempotent عبر id = `<wsId>_<inviteId>` |
| unique owner (0005) | `transferOwnership` transaction | مضمون بالبناء |
| one client report (0007) | doc واحد `clientReport/report` | |
| submit_client_decision rules (0007) | `submitClientDecision` | تحقق index + مرة واحدة |

### ما لا تستطيع القواعد فعله (ولذلك موجود كـ callable)

- إنشاء مساحة مع عضوية مالكها في خطوة واحدة → `ensureMyWorkspace`
- قبول دعوة (لا يمكن للعميل إضافة نفسه عضواً) → `acceptInvite`
- إشعار المدعو عند إنشاء الدعوة → داخل `sendInvites`
- نقل الملكية ذرياً → `transferOwnership`
- قرار العميل لـ viewer → `submitClientDecision`
- كل ربط GitHub App → `githubApp` / `githubAction`

## 3. تدفق GitHub App (كما هو من المراجعات الثلاثة)

```
Leg 1: التطبيق → githubAction(install-url) → رابط installations/new?state=<v1 موقّع>
Leg 2: GitHub → GET githubApp?installation_id&state → 302 → /login/oauth/authorize
        (لو state ضاع → توكن استرداد r1 موقّع يحمل installation_id فقط)
Leg 3: GitHub → GET githubApp?code&state → exchange → /user → identity binding
        → ownership (شخصي أو org admin) → حفظ → إلغاء توكن المستخدم
Webhook: POST githubApp/webhook → HMAC على الـ raw body → upsert pullRequests
```

فشل مغلق (fail-closed) في كل خطوة. `identityMatches` يتحقق أن حساب GitHub
مربوط بنفس حساب Firebase (`auth.getUserByProviderUid('github.com', id)`).

## 4. الـ snapshot

كان `get_workspace_snapshot()` SQL واحداً؛ في Firestore تُجمع نفس الحمولة
من قراءات متوازية (members, invites, tasks + subcollections, activity,
sprints + items, pullRequests, labels, integrations, repositories,
notifications, digest, clientReport) — **نفس شكل الـ JSON**، فلم تتغير
`WorkspaceSnapshotMapper` ولا الشاشات.

## 5. ما تغير في التطبيق

- `firebase_client.dart` بدل `supabase_client.dart` — نفس `runX(label, …)`
  والرسائل العربية.
- التسجيل بالبريد يدخل مباشرة (بلا OTP — لم يعد موجوداً في Firebase).
- `users/{uid}` يحمل الـ profile العام (displayName/email/photoURL) لأن
  Firestore لا يملك auth directory قابل للقراءة.

## 6. القرارات المفتوحة

- **CI للقواعد**: التحقق يحتاج اعتماد Firebase، فالـ CI يفحص `tsc` و`flutter` فقط.
- **حذف مشروع Supabase**: آخر خطوة بعد التحقق من Firebase — الترتيب المتفق عليه.
- **pgTAP**: اختبارات Postgres لم تعد صالحة؛ لم تكتب بدائل بعد (rules unit
  tests عبر emulator ممكنة كخطوة تالية).
