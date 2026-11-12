# 6DX backend

Go API على **SQLite** — ملف واحد، بلا سيرفر، بلا Docker، بلا أي تنزيل.
Firebase مسؤول عن **الهوية فقط**: كل طلب بيحمل Firebase ID token، والـ API
يتحقق منه ويشتغل على ملف القاعدة عندك.

```
Flutter ──(Firebase ID token)──► Go API ──► 6dx.db (SQLite)
                                    └────► GitHub API (GitHub App)
```

## التشغيل — خطوتين

```bash
cd backend
cp .env.example .env

# ضع ملف service account من Firebase console
#   Project settings → Service accounts → Generate new private key
#   → secrets/firebase-service-account.json

go run ./cmd/api
```

> الـ API يقرأ `.env` تلقائياً (من مجلد التشغيل أو المجلد الأعلى). المتغيرات الموجودة في البيئة الفعلية لها الأولوية، فالنشر لا يحتاج ملف.

أول تشغيل بينشئ `6dx.db` تلقائياً مع السكيما كاملة (٢٢ جدول). مفيش `psql` ولا
migration يدوي. `GET /health` للتأكد.

**الإعدادات المطلوبة فقط:** `FIREBASE_PROJECT_ID` + ملف service account.
كل حاجة تانية اختيارية.

## متغيرات البيئة

| المتغير | افتراضي | المعنى |
|---|---|---|
| `DATABASE_FILE` | `./6dx.db` | مسار ملف SQLite (أي مجلد قابل للكتابة) |
| `ADDR` | `:8080` | عنوان الاستماع |
| `FIREBASE_PROJECT_ID` | — | مشروع Firebase اللي بيصدر التوكنات القديمة (اختياري بعد تحويل الدخول لـ GitHub) |
| `FIREBASE_CREDENTIALS_FILE` | — | مسار service account JSON (مطلوب محلياً) |
| `PUBLIC_BASE_URL` | — | رابط الخدمة العام (لبناء GitHub redirect) |
| `CORS_ORIGINS` | `*` | قائمة مفصولة بفواصل |
| `MIGRATE_ON_STARTUP` | `true` | تطبيق الـ migrations عند الإقلاع |
| `GITHUB_APP_ID` … `GITHUB_CLIENT_SECRET` | — | إعدادات GitHub App (اختيارية) |
| `GITHUB_PRIVATE_KEY` أو `GITHUB_PRIVATE_KEY_FILE` | — | PEM مباشر أو مسار ملف |
| `GITHUB_OAUTH_REDIRECT` | `PUBLIC_BASE_URL/github/callback` | لازم يطابق Callback URL |
| `GITHUB_STATE_SECRET` | `GITHUB_WEBHOOK_SECRET` | سر توقيع الـ state |

## الـ API

كل مسارات `/v1` تحتاج `Authorization: Bearer <firebase-id-token>`،
و`X-Workspace-Id` اختياري لتحديد المساحة النشطة (لو المستخدم عضو في أكتر من
واحدة). بدون الهيدر بيُستخدم أول عضوية، وأول دخول بينشئ مساحة.

| Method | Path | الدور |
|---|---|---|
| GET | `/v1/me` | أي مستخدم (ينشئ المساحة لو مش موجودة) || GET | `/v1/workspace/snapshot` | عضو |
| GET/POST | `/v1/projects` | عضو / editor |
| POST | `/v1/projects/{id}/archive` | editor |
| GET/POST | `/v1/tasks` | عضو / editor |
| PATCH | `/v1/tasks/{id}/status` · DELETE | editor |
| POST | `/v1/pull-requests/{number}/review` | editor |
| POST | `/v1/time-entries/approve` | editor |
| GET | `/v1/members` | عضو |
| PATCH/DELETE | `/v1/members/{uid}` | مدير (بحدود) |
| POST | `/v1/invites` | مدير |
| GET | `/v1/invites/pending` · POST `/sync` · POST `/accept` | أي مستخدم |
| POST | `/v1/notifications/{id}/read` · `/read-all` | صاحب الإشعار |
| POST | `/v1/client-report/decision` | عضو (viewer مسموح) |
| GET/POST | `/v1/github/*` | عضو / مدير |

**عامة (بلا توكن):** `GET /health` · `POST /auth/github/device-code` ·
`POST /auth/github/device-token` · `GET /github/setup` ·
`GET /github/callback` · `POST /github/webhook`

## تسجيل الدخول

التطبيق يدخل بـ **GitHub فقط** عبر OAuth **Device Flow** — نفس الطريقة على
الويب والجوال وسطح المكتب، بلا روابط عميقة ولا متصفح مضمّن:

```
POST /auth/github/device-code    → {device_code, user_code, verification_uri}
POST /auth/github/device-token   → {access_token} أو {error: authorization_pending}
```

نقطتين الـ proxy موجودة لأن `github.com` لا يرسل ترويسات CORS، فبناء الويب مش
قادر يكلمها مباشرة. بعد الموافقة، التطبيق يرسل `Authorization: Bearer <github token>`
لكل طلب، والـ API يتحقق من التوكن عبر GitHub (`/user` + `/user/emails`) ويحفظ
النتيجة خمس دقائق.

