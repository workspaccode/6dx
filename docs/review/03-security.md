# 03 — مشاكل الحماية

مرتبة حسب الخطورة. البنود 🔴 لازم تتصلح قبل ما أي حد من برا الفريق يستخدم التطبيق.

---

## 🔴 1. أي workspace يقدر يستولى على تثبيت GitHub بتاع منظمة تانية

**الملفات:** [`backend/internal/api/github.go:253-262`](../../backend/internal/api/github.go#L253) و [`:440-447`](../../backend/internal/api/github.go#L440)

**المشكلة:**
- `/github/setup` بياخد `installation_id` من الرابط (المهاجم بيتحكم فيه)، وبيعيد توقيعه جوه أي `state` صالح يوصله.
- الـ callback لما يلاقي `state` صالح بيرجّع `state.WorkspaceID` على طول ([`resolveGithubTarget`](../../backend/internal/api/github.go#L440)) **من غير ما يتأكد** إن مستخدم GitHub اللي عمل التفويض هو نفسه `state.UserID`.
- الـ `state` صالح 30 دقيقة، مش مربوط بمتصفح، وينفع يستخدم أكتر من مرة.

**السيناريو:**
1. المهاجم يعمل workspace خاص بيه (هو الـ owner)، وياخد `state` من `POST /v1/github/install-url`.
2. يبعت لأدمن منظمة الـ App متسطب عندها لينك: `/github/setup?installation_id=<تثبيت الضحية>&state=<state المهاجم>`.
3. GitHub يعدّي التفويض من غير سؤال لأن الضحية وافق قبل كده، و `checkOwnership` ينجح لأن الضحية فعلًا أدمن المنظمة.
4. التثبيت يتسجل على workspace المهاجم، و `POST /v1/github/token` يدّيله توكنات على **كل repos المنظمة**.

**الحل:**
- [ ] في الـ callback: هات `github_id` بتاع `state.UserID` من جدول `users` واتأكد إنه يساوي `githubUserID` اللي رجع من التفويض، ولو مختلف ارفض.
- [ ] خلّي الـ `state` يستخدم مرة واحدة (خزّن الـ nonce في جدول وامسحه بعد الاستخدام)، وقلّل مدته لـ 10 دقايق.
- [ ] ما تعيدش توقيع `installation_id` جاي من الرابط جوه `state` جديد.

## 🔴 2. أي توكن GitHub بيتقبل كتسجيل دخول

**الملف:** [`backend/internal/auth/auth.go:158-213`](../../backend/internal/auth/auth.go#L158)

**المشكلة:** `verifyGitHubGrant` بينادي `GET /user` بس، وده بينجح مع **أي** توكن GitHub: Personal Access Token، أو توكن طالع لأي OAuth app تاني، حتى لو من غير أي scopes.

**السيناريو:** أي تطبيق تالت عنده توكن GitHub لمستخدم (تطبيق CI، إضافة متصفح...) يقدر ينادي API بتاعك كأنه المستخدم ده، وبصلاحية owner على مساحة العمل بتاعته.

**الحل:**
- [ ] اتأكد إن التوكن طالع لتطبيقك: `POST https://api.github.com/applications/{client_id}/token` (Basic auth بـ client_id و client_secret في السيرفر) وقارن `app.client_id`.
- [ ] خزّن النتيجة في الكاش الموجود (5 دقايق) علشان ما تتجاوزش rate limit.

## 🔴 3. الإيميل اللي مش مُوثّق بيتقبل في الدعوات

**الملفات:** [`backend/internal/auth/auth.go:181-196`](../../backend/internal/auth/auth.go#L181)، مستخدم في [`members.go:412-461`](../../backend/internal/api/members.go#L412)

**المشكلة:** الحقل `verified` في `/user/emails` مش بيتشيّك. وفي مسار Firebase القديم (`auth.go:126`) الـ `email_verified` بيتجاهل.

**السيناريو:**
- المهاجم يحط `victim@company.com` كإيميل أساسي (من غير توثيق) على حساب GitHub بتاعه، وياخد أي دعوة اتبعتت للإيميل ده.
- وبسبب الـ unique index على الإيميل (`users_email_idx` في الـ migration سطر 27)، لما صاحب الإيميل الحقيقي يسجّل دخول `upsertUser` بيفشل، **وكل `/v1` بترجعله 500**.

**الحل:**
- [ ] خد الإيميل بس لو `primary == true && verified == true`.
- [ ] في مسار Firebase اتأكد من `email_verified`.
- [ ] لو الإيميل موجود لمستخدم تاني، متفشلش الطلب كله: سيب الإيميل فاضي للمستخدم الجديد وسجّل تحذير.

## 🔴 4. تسجيل الخروج التلقائي لما النت يقطع

**الملفات:** [`lib/features/auth/data/backends/github_auth_backend.dart:41-43`](../../lib/features/auth/data/backends/github_auth_backend.dart#L41) و [`auth_repository_impl.dart:57-60`](../../lib/features/auth/data/repositories/auth_repository_impl.dart#L57)

**المشكلة:** `restoreSession` بيرجّع `null` مع **أي** خطأ (نت مقطوع، timeout، GitHub واقع، rate limit)، وبعدها `currentUser` بيعمل `clearSession()` **ويمسح التوكن**.

**السيناريو:** المستخدم يفتح التطبيق في المترو من غير نت، فيلاقي نفسه خرج ولازم يعمل device flow من الأول.

**الحل:**
- [ ] امسح التوكن **بس** لو GitHub رجّع 401.
- [ ] في أي خطأ تاني رجّع المستخدم المحفوظ من `AuthLocalDataSource.readCachedUser()` وكمّل.

## 🟠 5. الـ webhook بيتحقق منه بالمفتاح الغلط

**الملف:** [`backend/internal/api/github.go:81`](../../backend/internal/api/github.go#L81) و [`:518`](../../backend/internal/api/github.go#L518)

- [ ] `handleGithubWebhook` بيستخدم `b.hmac()`، وده متوقّع بـ `GitHubStateSecret` مش `GitHubWebhookSecret`.
  - لو ضبطت `GITHUB_STATE_SECRET` بقيمة مختلفة (زي ما `.env.example` بيقول)، **كل الـ webhooks الحقيقية هترجع 401**.
  - ولو القيمتين متساويتين، نفس المفتاح بيوقّع الـ state والـ webhook، وده خلط بين استخدامين مختلفين.
- **الحل:** اعمل دالة `webhookHMAC` منفصلة بـ `GitHubWebhookSecret`.

## 🟠 6. عضو عادي يقدر يربط تثبيت GitHub (من غير state)

**الملف:** [`github.go:312-317`](../../backend/internal/api/github.go#L312) و [`:450-467`](../../backend/internal/api/github.go#L450) — من commit `2bb89bb`

- [ ] لما الـ callback ييجي من غير `state`، مساحة العمل بتتحدد على إنها أول عضوية للمستخدم **من غير أي فحص للصلاحية**. يعني viewer عضو بس في مساحة عمل حد تاني (قبل دعوة قبل ما يتعمله workspace خاص) يقدر يربط تثبيت بتاعه، ويعدّي `requireAdmin` اللي على `install-url`.
- **الحل:** في مسار الـ recovery اشترط إن الدور `owner` أو `admin`.

## 🟠 7. توكن التثبيت بصلاحيات كاملة

- [ ] `/v1/github/token` ([`github.go:163`](../../backend/internal/api/github.go#L163)) بيطلع installation token من غير `repositories` ولا `permissions`، فأي developer بياخد كل صلاحيات الـ App على كل repos التثبيت.
- **الحل:** حدّد `repositories` بالـ repos المربوطة بمشاريع الـ workspace، و `permissions` بالحد الأدنى المطلوب.

## 🟡 8. HTTP غير مشفّر لعنوان LAN ثابت

**الملف:** [`android/app/src/main/res/xml/network_security_config.xml`](../../android/app/src/main/res/xml/network_security_config.xml)

- [ ] `cleartextTrafficPermitted="true"` لـ `192.168.1.11` حتى في نسخة الـ release. يعني توكن GitHub بيتبعت **من غير تشفير** على الشبكة دي، وأي حد على نفس الـ Wi-Fi يقدر يشوفه.
- [ ] الـ IP مكتوب ثابت؛ لو الراوتر غيّره التطبيق هيقف.
- **الحل:** حط الـ `domain-config` ده في `android/app/src/debug/res/xml/` بس، واستخدم HTTPS في الـ release.

## 🟡 9. `AppConfig.apiBaseUrl` الافتراضي localhost

- [ ] [`lib/core/config/app_config.dart:19-25`](../../lib/core/config/app_config.dart#L19): لو اتعمل build للـ release من غير `--dart-define=API_BASE_URL`، التطبيق هيكلّم `http://10.0.2.2:8080` / `http://localhost:8080`.
- **الحل:** في الـ release اشترط وجود القيمة، واعمل `assert` أو اقفل التطبيق بشاشة واضحة لو مش موجودة.

## 🟡 10. التوكن جوه الـ entity وبيتطبع

- [ ] `AuthUser` فيه `accessToken`، والـ `toString()` اللي freezed بيعمله بيطبعه. أي `print(user)` أو log فيه المستخدم هيطلع التوكن.
- [ ] `AppLogger.action` بيطبع في الـ release (commit `4044920`)، والرسايل فيها `login` المستخدم والـ `userCode`. ده مش سر خطير، بس التعليق بيقول "never contain personal data".
- **الحل:** شيل `accessToken` من `AuthUser` (هو متخزن في secure storage أصلًا)، أو اعمل override لـ `toString`.

## 🟡 11. CORS مفتوح

- [ ] `CORS_ORIGINS` افتراضيًا `*` ([`config.go:65`](../../backend/internal/config/config.go#L65)) وبيرجّع أي Origin. الخطر قليل لأن المصادقة Bearer مش cookies، بس في الـ production حدّد دومين الويب بس.

## ⚪ 12. حاجات تانية

- [ ] مفيش rate limit على الـ API. كل توكن غلط بيعمل نداء لـ GitHub، وده ممكن يخلّي GitHub يعمل throttle لـ IP السيرفر.
- [ ] التوكن اللي اتسحب منه الصلاحية بيفضل شغال لحد 5 دقايق (مدة الكاش).
- [ ] توكن المستخدم مش بيتعمله revoke لو الـ callback فشل بعد تبادل الـ code.
- [ ] `ReadTimeout` و `WriteTimeout` مش متضبطين في [`cmd/api/main.go`](../../backend/cmd/api/main.go#L62) (`ReadHeaderTimeout` بس)، فالسيرفر عُرضة لـ slow-body attacks.

## ✅ حاجات معمولة صح

- مقارنة توقيع الـ state والـ webhook بـ `hmac.Equal` (constant-time)، والـ webhook HMAC على الـ body الخام.
- كل الـ SQL parameterized، ومفيش SQL injection.
- مفيش open redirect: الـ redirect دايمًا لـ github.com.
- فحص ملكية التثبيت صارم: الحساب الشخصي لازم نفس الـ id، والمنظمة لازم عضوية `admin` نشطة.
- الأخطاء غير المتوقعة بتتسجل في الـ log بس، والعميل بياخد 500 عام.
- الـ `client_secret` اتشال من التطبيق.
