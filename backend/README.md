# 6DX backend

Go API + Postgres. **Firebase is the identity provider only** — every request
carries a Firebase ID token, the API verifies it, and all data lives in your
own database.

```
Flutter ──(Firebase ID token)──► Go API ──► Postgres
                                    └──► GitHub API (GitHub App)
```

## التشغيل محلياً

```bash
# 1) قاعدة البيانات
docker run --rm -d --name 6dx-db \
  -e POSTGRES_PASSWORD=sixdx_dev_password \
  -e POSTGRES_DB=sixdx \
  -p 5432:5432 postgres:17-alpine

# 2) الإعدادات
cp .env.example .env
#    → املأ FIREBASE_PROJECT_ID و FIREBASE_CREDENTIALS_FILE

# 3) الـ migrations + الـ API
export DATABASE_URL='postgres://postgres:sixdx_dev_password@localhost:5432/sixdx?sslmode=disable'
go run ./cmd/migrate     # يطبّق migrations/*.sql ويسجّلها
go run ./cmd/api         # يشتغل على :8080
```

`GET /health` للتأكد.

## النشر على سيرفرك

```bash
docker compose up -d --build
```

`docker compose` بيشغّل Postgres + الـ API. لازم قبلها:

```bash
mkdir -p secrets
# من Firebase console → Project settings → Service accounts → Generate new key
cp ~/Downloads/<project>-firebase-adminsdk-*.json secrets/firebase-service-account.json
# مفتاح GitHub App
cp <your-app>.private-key.pem secrets/github-app.private-key.pem
cp .env.example .env      # املأ القيم
docker compose up -d --build
```

الـ migrations بتتطبّق تلقائياً عند أول تشغيل (`MIGRATE_ON_STARTUP=true`).
عشان تفصلها: `MIGRATE_ON_STARTUP=false` وشغّل `docker compose run --rm api /usr/local/bin/api` مش هينفع — استخدم:

```bash
docker compose run --rm -e MIGRATE_ON_STARTUP=true api
```

## متغيرات البيئة

| المتغير | مطلوب | المعنى |
|---|---|---|
| `DATABASE_URL` | ✔ | اتصال Postgres |
| `FIREBASE_PROJECT_ID` | ✔ | مشروع Firebase اللي بيصدر التوكنات |
| `FIREBASE_CREDENTIALS_FILE` | ✔* | مسار service account JSON (*أو ADC على Cloud Run/GCE) |
| `PUBLIC_BASE_URL` | ✔ | رابط الخدمة العام (لبناء redirect الـ GitHub) |
| `CORS_ORIGINS` | ✖ | قائمة مفصولة بفواصل، `*` افتراضياً |
| `GITHUB_APP_ID` … `GITHUB_CLIENT_SECRET` | ✖** | إعدادات GitHub App |
| `GITHUB_OAUTH_REDIRECT` | ✖ | لازم يطابق Callback URL في إعدادات الـ App |
| `GITHUB_STATE_SECRET` | ✖ | افتراضياً `GITHUB_WEBHOOK_SECRET` |

\*\* بلا الإعدادات دي كل مسارات `/github/*` بترفض (fail closed) وباقي الـ API
شغّال عادي.

## الـ API

كل المسارات تحت `/v1` تحتاج `Authorization: Bearer <firebase-id-token>`،
و`X-Workspace-Id` اختياري لتحديد المساحة النشطة (لو المستخدم عضو في أكتر من
واحدة). بدون الهيدر بيُستخدم أول عضوية، وأول دخول بينشئ مساحة.

