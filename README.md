# 6DX

تطبيق إدارة مشاريع (Flutter) للموبايل والويب وسطح المكتب.

- **الهوية:** GitHub فقط — OAuth Device Flow (نفس الطريقة على Android وiOS وmacOS
  وWindows وLinux والويب)
- **البيانات:** Go backend على سيرفرك + SQLite (ملف واحد)
- **GitHub:** GitHub App يشتغل عبر الـ backend (المفاتيح لا تصل للجهاز أبداً)

> العربية هي لغة الواجهة الافتراضية (RTL). الكود والتعليقات بالإنجليزية.

## البنية

```
lib/
├── core/
│   ├── config/          # AppConfig (API_BASE_URL)
│   ├── layout/          # breakpoints + ResponsiveLayout (هاتف/سطح مكتب)
│   ├── network/          # api_client (توكن GitHub + X-Workspace-Id)
│   │                    # current_workspace
│   ├── errors/          # ServerException / UnauthorizedException
│   └── storage/          # secure storage + local storage
├── features/
│   ├── auth/             # تسجيل الدخول (GitHub device flow)
│   ├── workspace/        # المساحة + الدعوات + قرارات العميل
│   ├── projects/  tasks/  members/  notifications/  github/
└── main.dart

backend/                 # Go API + SQLite  (اقرأ backend/README.md)
```

## سطح المكتب (Windows / macOS / Linux)

الواجهة واحدة على كل المنصات وتتكيّف مع عرض النافذة:

| العرض | التخطيط |
| --- | --- |
| أقل من 700 | هاتف: شريط تنقّل سفلي وحواف 20 |
| 700 – 1099 | سطح مكتب ضيّق: شريط جانبي بالأيقونات فقط |
| 1100 وأكثر | سطح مكتب: شريط جانبي بالعناوين + محتوى بعرض أقصى 1180 |

- نافذة سطح المكتب تفتح بـ 1280×800 ولا تصغر عن 900×600 (`AppBreakpoints`).
- اختصارات: `Ctrl/⌘ + 1–4` للتنقّل بين الأقسام، و`Ctrl/⌘ + K` للبحث.
- `AppScreen` في `shared/widgets/ui_kit.dart` يوسّط المحتوى ويقصّه عند 1180 على
  سطح المكتب، ويُبقي حواف الهاتف كما هي.

## التشغيل

```bash
# ١) الـ backend
cd backend
cp .env.example .env     # املأ GITHUB_CLIENT_ID (وفعّل Device Flow في التطبيق)
go run ./cmd/api         # ينشئ 6dx.db تلقائياً

# ٢) التطبيق
cd ..
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` هو عنوان الجهاز من محاكي Android. على جهاز حقيقي استخدم عنوان
الـ LAN، أو رابط السيرفر في الإنتاج. على سطح المكتب والويب استخدم
`http://localhost:8080`.

## إعداد تسجيل الدخول

الدخول بـ **GitHub فقط** عبر Device Flow. الإعداد مرة واحدة:

1. `github.com/settings/developers` → تطبيقك (OAuth App أو GitHub App)
2. فعّل **Enable Device Flow** — بدونه GitHub يرد `device_flow_disabled`
3. ضع الـ **Client ID** في `backend/.env` (`GITHUB_CLIENT_ID`)

الـ client id يبقى على السيرفر: الـ backend يعمل proxy لنقطتي الجهاز
(`/auth/github/device-code` و `/auth/github/device-token`) لأن `github.com`
لا يرسل ترويسات CORS، وبكده نفس التسجيل يشتغل في بناء الويب.

المستخدم بيدخل كود من 6 خانات على `github.com/login/device`، وبعد الموافقة
التطبيق يحفظ الـ token في التخزين المشفّر ويرسله مع كل طلب. الـ API بيتحقق منه
عبر GitHub ويحفظ النتيجة 5 دقائق.

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
