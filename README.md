# 6DX

6DX — تطبيق إدارة مشاريع (Flutter) يعمل على موبايل وويب. المصادقة والبيانات
على **Firebase**: Firebase Auth لتسجيل الدخول (GitHub + البريد) وFirestore
للبيانات وCloud Functions للأوامر الحساسة.

> اللغة العربية هي لغة الواجهة الافتراضية (RTL). الكود والتعليقات بالإنجليزية.

## البنية

```
lib/
├── core/
│   ├── config/          # AppConfig (اختيار الـ backend)
│   ├── network/          # firebase_client (Firestore/Functions + أخطاء عربية)
│   │                    # current_workspace (حل/إنشاء مساحة العمل)
│   ├── errors/          # ServerException / UnauthorizedException
│   └── storage/          # secure storage + local storage
├── features/
│   ├── auth/             # تسجيل الدخول (Firebase Auth / device flow fallback)
│   ├── workspace/        # المساحة + الدعوات + قرارات العميل
│   ├── projects/         # المشاريع
│   ├── tasks/            # المهام
│   ├── github/           # ربط GitHub App
│   ├── members/          # الأعضاء والأدوار
│   └── notifications/    # الإشعارات
├── firebase_options.dart # مولّد بـ flutterfire configure
└── main.dart

functions/                # Cloud Functions (TypeScript)
├── src/admin.ts          # تهيئة Admin SDK + فحوصات العضوية
├── src/workspace.ts      # ensureMyWorkspace / transferOwnership
├── src/invites.ts        # sendInvites / acceptInvite / syncMyInvites
├── src/decisions.ts      # submitClientDecision
├── src/github.ts         # وسيط GitHub App (الأرجل الثلاثة + webhook)
└── src/githubActions.ts  # أوامر التطبيق (installation/repositories/...)

firestore.rules           # قواعد الأمان — ترجمة سياسات RLS القديمة
firestore.indexes.json    # فهارس الاستعلامات
firebase.json
```

## التشغيل

```bash
flutter pub get
dart run flutterfire configure   # يولّد lib/firebase_options.dart
flutter run
```

المتغيرات عبر `--dart-define`:

| المتغير | الافتراضي | المعنى |
|---|---|---|
| `USE_DEVICE_FLOW` | `false` | `true` = تجاهل Firebase واستخدم GitHub device flow (نسخة اختبار بلا مشروع) |

## المصادقة

| الـ backend | متى يُستخدم | ماذا يفعل |
|---|---|---|
| `FirebaseAuthBackend` | افتراضي | GitHub عبر المتصفح + بريد/كلمة سر. التسجيل يوقّع الدخول فوراً (لا يوجد كود تأكيد). |
| `DeviceFlowAuthBackend` | `--dart-define=USE_DEVICE_FLOW=true` | GitHub device flow فقط — بلا قاعدة بيانات. |

توقيع GitHub بلا أي `client secret` في التطبيق، والصلاحيات المطلوبة
`read:user user:email` فقط. الوصول للمستودعات عبر GitHub App منفصل تماماً.

## البيانات (Firestore)

```
workspaces/{wsId}
  ├── members/{uid}            # role: owner|admin|developer|reviewer|viewer
  ├── invites/{inviteId}        # email, role, status, invitedBy, expiresAt
  ├── projects/{pId}
  │     ├── repositories/{rId}
  │     └── labels/{lId}
  ├── sprints/{sId}/items/{taskId}
  ├── tasks/{tId}
  │     ├── comments/{cId}
  │     ├── subtasks/{sId}
  │     └── dependencies/{dId}
  ├── pullRequests/{number}    # من الـ webhook
  ├── activity/{aId}
  ├── integrations/{iId}
  ├── clientReport/report      # تقرير واحد لكل مساحة
  └── githubInstallations/{installationId}

users/{uid}
  ├── (profile: displayName, email, photoURL, defaultWorkspaceId)
  ├── notifications/{id}       # id = <wsId>_<inviteId> (idempotent)
  ├── digest/{id}
  └── timeEntries/{id}
```

### الأدوار (ترجمة سياسات RLS القديمة)

| الدور | قراءة | كتابة | إدارة أعضاء |
|---|---|---|---|
| owner | ✔ | ✔ | الجميع عدا مالك آخر |
| admin | ✔ | ✔ | developer/reviewer/viewer |
| developer | ✔ | ✔ | ✖ |
| reviewer | ✔ | ✔ | ✖ |
| viewer | ✔ | ✖ | ✖ |

- **viewer** (العميل الخارجي) يسجّل قراره عبر `submitClientDecision` فقط.
- مالك واحد لكل مساحة — مضمون بـ `transferOwnership` (transaction).
- الإنشعارات تُكتب من الـ Cloud Functions فقط (idempotent).

## Cloud Functions

| الدالة | دور | بديل الـ |
|---|---|---|
| `ensureMyWorkspace` | إنشاء أول مساحة + عضوية المالك | `ensure_my_workspace()` |
| `transferOwnership` | نقل الملكية | `transfer_ownership()` |
| `sendInvites` | دعوة + إشعار الحسابات الموجودة | trigger `notify_invite()` |
| `myPendingInvites` | دعواتي المعلقة | `my_pending_invites()` |
| `syncMyInvites` | تسليم دعوات ما قبل الحساب | `sync_my_invites()` |
| `acceptInvite` | قبول الدعوة | `accept_invite()` |
| `submitClientDecision` | قرار العميل (مرة واحدة) | `submit_client_decision()` |
| `githubAction` | أوامر GitHub (callable) | edge function actions |
| `githubApp` | أرجل OAuth الثلاثة + webhook (HTTP) | edge function |

### متغيرات البيئة للـ Functions

اضبطها بـ `firebase functions:secrets:set` أو ملف `.env` في `functions/`:

```
GITHUB_APP_ID
GITHUB_APP_SLUG
GITHUB_PRIVATE_KEY
GITHUB_WEBHOOK_SECRET
GITHUB_CLIENT_ID
GITHUB_CLIENT_SECRET
```

## GitHub App

نفس تصميم المراجعات الأمنية الثلاثة، منقولاً كما هو:

1. **fail-closed**: بلا `GITHUB_CLIENT_ID/SECRET` يُرفض الطلب.
2. **state موقّع** HMAC يربط (workspace, user, installation) — وبمسار استرداد
   إذا ضاع الـ state (GitHub لا يضمن إعادته على الـ Setup URL)، وحينها
   تُستخرج المساحة من هوية GitHub نفسها.
3. **identity binding**: حساب GitHub في المتصفح لازم يكون مربوطاً بنفس حساب 6DX.
4. **ownership**: حساب شخصي = نفس المستخدم؛ مؤسسة = عضوية `admin` نشطة.
5. **توكن المستخدم يُلغى** بعد إثبات الملكية.

## الاختبارات

```bash
flutter test          # 25 اختبار
flutter analyze
cd functions && npx tsc --noEmit
```

CI (`.github/workflows/checks.yml`) يشغّل الثلاثة على كل push.
