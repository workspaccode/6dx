# النشر: من المحلي للسيرفر للدومين

كل حاجة متظبطة من الإعدادات. **مفيش أي تعديل في الكود** وانت بتنقل من مرحلة للتانية.

| المرحلة | عنوان الـ API | HTTPS | ملف الإعدادات |
|---|---|---|---|
| **0. محلي** (دلوقتي) | `http://192.168.1.11:8080` | ❌ | `backend/.env` |
| **1. سيرفر بالـ IP** | `http://<server-ip>:8080` | ❌ | `backend/.env` على السيرفر |
| **2. دومين** | `https://api.<domain>` | ✅ تلقائي (Caddy + Let's Encrypt) | نفس الملف + 4 سطور |

> ⚠️ في المرحلتين 0 و 1 الاتصال **مش مشفّر**، يعني توكن GitHub بيتبعت كنص عادي، وأي حد على نفس الشبكة يقدر يشوفه. علشان كده المرحلتين دول **للاختبار بس**، مع ناس من الفريق. ماتدّيش التطبيق لمستخدمين حقيقيين قبل المرحلة 2.

---

## المرحلة 0: محلي

### الـ backend

```bash
cd backend
cp .env.example .env      # أول مرة بس، واملا قيم GitHub
go run ./cmd/api
```

### التطبيق

```bash
# على الموبايل في نفس الشبكة (release)
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.11:8080

# أو للتطوير على الإيموليتر (debug، العنوان الافتراضي 10.0.2.2)
flutter run
```

- **HTTP في نسخة الـ release:** الـ release بقى HTTPS بس افتراضيًا. علشان يكلّم سيرفر بـ HTTP لازم السطر ده يكون موجود في `android/local.properties`. الملف ده خاص بجهازك ومش بيترفع على git، والسطر اتضاف عندك خلاص:
  ```properties
  sixdx.allowCleartext=true
  ```
- **نسخة الـ debug** بتسمح بـ HTTP دايمًا.
- **نسخة release من غير `API_BASE_URL`** بتفتح على شاشة بتقول "النسخة دي اتبنت من غير عنوان السيرفر"، بدل ما تحاول تكلّم localhost وهي ساكتة.

---

## المرحلة 1: سيرفر بالـ IP

**على السيرفر** (Linux، و Docker متسطب):

```bash
git clone <repo> && cd 6dx/backend
cp .env.example .env
mkdir -p secrets   # حط فيه github-app.private-key.pem
```

**في `backend/.env`:**

```env
APP_ENV=development
PUBLIC_BASE_URL=http://<server-ip>:8080
GITHUB_OAUTH_REDIRECT=http://<server-ip>:8080/github/callback
GITHUB_CLIENT_ID=...
GITHUB_CLIENT_SECRET=...
GITHUB_WEBHOOK_SECRET=...           # openssl rand -hex 32
GITHUB_STATE_SECRET=...             # openssl rand -hex 32 (قيمة مختلفة)
```

**التشغيل:**

```bash
docker compose up -d --build
curl http://<server-ip>:8080/health     # {"status":"ok"}
```

**التطبيق:**

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://<server-ip>:8080
```

**إعدادات GitHub App** (github.com → Settings → Developer settings → GitHub Apps):

| الحقل | القيمة |
|---|---|
| Callback URL | `http://<server-ip>:8080/github/callback` |
| Setup URL | `http://<server-ip>:8080/github/setup` |
| Webhook URL | `http://<server-ip>:8080/github/webhook` |

> GitHub بيقبل HTTP في الـ callback، بس بيحذّر منه. ده مقبول للمرحلة دي بس.

**الـ firewall:** افتح البورت 8080 بس.

---

## المرحلة 2: الدومين (HTTPS)

1. **الـ DNS:** اعمل A record لـ `api.<domain>` يشاور على IP السيرفر.
2. **الـ firewall:** افتح 80 و 443، واقفل 8080 من برا.
3. **ضيف في `backend/.env`:**

   ```env
   APP_ENV=production
   API_DOMAIN=api.<domain>
   API_BIND=127.0.0.1
   PUBLIC_BASE_URL=https://api.<domain>
   GITHUB_OAUTH_REDIRECT=https://api.<domain>/github/callback
   CORS_ORIGINS=https://<domain>            # دومين نسخة الويب، لو موجودة
   ```

4. **التشغيل:**

   ```bash
   docker compose --profile https up -d --build
   curl https://api.<domain>/health
   ```

   Caddy بيطلّع شهادة Let's Encrypt ويجددها لوحده.

5. **غيّر الـ 3 روابط في GitHub App** لـ `https://api.<domain>/...`.
6. **التطبيق:** شيل `sixdx.allowCleartext=true` من `android/local.properties`، وابني:

   ```bash
   flutter build apk --release --dart-define=API_BASE_URL=https://api.<domain>
   flutter build appbundle --release --dart-define=API_BASE_URL=https://api.<domain>   # Google Play
   ```

**`APP_ENV=production` بيرفض يشتغل لو** أي حاجة من دول غلط، وبيكتب السبب في الـ log:
- `CORS_ORIGINS=*`.
- `PUBLIC_BASE_URL` أو `GITHUB_OAUTH_REDIRECT` مش `https://`.
- `GITHUB_CLIENT_ID` أو `GITHUB_CLIENT_SECRET` ناقص.
- `GITHUB_STATE_SECRET` فاضي أو هو نفس `GITHUB_WEBHOOK_SECRET`.

**الـ rate limit ورا Caddy:** `TRUSTED_PROXIES` متضبط في `docker-compose.yml` على شبكة الـ containers (`172.30.0.0/24`). علشان كده السيرفر بيقرا IP المستخدم الحقيقي من `X-Forwarded-For`، والـ header ده بيتقبل من Caddy بس. يعني مستخدم من برا مايقدرش يزوّر الـ IP بتاعه.

---

## توقيع نسخة الـ release (قبل Google Play أو أي مستخدم حقيقي)

**اعمل المفتاح مرة واحدة واحفظه في مكان آمن برا الجهاز.** لو ضاع، مش هتقدر تنزّل update للتطبيق تاني.

```bash
keytool -genkey -v -keystore ~/6dx-release.jks -keyalg RSA -keysize 4096 \
        -validity 10000 -alias 6dx
```

`android/key.properties` (مش بيترفع على git):

```properties
storeFile=C:/Users/<you>/6dx-release.jks
storePassword=...
keyAlias=6dx
keyPassword=...
```

لو الملف ده مش موجود، الـ build بيكمّل بمفتاح الـ debug ويطبع تحذير `6DX: android/key.properties missing`.

---

## النسخ الاحتياطي

كل البيانات في ملف SQLite واحد جوه الـ volume `6dx-data`:

```bash
# نسخة متسقة حتى والسيرفر شغال (sqlite3 موجود جوه الـ image)
docker compose exec api sqlite3 /data/6dx.db ".backup /data/backup-$(date +%F).db"
docker compose cp api:/data/backup-$(date +%F).db ./
```

انقل النسخة لبرا السيرفر (S3 أو Google Drive...) كل يوم. وفي المستقبل ممكن [Litestream](https://litestream.io) يعمل replication مستمر.

---

## Firebase

التطبيق بيسجّل الدخول بـ **GitHub device flow**، والسيرفر هو اللي بيتحقق من التوكن مع GitHub. Firebase موجود في الـ backend بس علشان **الجلسات القديمة**، وهو **مقفول افتراضيًا** في `docker-compose.yml`. لو محتاجه:

```env
FIREBASE_PROJECT_ID=apps-41d38
FIREBASE_CREDENTIALS_FILE=/run/secrets/firebase.json
```

وضيف الـ secret في `docker-compose.yml` (`firebase.json: file: ./secrets/firebase-service-account.json`).
