# 6DX

تطبيق إدارة مشاريع (Flutter) للموبايل والويب.

- **الهوية:** Firebase Auth (GitHub + بريد/كلمة سر)
- **البيانات:** Go backend على سيرفرك + SQLite (ملف واحد)
- **GitHub:** GitHub App يشتغل عبر الـ backend (المفاتيح لا تصل للجهاز أبداً)

> العربية هي لغة الواجهة الافتراضية (RTL). الكود والتعليقات بالإنجليزية.

## البنية

```
lib/
├── core/
│   ├── config/          # AppConfig (API_BASE_URL)
│   ├── network/          # api_client (توكن Firebase + X-Workspace-Id)
│   │                    # current_workspace
│   ├── errors/          # ServerException / UnauthorizedException
│   └── storage/          # secure storage + local storage
├── features/
│   ├── auth/             # تسجيل الدخول (Firebase Auth / device flow)
│   ├── workspace/        # المساحة + الدعوات + قرارات العميل
│   ├── projects/  tasks/  members/  notifications/  github/
├── firebase_options.dart # مولّد بـ flutterfire configure
└── main.dart

backend/                 # Go API + SQLite  (اقرأ backend/README.md)
```

## التشغيل

```bash
# ١) الـ backend
cd backend
cp .env.example .env     # املأ FIREBASE_PROJECT_ID + ملف service account
go run ./cmd/api         # ينشئ 6dx.db تلقائياً

# ٢) التطبيق
cd ..
flutter pub get
dart run flutterfire configure     # يولّد lib/firebase_options.dart
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` هو عنوان الجهاز من محاكي Android. على جهاز حقيقي استخدم عنوان
الـ LAN، أو رابط السيرفر في الإنتاج.

## إعداد Firebase

1. `console.firebase.google.com` → مشروعك → **Authentication**
2. **Sign-in method** → فعّل **GitHub** و **Email/Password**

> **مهم — SHA-1:** أي APK يدخل بـ Firebase Auth لازم بصمة مفتاح التوقيع تكون
> مسجّلة في المشروع، وإلا يفشل بـ `INVALID_CERT_HASH 400` قبل ما المتصفح يفتح
> (المتصفح يفتح ويقفل في لحظة، وبلا رسالة مفيدة).
>
> المسجَّل حالياً (مفتاح الـ debug الذي يوقّع نسخة الـ beta):
> `95:AA:D3:6D:71:E1:5A:56:E3:B7:66:9D:9D:B6:DF:4D:FD:8C:4E:C1`
>
> قبل نشر نسخة بمفتاح حقيقي، أضف بصمة مفتاحك: Firebase Console →
> Project settings → Your apps → Android → **Add fingerprint**.3. GitHub OAuth App → Authorization callback URL:
   `https://<project>.firebaseapp.com/__/auth/handler`
4. `dart run flutterfire configure` لتوليد `firebase_options.dart`

## إعداد GitHub App

```
Setup URL      https://<domain>/github/setup
Callback URL   https://<domain>/github/callback
Webhook URL    https://<domain>/github/webhook
```

الأسرار في `backend/.env` (`GITHUB_PRIVATE_KEY_FILE` أو PEM مباشر). بلا
الإعدادات دي كل مسارات `/github/*` بترفض والباقي شغّال.

## الاختبارات

```bash
flutter test                                        # 25 اختبار
flutter analyze
cd backend && go test -tags=integration ./internal/api/   # 9 اختبارات
```

CI (`.github/workflows/checks.yml`) يشغّل الثلاثة على كل push.

## المستندات

- [backend/README.md](backend/README.md) — الـ API، الأدوار، النشر، متغيرات البيئة
- [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md) — القرارات المعمارية والقيود
