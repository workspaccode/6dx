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
- [x] في الـ callback: هات `github_id` بتاع `state.UserID` من جدول `users` واتأكد إنه يساوي `githubUserID` اللي رجع من التفويض، ولو مختلف ارفض.
- [ ] خلّي الـ `state` يستخدم مرة واحدة (خزّن الـ nonce في جدول وامسحه بعد الاستخدام)، وقلّل مدته لـ 10 دقايق.
- [ ] ما تعيدش توقيع `installation_id` جاي من الرابط جوه `state` جديد.
- [x] **(المراجعة التانية) الحل ده لوحده مش كفاية — في مسار تاني:** [`github.go:302-316`](../../backend/internal/api/github.go#L302). لو الـ `state` صالح بس `InstallationID == 0` (ده بالظبط اللي `install-url` بيطلّعه)، الكود بيدخل الـ `default` ويقرا `installation_id` من الـ query string، و `stateOK` بيفضل true، فـ `resolveGithubTarget` بيرجّع workspace المهاجم. المهاجم يقدر يبعت الضحية على `github.com/login/oauth/authorize?...&state=<state المهاجم>&redirect_uri=<api>/github/callback?installation_id=<تثبيت الضحية>` من غير ما يعدّي على `/github/setup` خالص. **الحل:** لو `stateOK` متقراش `installation_id` من الرابط أبدًا، وخد بس الـ id الموقّع.
- [x] **(المراجعة التانية) الـ state ممكن يتجدد للأبد:** [`github.go:261-262`](../../backend/internal/api/github.go#L261) بيعيد التوقيع بـ `time.Now()`، فلو عدّيت الـ state على `/github/setup` كل 29 دقيقة مش هيخلص. انقل `issuedAt` الأصلي للـ state الجديد.

## 🔴 2. أي توكن GitHub بيتقبل كتسجيل دخول

**الملف:** [`backend/internal/auth/auth.go:158-213`](../../backend/internal/auth/auth.go#L158)

**المشكلة:** `verifyGitHubGrant` بينادي `GET /user` بس، وده بينجح مع **أي** توكن GitHub: Personal Access Token، أو توكن طالع لأي OAuth app تاني، حتى لو من غير أي scopes.

**السيناريو:** أي تطبيق تالت عنده توكن GitHub لمستخدم (تطبيق CI، إضافة متصفح...) يقدر ينادي API بتاعك كأنه المستخدم ده، وبصلاحية owner على مساحة العمل بتاعته.

**الحل:**
- [x] اتأكد إن التوكن طالع لتطبيقك: `POST https://api.github.com/applications/{client_id}/token` (Basic auth بـ client_id و client_secret في السيرفر) وقارن `app.client_id`.
- [x] خزّن النتيجة في الكاش الموجود (5 دقايق) علشان ما تتجاوزش rate limit.

## 🔴 3. الإيميل اللي مش مُوثّق بيتقبل في الدعوات

**الملفات:** [`backend/internal/auth/auth.go:181-196`](../../backend/internal/auth/auth.go#L181)، مستخدم في [`members.go:412-461`](../../backend/internal/api/members.go#L412)

**المشكلة:** الحقل `verified` في `/user/emails` مش بيتشيّك. وفي مسار Firebase القديم (`auth.go:126`) الـ `email_verified` بيتجاهل.

**السيناريو:**
- المهاجم يحط `victim@company.com` كإيميل أساسي (من غير توثيق) على حساب GitHub بتاعه، وياخد أي دعوة اتبعتت للإيميل ده.
- وبسبب الـ unique index على الإيميل (`users_email_idx` في الـ migration سطر 27)، لما صاحب الإيميل الحقيقي يسجّل دخول `upsertUser` بيفشل، **وكل `/v1` بترجعله 500**.

**الحل:**
- [x] خد الإيميل بس لو `primary == true && verified == true`.
- [x] في مسار Firebase اتأكد من `email_verified`.
- [x] لو الإيميل موجود لمستخدم تاني، متفشلش الطلب كله: سيب الإيميل فاضي للمستخدم الجديد وسجّل تحذير.

## 🔴 4. تسجيل الخروج التلقائي لما النت يقطع

**الملفات:** [`lib/features/auth/data/backends/github_auth_backend.dart:41-43`](../../lib/features/auth/data/backends/github_auth_backend.dart#L41) و [`auth_repository_impl.dart:57-60`](../../lib/features/auth/data/repositories/auth_repository_impl.dart#L57)

**المشكلة:** `restoreSession` بيرجّع `null` مع **أي** خطأ (نت مقطوع، timeout، GitHub واقع، rate limit)، وبعدها `currentUser` بيعمل `clearSession()` **ويمسح التوكن**.

**السيناريو:** المستخدم يفتح التطبيق في المترو من غير نت، فيلاقي نفسه خرج ولازم يعمل device flow من الأول.

**الحل:**
- [x] امسح التوكن **بس** لو GitHub رجّع 401.
- [x] في أي خطأ تاني رجّع المستخدم المحفوظ من `AuthLocalDataSource.readCachedUser()` وكمّل.

## 🟠 5. الـ webhook بيتحقق منه بالمفتاح الغلط

**الملف:** [`backend/internal/api/github.go:81`](../../backend/internal/api/github.go#L81) و [`:518`](../../backend/internal/api/github.go#L518)

- [x] `handleGithubWebhook` بيستخدم `b.hmac()`، وده متوقّع بـ `GitHubStateSecret` مش `GitHubWebhookSecret`.
  - لو ضبطت `GITHUB_STATE_SECRET` بقيمة مختلفة (زي ما `.env.example` بيقول)، **كل الـ webhooks الحقيقية هترجع 401**.
  - ولو القيمتين متساويتين، نفس المفتاح بيوقّع الـ state والـ webhook، وده خلط بين استخدامين مختلفين.
- **الحل:** اعمل دالة `webhookHMAC` منفصلة بـ `GitHubWebhookSecret`.

## 🟠 6. عضو عادي يقدر يربط تثبيت GitHub (من غير state)

**الملف:** [`github.go:312-317`](../../backend/internal/api/github.go#L312) و [`:450-467`](../../backend/internal/api/github.go#L450) — من commit `2bb89bb`

- [x] لما الـ callback ييجي من غير `state`، مساحة العمل بتتحدد على إنها أول عضوية للمستخدم **من غير أي فحص للصلاحية**. يعني viewer عضو بس في مساحة عمل حد تاني (قبل دعوة قبل ما يتعمله workspace خاص) يقدر يربط تثبيت بتاعه، ويعدّي `requireAdmin` اللي على `install-url`.
- **الحل:** في مسار الـ recovery اشترط إن الدور `owner` أو `admin`.
- **تصحيح (المراجعة التانية):** الخطر أقل من الموصوف. أول دخول بيعمل للمستخدم workspace هو الـ owner فيه، والـ query بيرتب `role = 'owner'` الأول، فالمشكلة بتحصل بس لمستخدم معندوش أي workspace بيمتلكه.

## 🟠 7. توكن التثبيت بصلاحيات كاملة

- [ ] `/v1/github/token` (الـ handler في [`github.go:719-759`](../../backend/internal/api/github.go#L719)، والطلب لـ GitHub في `installationToken` سطر 163) بيطلع installation token من غير `repositories` ولا `permissions`، فأي developer بياخد كل صلاحيات الـ App على كل repos التثبيت.
- **الحل:** حدّد `repositories` بالـ repos المربوطة بمشاريع الـ workspace، و `permissions` بالحد الأدنى المطلوب.

## 🟡 8. HTTP غير مشفّر لعنوان LAN ثابت

**الملف:** [`android/app/src/main/res/xml/network_security_config.xml`](../../android/app/src/main/res/xml/network_security_config.xml)

- [x] `cleartextTrafficPermitted="true"` لـ `192.168.1.11` حتى في نسخة الـ release. يعني توكن GitHub بيتبعت **من غير تشفير** على الشبكة دي، وأي حد على نفس الـ Wi-Fi يقدر يشوفه.
- [x] الـ IP مكتوب ثابت؛ لو الراوتر غيّره التطبيق هيقف.
- **الحل:** حط الـ `domain-config` ده في `android/app/src/debug/res/xml/` بس، واستخدم HTTPS في الـ release.

## 🟡 9. `AppConfig.apiBaseUrl` الافتراضي localhost

- [x] [`lib/core/config/app_config.dart:19-25`](../../lib/core/config/app_config.dart#L19): لو اتعمل build للـ release من غير `--dart-define=API_BASE_URL`، التطبيق هيكلّم `http://10.0.2.2:8080` / `http://localhost:8080`.
- **الحل:** في الـ release اشترط وجود القيمة، واعمل `assert` أو اقفل التطبيق بشاشة واضحة لو مش موجودة.

## 🟡 10. التوكن جوه الـ entity وبيتطبع

- [ ] `AuthUser` فيه `accessToken`، والـ `toString()` اللي freezed بيعمله بيطبعه. أي `print(user)` أو log فيه المستخدم هيطلع التوكن.
- [ ] `AppLogger.action` بيطبع في الـ release (commit `4044920`)، والرسايل فيها `login` المستخدم والـ `userCode`. ده مش سر خطير، بس التعليق بيقول "never contain personal data".
- **الحل:** شيل `accessToken` من `AuthUser` (هو متخزن في secure storage أصلًا)، أو اعمل override لـ `toString`.
- [x] **(المراجعة التانية) التوكن متخزن مرتين:** [`auth_local_data_source.dart:15`](../../lib/features/auth/data/datasources/auth_local_data_source.dart#L15) بيكتب `user.toJson()` وفيه `accessToken` ([`user_model.dart:18`](../../lib/features/auth/data/models/user_model.dart#L18)) تحت مفتاح `user`. وكل أخطاء الكتابة/المسح بتتبلع في [`secure_storage_service.dart:37-51`](../../lib/core/storage/secure_storage_service.dart#L37)، فلو المسح فشل عند الخروج التوكن بيفضل والـ UI بيقول إنك خرجت. **الحل:** `@JsonKey(includeToJson: false)` على `accessToken`، وخلّي المسح عند الخروج يرمي الخطأ.
- [x] الـ logs في الـ release بتطبع كمان `login` بتاع GitHub ([`github_auth_backend.dart:39,97`](../../lib/features/auth/data/backends/github_auth_backend.dart#L39)) والـ `userCode` (`:51`).

## 🟡 11. CORS مفتوح

- [x] `CORS_ORIGINS` افتراضيًا `*` ([`config.go:65`](../../backend/internal/config/config.go#L65)) وبيرجّع أي Origin. الخطر قليل لأن المصادقة Bearer مش cookies، بس في الـ production حدّد دومين الويب بس.

## ⚪ 12. حاجات تانية

- [x] مفيش rate limit على الـ API. كل توكن غلط بيعمل نداء لـ GitHub، وده ممكن يخلّي GitHub يعمل throttle لـ IP السيرفر.
- [ ] التوكن اللي اتسحب منه الصلاحية بيفضل شغال لحد 5 دقايق (مدة الكاش).
- [ ] توكن المستخدم مش بيتعمله revoke لو الـ callback فشل بعد تبادل الـ code.
- [x] `ReadTimeout` و `WriteTimeout` مش متضبطين في [`cmd/api/main.go`](../../backend/cmd/api/main.go#L62) (`ReadHeaderTimeout` بس)، فالسيرفر عُرضة لـ slow-body attacks.

---

# إضافات المراجعة التانية

مشاكل جديدة اتلاقت في المراجعة التانية ومكانتش في القائمة فوق. كل بند اتأكد منه من الكود. مشاكل إعدادات المنصات (Android/iOS/Web/Docker/CI) في [06-platform-release.md](06-platform-release.md).

## 🔴 13. توكن تثبيت GitHub بيفضل شغال بعد الخروج أو تغيير الـ workspace

**الملف:** [`lib/features/github/data/datasources/github_sdk.dart:31-60`](../../lib/features/github/data/datasources/github_sdk.dart#L31)

- [x] `GithubSdk` بيحفظ `_client` و `_expiresAt` حوالي ساعة. `reset()` موجودة بس **محدش بيناديها** في أي مكان، و `githubSdkProvider` ([`github_providers.dart:21`](../../lib/features/github/presentation/providers/github_providers.dart#L21)) مش بيتعمله invalidate.
- **السيناريو:** المستخدم A يخرج والمستخدم B يدخل على نفس الجهاز، أو A يقبل دعوة ويتنقل لـ workspace تاني. لحد ما التوكن يخلص، `repositories()` و `issues()` و `pullRequestFiles()` بيستخدموا توكن A، **فـ B بيقرا الـ repos الخاصة بمنظمة A**.
- **الحل:** نادِ `githubSdk.reset()` في `AuthNotifier.signOut()` وفي `CurrentWorkspace` عند أي تغيير، أو خلّي الكاش مربوط بـ `workspaceId + userId`.

## 🟠 14. الـ webhook ممكن يكتب PRs منظمة في workspace تانية

**الملفات:** [`github.go:561-563`](../../backend/internal/api/github.go#L561) و migration `0001_init.sql:292-304`

- [x] `installation_id` مش unique على مستوى الجدول كله، والـ webhook بيختار الـ workspace بـ `limit 1` من غير `order by`. لو نفس التثبيت اتسجل في workspaceين (مثلًا بعد بند 1)، عناوين PRs المنظمة وأسماء الـ authors والـ branches بتتكتب في أي صف SQLite يرجّعه الأول.
- **الحل:** unique index على `github_installations(installation_id)` في migration `0002`.

## 🟠 15. أي عضو يقدر يسجّل قرار العميل قبل العميل نفسه

**الملف:** [`backend/internal/api/decisions.go:32,72`](../../backend/internal/api/decisions.go#L72)

- [x] الـ endpoint بيشترط `requireMember` بس، والشرط الوحيد هو `decidedBy != nil && !role.IsAdmin()`. يعني أول عضو يكتب، حتى لو developer أو reviewer، بيقفل القرار، والعميل (viewer) يترفض بـ `decision_already_recorded`.
- **الحل:** أول كتابة تبقى لـ `role == viewer` بس، والأدمن يقدر يعمل override.

## 🟠 16. العميل (viewer) بيشوف بيانات الفريق كلها

**الملفات:** [`snapshot.go:111-176`](../../backend/internal/api/snapshot.go#L111)، [`members.go:23-30`](../../backend/internal/api/members.go#L23)، [`snapshot.go:640-700`](../../backend/internal/api/snapshot.go#L640)

- [x] كل عضو، ومنهم الـ viewer (العميل الخارجي)، بياخد **إيميل كل الأعضاء** و**سجل الدعوات كله** (إيميلات المقبولين والمنتهيين والمعلّقين ومين اللي دعاهم).
- [x] `hourly_rate` و `invoice_lines` و `invoice_number` بيتبعتوا لكل الأعضاء، فالـ developers بيشوفوا أسعار الساعة.
- **الحل:** الـ snapshot يتبني حسب الدور: شيل `email` و `invites` للـ viewer، والدعوات للأدمن بس، والفلوس للأدمن والعميل بس.

## 🟠 17. `/auth/github/device-token` من غير حد للحجم

**الملف:** [`backend/internal/api/auth_flow.go:34-46,63`](../../backend/internal/api/auth_flow.go#L63)

- [x] `device-code` و `device-token` **مفتوحين من غير مصادقة**، ومفيش rate limit. و `device-token` بيعمل `json.NewDecoder(r.Body)` من غير `MaxBytesReader`، والسيرفر مفيهوش `ReadTimeout`.
- **السيناريو:** طلب JSON بحجم جيجات من غير تسجيل دخول يملا الذاكرة. والـ flood على `device-code` ممكن يخلّص quota الـ device flow بتاعة الـ `client_id` عند GitHub، **فمحدش يقدر يسجّل دخول**.
- **الحل:** `httpx.Decode` أو `http.MaxBytesReader(w, r.Body, 4<<10)`، و rate limit لكل IP.
- (ملحوظة: ده مش open proxy، الـ host والـ path والـ `client_id` ثابتين في السيرفر.)

## 🟠 18. الدعوات من غير حد ولا validation

**الملف:** [`members.go:204-297`](../../backend/internal/api/members.go#L204)

- [x] `emails[]` مالهاش حد أقصى ولا فحص للصيغة. طلب واحد 1MB فيه حوالي 50 ألف إيميل، كلهم بيتكتبوا في transaction واحدة على **الاتصال الوحيد** للـ DB (`SetMaxOpenConns(1)`).
- **السيناريو:** أي مستخدم GitHub هو أدمن على الـ workspace اللي اتعمله تلقائي، فيقدر يوقف الـ API على **كل** الـ tenants، ويبعت إشعارات spam لأي مستخدم موجود بالإيميل.
- **الحل:** حد أقصى ~50، `mail.ParseAddress`، و rate limit لكل workspace.

## 🟠 19. الخروج مش بيعمل revoke للتوكن على GitHub

- [ ] [`github_auth_backend.dart:102-107`](../../lib/features/auth/data/backends/github_auth_backend.dart#L102) بيمسح التوكن من الجهاز بس. التعليق بيقول إن الـ revoke محتاج الـ client secret، بس السر **موجود في الـ backend** ([`github.go:395`](../../backend/internal/api/github.go#L395)).
- **النتيجة:** أي توكن اتسرّب (logcat، backup، HTTP على LAN) بيفضل شغال على GitHub وعلى الـ API بتاعك للأبد. والتعليق في `github_sdk.dart` اللي بيقول إن النسخة المسرّبة "worthless quickly" غلط.
- **الحل:** `POST /v1/auth/signout` والسيرفر ينادي `DELETE /applications/{client_id}/grant`.
- [x] كمان الـ revoke الموجود في السيرفر ([`github.go:216-231`](../../backend/internal/api/github.go#L216)) بيبني الـ JSON بتجميع strings ومش بيشيّك على الـ status، فأي فشل مش بيبان. استخدم `json.Marshal` وسجّل أي رد غير 204.

## 🟡 20. روابط جاية من السيرفر بتتفتح من غير فحص

- [x] `verification_uri` في [`login_page.dart:73-78`](../../lib/features/auth/presentation/pages/login_page.dart#L73) ورابط التثبيت في [`connect_repository_page.dart:48-51`](../../lib/features/github/presentation/pages/connect_repository_page.dart#L48) بيتفتحوا بـ `launchUrl` من غير ما يتأكد من الـ scheme أو الـ host.
- **السيناريو:** مع HTTP على LAN (بند 8)، أي حد على نفس الشبكة يبدّل الرابط بصفحة phishing شكلها GitHub، والـ sheet بتاعة الـ device code بتقول للمستخدم يثق فيها.
- **الحل:** اشترط `uri.scheme == 'https' && uri.host == 'github.com'` قبل `launchUrl`.

## 🟡 21. الـ `Authorization` بيتبعت لأي host

- [x] [`api_client.dart:42`](../../lib/core/network/api_client.dart#L42) بيحط `Bearer` على أي طلب. النهارده كل المسارات `/v1/...` فمفيش مشكلة، بس لو في يوم اتبعت URL كامل جاي من السيرفر (`next`، `avatar`...) التوكن هيروح لدومين تاني.
- **الحل:** حطه بس لو `options.uri.host == Uri.parse(baseUrl).host`.

## 🟡 22. مسار Firebase القديم شغال تلقائي

- [ ] [`auth.go:121`](../../backend/internal/auth/auth.go#L121): بيشتغل لو الـ credentials موجودة، و `VerifyIDToken` مش بيشيّك على التوكنات اللي اتسحبت. لو مشروع Firebase (`apps-41d38`) بيسمح بـ email/password أو anonymous sign-up، أي حد يقدر يطلّع توكن مقبول بإيميل مش مُوثّق، وده بيخلّي بند 3 أسوأ.
- **الحل:** Firebase يبقى مقفول تلقائي، استخدم `VerifyIDTokenAndCheckRevoked`، وحدد تاريخ لشيله.
- [ ] مفتاح Firebase (`AIzaSyALqZ8...`) و OAuth client ids لسه في الـ git history (`google-services.json` في `dfd3a58`/`7c079f5`، اتحذف في `54e8cb0`). مش سر بالمعنى الحرفي، بس المشروع متساب. **اقفل المفتاح أو احذف المشروع من GCP console.**

## 🟡 23. رسائل الأخطاء بتكشف تفاصيل داخلية

- [x] [`httpx.go:96`](../../backend/internal/httpx/httpx.go#L96) بيرجّع `err.Error()` بتاع `encoding/json` للعميل، زي `Go struct field inviteRequest.emails of type []string`. رجّع رسالة عامة وسجّل التفاصيل.

## ⚪ 24. حاجات تانية

- [x] الـ state والـ webhook بيستخدموا نفس مفتاح HMAC على صيغ مختلفة ([`github.go:81`](../../backend/internal/api/github.go#L81)): توقيع الـ state هو `X-Hub-Signature-256` صالح للـ body `v1.<ws>.<uid>.<inst>.<ts>`. مش بيتقبل النهارده بس لأنه مش JSON. افصل المفاتيح (بند 5) وضيف prefix لكل استخدام.
- [ ] ردود GitHub بتتقري من غير حد للحجم (`auth.go:242`، `github.go:211`) — استخدم `io.LimitReader`. وكل `store()` في كاش التوكنات بيلف على الـ map كلها وهو ماسك الـ mutex.
- [ ] الـ developer يقدر يعتمد الـ PR بتاعه (تفاصيل في [04-backend.md](04-backend.md)).
- [ ] الـ CHECK على `workspace_invites.role` بيقبل `'owner'` (migration سطر 59). الـ API بس هو اللي مانع.
- [ ] مفيش حماية من الـ screenshots (`FLAG_SECURE`) على شاشة الـ device code وشاشات الأعضاء والفواتير، ومفيش certificate pinning (اختياري بعد HTTPS).

**اتأكد إنه سليم في المراجعة التانية:** لو مفتاح HMAC فاضي السيرفر مش بيقبل أي توقيع (`GitHubEnabled()` بيشترط `GITHUB_WEBHOOK_SECRET`). مفيش field injection في الـ state (split لـ 6 أجزاء بالظبط والـ ids من غير نقط). مفيش SSRF. مفيش path traversal في الـ routes. مفيش WebView ولا HTML rendering. scopes الـ device flow أقل حاجة (`read:user user:email`). مفيش `ghp_`/`ghs_` ولا private keys في الـ git history.

---

## ✅ حاجات معمولة صح

- مقارنة توقيع الـ state والـ webhook بـ `hmac.Equal` (constant-time)، والـ webhook HMAC على الـ body الخام.
- كل الـ SQL parameterized، ومفيش SQL injection.
- مفيش open redirect: الـ redirect دايمًا لـ github.com.
- فحص ملكية التثبيت صارم: الحساب الشخصي لازم نفس الـ id، والمنظمة لازم عضوية `admin` نشطة.
- الأخطاء غير المتوقعة بتتسجل في الـ log بس، والعميل بياخد 500 عام.
- الـ `client_secret` اتشال من التطبيق.