**ربط الحساب القديم:** التوكن مابيحملش `uid`، فالـ API بيحول رقم حساب GitHub
للمستخدم المحفوظ عبر `users.github_id` (`internal/api/identity.go`). الحسابات
اللي أنشأها Firebase زمان ليها `uid` عشوائي، والربط ده بيخليها تحتفظ
بمساحاتها ومشاريعها بدل ما تتعمل من جديد.

`FIREBASE_PROJECT_ID` لم يعد مطلوباً لتسجيل الدخول: يُستخدم فقط للتحقق من توكنات
Firebase القديمة. لو غاب، الـ API يقلع ويكمل بجلسات GitHub فقط.

## الأدوار

| الدور | قراءة | كتابة | إدارة أعضاء |
|---|---|---|---|
| owner | ✔ | ✔ | الجميع عدا مالك آخر |
| admin | ✔ | ✔ | developer/reviewer/viewer |
| developer | ✔ | ✔ | ✖ |
| reviewer | ✔ | ✔ | ✖ |
| viewer | ✔ | ✖ | ✖ |

`owner` مش بيتوزّع من أي endpoint. **مالك واحد** لكل مساحة مضمون بـ partial
unique index، و**تقرير عميل واحد** كذلك، و**إشعار واحد** لكل (مستخدم، دعوة)
عشان الـ sync يبقى idempotent.

## النشر

```bash
mkdir -p secrets
cp <firebase-key>.json secrets/firebase-service-account.json
cp <app>.private-key.pem secrets/github-app.pem
cp .env.example .env      # املأ FIREBASE_PROJECT_ID و PUBLIC_BASE_URL
docker compose up -d --build
```

الـ `docker-compose.yml` فيه خدمة واحدة بس (مفيش database container):
القاعدة ملف داخل volume اسمه `6dx-data`. **النسخة الاحتياطية = نسخة من
`/data/6dx.db`**.

بدون Docker، شغّل الـ binary مباشرة:

```bash
go build -o 6dx-api ./cmd/api
DATABASE_FILE=/var/lib/6dx/6dx.db FIREBASE_PROJECT_ID=... ./6dx-api
```

## الأوامر

| الأمر | الوظيفة |
|---|---|
| `go run ./cmd/api` | الـ API |
| `go run ./cmd/migrate` | تطبيق الـ migrations كخطوة مستقلة |
| `go run ./cmd/dbinfo` | طباعة الجداول والفهارس الموجودة في الملف |

## الاختبارات

```bash
go test -tags=integration ./internal/api/ -v
```

٩ اختبارات تكامل — **بتشتغل بلا أي تنزيل ولا Docker**، كل اختبار بينشئ ملف
SQLite مؤقت. تغطي: رفض غير المسجّل، إنشاء المساحة، منع viewer من الكتابة، منع
منح `owner`، تحقق قرار العميل، شكل الـ snapshot، دورة حياة المهمة، عزل
المساحات، وتعليم كل الإشعارات كمقروءة.

## البنية

```
cmd/api/          الـ HTTP server
cmd/migrate/      تطبيق الـ migrations
cmd/dbinfo/       فحص محتوى ملف القاعدة
internal/auth/    التحقق من Firebase ID token + الـ middleware
internal/api/     routing · handlers · طبقة الصلاحيات · بناء الـ snapshot
internal/db/      sql.DB + السكيما مضمّنة (go:embed)· migrations
internal/httpx/   مساعدات الردود والأخطاء
```

## لماذا SQLite

- **صفر تشغيل**: ملف واحد، مفيش daemon، مفيش منفذ، مفيش صلاحيات.
- **النسخ الاحتياطي**: نسخ ملف.
- **الأداء**: لعدد أعضاء في العشرات، الاستعلامات محلية وأسرع من شبكة.
- **القيد**: كاتب واحد في اللحظة (SQLite بيقفل الكتابة). لو المشروع كبر
  لمئات المستخدمين المتزامنين، الترقية لـ Postgres — وقتها السكيما
  موجودة في تاريخ git تحت `internal/db/migrations/postgres/`.

## GitHub App

نفس تصميم المراجعات الأمنية:

1. **fail closed** بلا إعدادات — باقي الـ API شغّال عادي
2. **state موقّع** HMAC (workspace, user, installation) + مسار استرداد لو ضاع
   الـ state، والمساحة بتتحدد من **`users.github_id`** المجلوب من توكن Firebase
   الموثّق فقط
3. **identity binding**: حساب GitHub في المتصفح لازم يكون مربوط بنفس حساب 6DX
4. **ownership**: شخصي = نفس المستخدم؛ org = عضوية `admin` نشطة
5. **توكن المستخدم يتلغى** بعد إثبات الملكية
6. **webhook**: HMAC على الـ raw body + ربط الـ installation بالمساحة

إعدادات الـ App اللي لازم تتظبط:

```
Setup URL      https://<domain>/github/setup
Callback URL   https://<domain>/github/callback
Webhook URL    https://<domain>/github/webhook
```