| Method | Path | الدور المطلوب |
|---|---|---|
| GET | `/v1/me` | أي مستخدم (ينشئ المساحة لو مش موجودة) |
| GET | `/v1/workspace/snapshot` | عضو |
| GET/POST | `/v1/projects` | عضو / editor |
| POST | `/v1/projects/{id}/archive` | editor |
| GET/POST | `/v1/tasks` | عضو / editor |
| PATCH | `/v1/tasks/{id}/status` | editor |
| DELETE | `/v1/tasks/{id}` | editor |
| POST | `/v1/pull-requests/{number}/review` | editor |
| POST | `/v1/time-entries/approve` | editor |
| GET | `/v1/members` | عضو |
| PATCH/DELETE | `/v1/members/{uid}` | مدير (بحدود) |
| POST | `/v1/invites` | مدير |
| GET | `/v1/invites/pending` | أي مستخدم |
| POST | `/v1/invites/sync` | أي مستخدم |
| POST | `/v1/invites/accept` | أي مستخدم |
| POST | `/v1/notifications/{id}/read` | صاحب الإشعار |
| POST | `/v1/notifications/read-all` | صاحب الإشعار |
| POST | `/v1/client-report/decision` | عضو (viewer مسموح) |
| GET/POST | `/v1/github/*` | عضو / مدير |

**عامة (بلا توكن):** `GET /health` · `GET /github/setup` ·
`GET /github/callback` · `POST /github/webhook`

## الأدوار

| الدور | قراءة | كتابة | إدارة أعضاء |
|---|---|---|---|
| owner | ✔ | ✔ | الجميع عدا مالك آخر |
| admin | ✔ | ✔ | developer/reviewer/viewer |
| developer | ✔ | ✔ | ✖ |
| reviewer | ✔ | ✔ | ✖ |
| viewer | ✔ | ✖ | ✖ |

- `owner` مش بيتوزّع من أي endpoint — بس
  `POST /v1/members/{uid}` بيرفضه، ونقل الملكية محتاج مسار مخصص.
- **مالك واحد** لكل مساحة مضمون بـ partial unique index.
- **تقرير عميل واحد** لكل مساحة (unique index).
- **إشعار واحد** لكل (مستخدم، دعوة) → الـ sync idempotent.

## الاختبارات

```bash
docker run --rm -d -p 55432:5432 -e POSTGRES_PASSWORD=test \
  -e POSTGRES_DB=sixdx postgres:17-alpine

DATABASE_URL='postgres://postgres:test@localhost:55432/sixdx?sslmode=disable' \
  go test -tags=integration ./internal/api/ -v
```

سبعة اختبارات تكامل بتغطي طبقة الصلاحيات (الـ RLS المترجمة)، إنشاء المساحة،
منع الـ viewer من الكتابة، منع منح `owner`، تحقق قرار العميل، وشكل الـ
snapshot.

## البنية

```
cmd/api/          الـ HTTP server
cmd/migrate/      تطبيق الـ migrations كخطوة مستقلة
internal/auth/    التحقق من Firebase ID token + الـ middleware
internal/api/     الـ routing والـ handlers وطبقة الصلاحيات
internal/db/      pgxpool + migrations مضمّنة (go:embed)
internal/httpx/   مساعدات الردود والأخطاء
```

## GitHub App

نفس تصميم المراجعات الأمنية:

1. **fail closed** بلا إعدادات
2. **state موقّع** HMAC (workspace, user, installation) + مسار استرداد لو ضاع
   الـ state، وحينها المساحة بتتحدد من **هوية GitHub** المخزّنة في
   `users.github_id` (المصدر الموثوق: توكن Firebase نفسه)
3. **identity binding**: حساب GitHub في المتصفح لازم يكون مربوط بنفس حساب 6DX
4. **ownership**: شخصي = نفس المستخدم؛ org = عضوية `admin` نشطة
5. **توكن المستخدم يتلغى** بعد إثبات الملكية
6. **webhook**: HMAC على الـ raw body + ربط الـ installation بالمساحة

المسارات اللي لازم تتظبط في إعدادات الـ GitHub App:

```
Setup URL      https://<your-domain>/github/setup
Callback URL   https://<your-domain>/github/callback
Webhook URL    https://<your-domain>/github/webhook
```
