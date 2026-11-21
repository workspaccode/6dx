# 05 — مشاكل هتقابلك في المستقبل

دي مش bugs النهارده، بس هتظهر لما يزيد المستخدمين أو البيانات أو حجم الفريق.

---

## 🔴 الـ CI مش شغال أصلًا

**الملف:** [`.github/workflows/checks.yml`](../../.github/workflows/checks.yml)

- [x] **مش بيشتغل على الـ push:** الـ trigger على `branches: [main]`، والفرع الافتراضي عندك اسمه `master`. يعني مفيش أي فحص بيحصل على الـ push.
- [x] **لو اشتغل هيفشل في أول خطوة:** بيسطّب Flutter `3.35.x` (Dart 3.9)، والـ [`pubspec.yaml`](../../pubspec.yaml#L7) طالب `sdk: ">=3.10.0"`، فـ `flutter pub get` هيقع. **(تصحيح المراجعة التانية):** الـ `pubspec.lock` فعليًا طالب `flutter: ">=3.47.0"` و `dart: ">=3.13.0"`، يعني `3.38.x` المقترح تحت **مش هيكفي**.
- [x] Go في الـ CI `1.23`، والـ [`go.mod`](../../backend/go.mod#L3) بيقول `go 1.26.0`. هيشتغل بس لأن Go بينزّل الـ toolchain تلقائي في كل run، وده وقت ضايع ومصدر مفاجآت. ونفس المشكلة في الـ [`Dockerfile`](../../backend/Dockerfile#L2) (`golang:1.23-alpine`) — تفاصيل في [06-platform-release.md](06-platform-release.md).

**الحل:**

```yaml
on:
  push:
    branches: [master]
  pull_request:

# ...
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.47.x'   # الـ pubspec.lock طالب flutter >= 3.47.0
# ...
      - uses: actions/setup-go@v5
        with:
          go-version-file: backend/go.mod
```

---

## 🟠 الأداء والتوسع (Backend)

### SQLite باتصال واحد

- [ ] [`db.go:56`](../../backend/internal/db/db.go#L56): `SetMaxOpenConns(1)`، يعني **كل** طلبات السيرفر بتتنفذ ورا بعض على اتصال واحد.
  - `/v1/snapshot` لوحده فيه **18** query، فلو 20 مستخدم فتحوا التطبيق في نفس الوقت كلهم هيستنوا في طابور.
- [ ] ملف SQLite = **سيرفر واحد بس**. مش هتقدر تشغّل نسختين من الـ API ورا load balancer، والكاش بتاع توكنات GitHub في الذاكرة ([`auth.go:66`](../../backend/internal/auth/auth.go#L66)) كمان لكل نسخة لوحدها.
- **الخطة:**
  - قريبًا: افصل اتصال القراءة (`SetMaxOpenConns(N)` مع WAL) عن اتصال الكتابة.
  - لما تكبر: ارجع لـ Postgres. الكود كان شغال عليه قبل كده (commit `23b5694`)، فخلي الـ SQL متوافق مع الاتنين.
- [ ] **مفيش backups:** اعمل `sqlite3 6dx.db ".backup ..."` دوري، أو استخدم Litestream.

### الـ Snapshot بيرجّع كل حاجة

- [ ] endpoint واحد بيرجّع المشاريع والمهام والأعضاء والـ PRs والنشاط والـ sprints... مع كل فتحة للتطبيق.
  - النشاط محدود بـ 200 ([`snapshot.go:341`](../../backend/internal/api/snapshot.go#L341)).
  - المهام في `/v1/tasks` و `snapshot.go:185` **من غير أي limit أو pagination**.
- **النتيجة:** workspace فيه 5000 مهمة هيبقى response بالميجات، والتطبيق هيبطأ ويستهلك باقة المستخدم.
- **الحل:** pagination بـ cursor (`?after=<id>&limit=50`)، وخلّي الـ snapshot للعدادات والملخصات بس.

### مفيش rate limiting

- [x] أي حد يقدر يبعت آلاف الطلبات بتوكنات غلط، وكل واحد بينادي GitHub. GitHub هيعمل throttle لـ IP السيرفر، فـ**كل** المستخدمين مش هيقدروا يدخلوا.
- **الحل:** rate limiter لكل IP (مثلًا `golang.org/x/time/rate`)، وكاش سلبي للتوكنات الغلط لمدة دقيقة.

### الـ Migrations

- [ ] فيه migration واحدة بس `0001_init.sql`. أول تعديل على الـ schema (زي إصلاح unique key الـ PRs في [04-backend.md](04-backend.md)) لازم يبقى `0002_...sql` جديد، **ما تعدّلش `0001`** لأن قواعد البيانات اللي اشتغلت مش هتتحدث.

---

## 🟠 الصيانة (التطبيق)

### الاختبارات قليلة جدًا مقارنة بحجم الكود

- [ ] حوالي **22 ألف سطر** (Dart + Go)، وفي `test/` 9 ملفات أغلبها UI kit و layout. مفيش اختبارات للـ repositories ولا الـ notifiers ولا الـ router ولا الـ mapper.
- **أولوية الاختبارات:**
  1. `workspace_snapshot_mapper`: اختبار بـ JSON حقيقي طالع من السيرفر (كان هيمسك مشكلة ألوان الـ labels).
  2. `app_router`: كل مسار بيفتح الصفحة الصح (كان هيمسك `/tasks/bulk`).
  3. `AuthRepositoryImpl.currentUser`: حالة "مفيش نت" (كان هيمسك الخروج التلقائي).

### بقايا من backends قديمة

- [ ] المشروع اتنقل Supabase ← Firebase ← Go+Postgres ← Go+SQLite في كام أسبوع. لسه فيه بقايا، زي أكواد أخطاء Postgres في الـ UI و Firebase في الـ backend. كل بقية من دي bug مستخبي، فاعمل sweep على `supabase`، `firebase`، `42501`، و `P0002`.

### الترجمة هتبقى أصعب كل يوم

- [ ] 946 نص ثابت النهارده. كل شاشة جديدة بنفس الأسلوب بتزوّد الشغل. **ابدأ القاعدة دلوقتي:** أي نص جديد يدخل في `app_ar.arb`. ضيف lint أو اختبار يرفض النصوص العربي المباشرة في `lib/features/**/pages`.

### شاشات أكتر من الميزات

- [ ] فيه 86 route وشاشات كتير شكلها بس (agents، knowledge map، ask project، estimates، billing...) من غير أي backend وراها. كل شاشة منهم محتاجة صيانة مع كل تغيير في الـ theme أو الـ UI kit.
- **اقتراح:** خبّي الشاشات اللي مالهاش backend ورا feature flag لحد ما الميزة تتعمل فعلًا.

---

## 🟡 التشغيل والنشر

- [x] **عنوان السيرفر:**
  - الـ IP ثابت في `network_security_config.xml` (`192.168.1.11`)، فأي تغيير في الشبكة يوقف التطبيق.
  - الـ `apiBaseUrl` الافتراضي localhost.
  - **قبل أي نشر:** دومين ثابت + HTTPS + `--dart-define=API_BASE_URL` في سكريبت الـ build.
- [ ] **الـ device flow في التطبيق:**
  - بيعمل polling لحد 15 دقيقة من غير زر إلغاء.
  - لو المستخدم خرج من صفحة الدخول، الـ polling بيكمّل في الخلفية.
  - أي خطأ شبكة لحظي وسط الانتظار بيفشّل الدخول كله بدل ما يعيد المحاولة.
- [ ] **التوكن مش بيتعمله revoke عند الخروج** (`github_auth_backend.dart:104`): بيتمسح من الجهاز بس، والتوكن نفسه بيفضل صالح على GitHub. اعمل endpoint في الـ backend يعمل revoke (السر موجود في السيرفر).
- [ ] **الـ Logs:**
  - `AppLogger.action` بيكتب في الـ release بـ `print`.
  - الـ backend بيسجّل بـ `slog` من غير request id، فلما مستخدم يشتكي مش هتعرف تربط خطأ التطبيق بسطر في السيرفر.
  - **الحل:** ابعت `X-Request-Id` من التطبيق وسجّله في الـ backend.
- [ ] **مراقبة الأخطاء:** مفيش crash reporting (Sentry / Crashlytics). أول مستخدمين حقيقيين هيقابلوا أخطاء انت مش هتعرف عنها حاجة.

---

## ⚪ الـ Dependencies

- [ ] `pubspec.yaml` فيه `auto_route` و `auto_route_generator` مستخدمين في 13 route ميتة. احذفهم.
- [ ] `firebase.google.com/go/v4` في الـ backend: dependency تقيل علشان مسار legacy.
- [ ] اعمل Dependabot (`.github/dependabot.yml`) لـ `pub` و `gomod` و `github-actions`.
- [x] **(المراجعة التانية) dependencies عليها CVEs معروفة** في [`backend/go.mod`](../../backend/go.mod):
  - `golang-jwt/jwt/v5 v5.2.1` و `jwt/v4 v4.5.0` (indirect): CVE-2025-30204، متصلّح في 5.2.2. مش reachable لأن الكود بيوقّع JWT بس ومش بيعمل parse.
  - `golang.org/x/net v0.30.0`: CVE-2024-45338 و CVE-2025-22870/22872.
  - `golang.org/x/crypto v0.28.0`: CVEs في SSH، والـ SSH مش مستخدم.
  - **الحل:** حدّثهم كلهم، وضيف `govulncheck ./...` في الـ CI (اتقيّم بقراءة الكود بس، `govulncheck` مكانش متسطب).
