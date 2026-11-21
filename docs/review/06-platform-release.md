# 06 — المنصات والنشر (Android / iOS / Web / macOS / Docker / CI)

ملف جديد من **المراجعة التانية**. الملف ده عن الإعدادات اللي برا الكود: الـ manifest، التوقيع، الـ Docker، والـ CI. مشاكل الحماية في الكود نفسه في [03-security.md](03-security.md).

---

## 🟠 Android

### الـ release موقّع بمفتاح الـ debug

- [ ] [`android/app/build.gradle.kts:36`](../../android/app/build.gradle.kts#L36): `signingConfig = signingConfigs.getByName("debug")`.
  - مفتاح الـ debug خاص بكل جهاز وكلمة سره معروفة (`android`). لو اتمسح، المستخدمين اللي سطّبوا التطبيق **مش هيقدروا يعملوا update**. وأي حد معاه المفتاح يقدر ينزّل "update" مزيف.
  - Google Play هيرفض النسخة.
- **الحل:** اعمل release keystore واقراه من `key.properties` (موجود أصلًا في `.gitignore`)، واحفظ المفتاح في مكان آمن برا الجهاز.
- **(اتجهّز):** الـ gradle بقى بيقرا `android/key.properties` لو موجود، ولو مش موجود بيطبع تحذير. فاضل إنك تعمل المفتاح نفسه، والخطوات في [docs/deploy.md](../deploy.md).

### scheme الـ Supabase القديم لسه متسجل

- [x] [`AndroidManifest.xml:35-40`](../../android/app/src/main/AndroidManifest.xml#L35) بيسجّل `io.supabase.flutter://login-callback`، و [`ios/Runner/Info.plist:52-62`](../../ios/Runner/Info.plist#L52) بيسجّل `io.supabase.flutter`. والـ `app_links` في الـ pubspec ومش مستخدم.
  - الـ scheme ده عام ومشترك بين كل التطبيقات اللي اتعملت من template الـ Supabase. ومع الـ deep linking اللي Flutter بيشغّله تلقائي، أي موقع أو تطبيق يقدر يدخّل مسارات go_router للتطبيق (`/states/*`، `/invite/accept`، `/github/*`).
- **الحل:** احذف التسجيلين، واقفل `flutter_deeplinking_enabled` لحد ما يبقى فيه App Links / Universal Links متوثّقة بدومين حقيقي.

### الـ backup مش متضبط

- [x] `android:allowBackup` و `dataExtractionRules` مش متحددين ([`AndroidManifest.xml:10`](../../android/app/src/main/AndroidManifest.xml#L10))، فالـ backup شغال تلقائي.
  - ملف الـ `EncryptedSharedPreferences` بيترجع على جهاز جديد **من غير** مفتاح الـ Keystore، فالقراية بتفشل والخطأ بيتبلع، والمستخدم بيخرج من غير سبب واضح (أو التطبيق بيقع، وده bug معروف).
- **الحل:** `android:allowBackup="false"`، أو استثني `FlutterSecureStorage` من الـ backup.

### HTTP غير مشفر

- [x] `192.168.1.11` مسموح بـ cleartext في نسخة الـ release. التفاصيل في [03-security.md](03-security.md) بند 8.

### مفيش حماية من الـ screenshots

- [ ] مفيش `FLAG_SECURE` على شاشة الـ device code ولا شاشات الأعضاء والفواتير، فالمحتوى بيظهر في الـ recents وفي تسجيل الشاشة. فعّله على الشاشات الحساسة بس.

---

## 🟡 iOS

- [ ] بيانات الـ keychain بتفضل موجودة بعد مسح التطبيق، لأن `IOSOptions` الافتراضية مستخدمة ([`secure_storage_service.dart:9-11`](../../lib/core/storage/secure_storage_service.dart#L9)). لو المستخدم مسح التطبيق وسطّبه تاني، **هيدخل أوتوماتيك بحساب المستخدم اللي قبله**. امسح الـ keychain أول مرة التطبيق يشتغل، بـ flag في `SharedPreferences`.
- [x] scheme الـ Supabase متسجل في `Info.plist` (فوق).

---

## 🟡 Web

- [ ] **التوكن عمليًا plaintext:** `flutter_secure_storage_web` 1.2.1 بيحط مفتاح الـ AES جنب الـ ciphertext في localStorage. أي XSS أو extension خبيثة تقرا توكن GitHub.
- [ ] **مفيش CSP** في [`web/index.html`](../../web/index.html).
- **الحل:**
  - على المدى القريب: CSP صارم في `<meta>`، مثلًا `default-src 'self'; connect-src <api> https://api.github.com`.
  - على المدى البعيد: الـ backend يطلّع session cookie (`HttpOnly`، `Secure`، `SameSite`) للويب بدل ما توكن GitHub نفسه يتخزن في المتصفح.

---

## 🟡 macOS

- [ ] `macos/Runner/Release.entitlements` و `DebugProfile.entitlements` مفيهمش `com.apple.security.network.client`، فكل طلبات الـ API و GitHub هتفشل جوه الـ sandbox.
- [ ] مفيش keychain access group، فالـ secure storage ممكن يفشل.
- **الحل:** ضيف `network.client` و `keychain-access-groups`.

---

## 🟠 Docker

**الملف:** [`backend/Dockerfile`](../../backend/Dockerfile)

- [x] **مفيش `.dockerignore`**، و `COPY . .` (سطر 10) بيدخّل `secrets/*.pem` ومفتاح الـ service account بتاع Firebase و `.env` و `6dx.db` في layers الـ build stage وفي الـ builder cache. أي حد يوصل للـ cache أو للـ registry لو الـ build stage اتعمله push يقدر يقرا الأسرار.
- [x] `golang:1.23-alpine` (سطر 2) أقدم من `go 1.26.0` اللي في `go.mod`، فكل build بينزّل toolchain.
- [x] `alpine:3.20` (سطر 13) خلص دعمه في أبريل 2026، ومبقاش بياخد security patches.
- **الحل:**

```dockerignore
# backend/.dockerignore
.env
.env.*
!.env.example
secrets/
*.db
*.db-*
*.pem
.git
```

واستخدم `golang:1.26-alpine` وصورة runtime مدعومة (alpine حديثة أو `gcr.io/distroless/static`).

---

## 🟡 الـ CI

**الملف:** [`.github/workflows/checks.yml`](../../.github/workflows/checks.yml). المشاكل الأساسية (الفرع وإصدار Flutter) في [05-future-risks.md](05-future-risks.md).

- [ ] الـ actions متثبّتة بالـ tag مش بالـ SHA، ومنها action من طرف تالت (`subosito/flutter-action@v2`). لو الـ tag اتنقل لكود خبيث هيتنفذ في الـ CI.
- [x] مفيش block `permissions:`، فالـ `GITHUB_TOKEN` واخد الصلاحيات الافتراضية.
- [ ] مفيش `govulncheck` ولا `flutter analyze` بـ `--fatal-infos`.
- **الحل:**

```yaml
permissions:
  contents: read
```

وثبّت كل action بالـ SHA الكامل، مع تعليق فيه رقم الإصدار.

**معمول صح:** الـ workflow بيستخدم `pull_request` مش `pull_request_target`، ومش بيستخدم أي secrets.

---

## ⚪ الأسرار والحسابات القديمة

- [ ] مفتاح Firebase API (`AIzaSyALqZ8...`، المشروع `apps-41d38`) و OAuth client ids لسه في الـ git history (`google-services.json` في commits `dfd3a58` و `7c079f5`، واتحذف في `54e8cb0`).
  - المفتاح ده مش سر بالمعنى الحرفي، بس المشروع متساب، والمفتاح مش متقيّد غير لو حد قفله.
  - **الحل:** قيّد المفتاح أو احذفه من GCP console، أو احذف مشروع Firebase كله. ولو Firebase Auth لسه شغال فيه، اقفل email/password و anonymous sign-up (شوف [03-security.md](03-security.md) بند 22).

**اتأكد إنه سليم:** مجلد `secrets/` و `.env` و `6dx.db` في `.gitignore`، ومظهروش في الـ git history. ومفيش توكنات `ghp_`/`ghs_` ولا private keys.
