# 6DX — System Design

**المعمارية الحالية:** Flutter (موبايل وويب) + Firebase **للهوية فقط** +
Go backend + SQLite (ملف واحد). لا Supabase، لا Cloud Functions، لا Postgres.

```
Flutter
  │  firebase_auth   → تسجيل الدخول (GitHub / بريد)
  │  HTTP + Bearer   → كل البيانات
  ▼
6DX API (Go)
  │  يتحقق من Firebase ID token
  │  يطبّق الأدوار بنفسه (internal/api/authz.go)
  ▼
SQLite  6dx.db
  └── GitHub App broker ──► GitHub API
```

## 1. لماذا هذا الشكل

| القرار | السبب |
|---|---|
| Firebase للهوية فقط | يوفّر GitHub + بريد بلا سيرفر، ولا يحتاج منّا تشغيل auth |
| Go backend | الأوامر الحسّاسة (bootstrap، دعوات، قرارات، GitHub App) مستحيلة على العميل |
| SQLite | ملف واحد، صفر تشغيل، نسخ احتياطي = نسخ ملف |

## 2. الأمان

الـ API هو **العميل الوحيد** للقاعدة، فالأدوار مفروضة في Go لا في القاعدة.
كل سياسة من سياسات RLS الأصلية موجودة كفحص صريح:

| الأصل (Postgres RLS) | المكافئ الآن |
|---|---|
| `is_workspace_member` | `store.requireMember` |
| `is_workspace_admin` | `store.requireAdmin` |
| `is_workspace_owner` | `store.requireOwner` |
| `is_workspace_editor` (viewer للقراءة فقط) | `store.requireEditor` |
| إدارة الأعضاء الطبقيّة | `handleChangeMemberRole` / `handleRemoveMember` |
| activity insert بـ actor = caller | `logActivity` يمرّر uid التوكن |
| notifications لصاحبها فقط | `where user_uid = ?` داخل الاستعلام |
| مالك واحد · تقرير واحد · إشعار واحد/دعوة | partial unique indexes في السكيما |

**قاعدة ثابتة:** هوية المستخدم تجي **من التوكن فقط** — لا `uid` ولا `role`
ولا `workspace_id` مقبول من جسم الطلب.

## 3. تعدد مساحات العمل

المستخدم ممكن يكون عضو في أكتر من مساحة:

- `X-Workspace-Id` يحدد المساحة النشطة، والـ API يتحقق من العضوية فيها.
- بدونه: أول عضوية؛ وأول دخول ينشئ مساحة + عضوية مالك في transaction.
- بعد قبول دعوة، التطبيق يفعّل المساحة الجديدة.

> ده كان ثغرة حقيقية كشفها اختبار التكامل: بدون التحديد الصريح كان الـ viewer
> يفضل شغّال على مساحته الخاصة (اللي هو مالكها) بدل المساحة اللي اتدعى ليها.

## 4. الـ snapshot

الشاشات تقرأ حمولة واحدة (`GET /v1/workspace/snapshot`) تُبنى في
`internal/api/snapshot.go`. الشكل مطابق لما كان يرجّعه
`get_workspace_snapshot()`، فمافيش شاشة ولا mapper اتغيّر.

## 5. GitHub App

```
Leg 1: التطبيق → POST /v1/github/install-url → installations/new?state=<v1 موقّع>
Leg 2: GitHub → GET /github/setup → 302 إلى /login/oauth/authorize
       (لو ضاع state → توكن استرداد r1 يحمل installation_id فقط)
Leg 3: GitHub → GET /github/callback → exchange → /user
       → identity binding → ownership → حفظ → إلغاء توكن المستخدم
Hook : POST /github/webhook → HMAC على الـ raw body → upsert pull_requests
```

- **fail closed** بلا إعدادات.
- **identity binding**: `users.github_id` مصدره توكن Firebase الموثّق فقط.
- **ownership**: حساب شخصي = نفس المستخدم؛ org = عضوية `admin` نشطة.
- **إلغاء التوكن** بعد إثبات الملكية.

## 6. القيود المعروفة

- **SQLite كاتب واحد** في اللحظة — كافي لعشرات الأعضاء، ويحتاج Postgres لمئات
  المتزامنين (السكيما الأصلية في تاريخ git).
- **لا يوجد JWT cache**: كل طلب يتحقق من Firebase. لو الحمل زاد، cache بـ TTL قصير.
- **تقرير العميل يُزرع يدوياً** (لا endpoint لإنشائه).
