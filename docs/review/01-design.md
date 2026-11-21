# 01 — مشاكل التصميم

الملف ده فيه جزئين:
1. **تصميم الواجهة (UI/UX):** اللي المستخدم بيشوفه.
2. **تصميم الكود (المعمارية):** طريقة تنظيم الكود اللي هتتعبك وانت بتطوّر.

---

## الجزء الأول: الواجهة

### 🟠 أزرار شكلها شغال وهي مش بتعمل حاجة

أخطر مشكلة في التجربة: المستخدم يدوس، الشاشة تتقفل أو مفيش حاجة تحصل، ومفيش أي تغيير على السيرفر. الـ endpoints موجودة وجاهزة في الـ backend، بس التطبيق مش بيناديها.

- [ ] **حذف عضو / تغيير صلاحيته:** كل الأزرار بتعمل `pop()` بس — [`member_pages.dart:109-134`](../../lib/features/members/presentation/pages/member_pages.dart#L109). `DELETE /v1/members/{uid}` مش بيتنادى. "تغيير الصلاحية" (`:185`)، زر الدعوة (`:31`)، إعادة الإرسال (`:335`)، ونسخ اللينك (`:342`) كلهم `() {}`.
- [ ] **اعتماد ودمج PR:** [`review_pages.dart:165`](../../lib/features/reviews/presentation/pages/review_pages.dart#L165) → `() {}`. الدالة `reviewPullRequest` موجودة في `workspace_remote_data_source.dart` بس مفيش provider بيستخدمها.
- [ ] **قرار العميل / اعتماد الوقت:** [`client_pages.dart:81,90,344`](../../lib/features/clients/presentation/pages/client_pages.dart#L81) → `() {}`. `submitClientDecision` و `approveTimeEntries` مش متوصلين.
- [ ] **تعليم الإشعارات كمقروءة:** [`notifications_page.dart:27`](../../lib/features/notifications/presentation/pages/notifications_page.dart#L27) → `() {}`.
- [ ] **أرشفة المشروع:** [`project_settings_pages.dart:460,497`](../../lib/features/projects/presentation/pages/project_settings_pages.dart#L460) → `() {}`. `archiveProjectProvider` مالوش أي مستخدم.
- [ ] **تعديل المهمة:** حفظ وحذف في [`task_flow_pages.dart:77,84`](../../lib/features/tasks/presentation/pages/task_flow_pages.dart#L77) → `() {}`.
- [ ] **مهمة جديدة:** [`new_task_page.dart:43-48`](../../lib/features/tasks/presentation/pages/new_task_page.dart#L43) بتقفل الصفحة حتى لو الإنشاء فشل. وبتبعت العنوان بس: المشروع، المسؤول، النقاط، والتاريخ بيضيعوا. أزرار +/- للنقاط (`:193`) مش شغالة.
- [ ] **التعليقات والمهام الفرعية:** [`task_detail_page.dart:119`](../../lib/features/tasks/presentation/pages/task_detail_page.dart#L119) و [`task_extras_page.dart:70`](../../lib/features/tasks/presentation/pages/task_extras_page.dart#L70): `TextField` لوحده من غير أي إرسال.
- [ ] **روابط الـ sidebar في الويب:** [`web_shell_page.dart:103`](../../lib/features/web/presentation/pages/web_shell_page.dart#L103) → `onTap: () {}`.
- [ ] **كارت الدعوة في صفحة المشاريع:** أزرار قبول/رفض [`projects_page.dart:230,239`](../../lib/features/projects/presentation/pages/projects_page.dart#L230) → `() {}`.

> **اقتراح:** اعمل grep على `() {}` في `lib/features` وخلّي أي زر مش جاهز `onPressed: null` (يظهر disabled) بدل ما يخدع المستخدم.

### 🟠 الأخطاء بتظهر كأنها "مفيش بيانات"

- [ ] [`task_providers.dart:56,63,71`](../../lib/features/tasks/presentation/providers/task_providers.dart#L56): لو حصل خطأ في `build`/`refresh`/`filterByProject` بيرجع `[]`. يعني النت لو قطع المستخدم هيشوف "لا توجد مهام".
- [ ] [`project_providers.dart:52`](../../lib/features/projects/presentation/providers/project_providers.dart#L52): نفس الكلام في المشاريع.
- [ ] `workspaceSnapshotProvider` بيرجع snapshot فاضي لو حصل خطأ. الخطأ نفسه بيتحط في `workspaceErrorProvider` بس **مفيش شاشة بتقراه**، ومش بيتمسح.
- [ ] الدعوات المعلّقة: لو حصل خطأ بيظهر "لا توجد دعوة" — [`workspace_flow_pages.dart:123-129`](../../lib/features/workspace/presentation/pages/workspace_flow_pages.dart#L123).
- [ ] حذف المهمة [`task_detail_page.dart:47`](../../lib/features/tasks/presentation/pages/task_detail_page.dart#L47): من غير تأكيد، ومن غير رجوع، والصفحة بتتحول لـ "المهمة غير موجودة". ولو الحذف فشل مفيش أي رسالة.
- [ ] لوحة المهام: `grouped.isEmpty` عمرها ما هتبقى true (دايمًا فيها 4 مفاتيح)، فالـ loader مش بيظهر خالص — [`task_board_page.dart:39`](../../lib/features/tasks/presentation/pages/task_board_page.dart#L39).

> **اقتراح:** خلّي الـ notifiers ترمي `AsyncError` بدل `[]`، واستخدم `ErrorState` الموجود في `shared/widgets/app_states.dart` مع زر "إعادة المحاولة".

### 🟠 الثيم الفاتح مكسور

- [ ] في زر لتبديل الثيم ([`account_pages.dart:51`](../../lib/features/account/presentation/pages/account_pages.dart#L51))، بس **98 مكان** في `lib/features` و `lib/shared` بيستخدموا ألوان ثابتة من [`app_colors.dart`](../../lib/core/constants/app_colors.dart) معمولة للثيم الداكن بس، زي `AppColors.text` (`#E8EAF0`، فاتح جدًا)، `AppColors.surface`، و `AppColors.border`.
  - **النتيجة في الوضع الفاتح:** نص فاتح على خلفية بيضا، وكروت داكنة وسط صفحة فاتحة.
  - **الحل:** استخدم `Theme.of(context).colorScheme.*` أو اعمل `ThemeExtension` للألوان المخصوصة، وخلّي `AppColors` يتقري من الثيم الحالي.

### 🟡 بيانات وهمية لسه ظاهرة في الشاشات

| المكان | القيمة الوهمية |
|---|---|
| [`task_detail_page.dart:92`](../../lib/features/tasks/presentation/pages/task_detail_page.dart#L92) | `'غدًا · 5 نقاط'` |
| [`task_detail_page.dart:99`](../../lib/features/tasks/presentation/pages/task_detail_page.dart#L99) | رقم PR افتراضي `'58'`، فأي مهمة من غير PR بتفتح PR #58 |
| [`task_detail_page.dart:255-271`](../../lib/features/tasks/presentation/pages/task_detail_page.dart#L255) | `'4/4 فحوصات'`، build/tests/lint ✓، `'+312 −48'` |
| [`task_detail_page.dart:111`](../../lib/features/tasks/presentation/pages/task_detail_page.dart#L111) | النشاط بيعرض نشاط مساحة العمل كلها مش المهمة |
| [`task_board_page.dart:102,113`](../../lib/features/tasks/presentation/pages/task_board_page.dart#L102) | `'تطبيق المتجر'`، `'Sprint 4 · 3 أيام متبقية'`، `'تمت المزامنة منذ دقيقة'` |
| [`task_views_page.dart:22,96,100`](../../lib/features/tasks/presentation/pages/task_views_page.dart#L22) | `'تطبيق المتجر'`، `'Sprint 4 ينتهي الخميس — 11 مهمة'` |
| [`projects_page.dart:353`](../../lib/features/projects/presentation/pages/projects_page.dart#L353) | `'3 PR مفتوحة · 2 بانتظار مراجعتك'` |
| [`home/.../reviews_page.dart:58`](../../lib/features/home/presentation/pages/reviews_page.dart#L58) | `'4/4 فحوصات'` |
| [`review_pages.dart:14,305`](../../lib/features/reviews/presentation/pages/review_pages.dart#L14) | `prNumber = 58` افتراضي، `'قبل 3 ساعات'` |
| [`state_pages.dart:409`](../../lib/features/workspace/presentation/pages/state_pages.dart#L409) | `'PR #58'` |
| [`member_pages.dart:329`](../../lib/features/members/presentation/pages/member_pages.dart#L329) | `'أُرسلت أمس · لم تُفتح بعد'` |

- [ ] شيل القيم دي أو اربطها بالبيانات الحقيقية.
- [ ] [`test/no_fake_data_test.dart`](../../test/no_fake_data_test.dart) بيختبر الـ providers بس ومش بيعمل build لأي widget، فكل اللي فوق بيعدّي منه. ضيف اختبار بيعمل scan على `lib/features/**/pages` للقيم دي (`'58'`، `'Sprint 4'`، `'4/4'`، ...).

### 🟡 منطق عرض غلط

- [ ] [`sprint_pages.dart:209`](../../lib/features/sprints/presentation/pages/sprint_pages.dart#L209): `Text('بدء $sprint.name')` بيظهر **"بدء Instance of 'Sprint'.name"**. الصح: `'بدء ${sprint.name}'`.
- [ ] الـ Backlog بيعرض `sprints.first.items` (أقدم sprint) بدل المهام اللي مش في أي sprint — [`sprint_pages.dart:19`](../../lib/features/sprints/presentation/pages/sprint_pages.dart#L19).
- [ ] ملخص الـ Sprint بيعتبر أي عنصر عنده نقاط `> 0` "مكتمل" (`sprint_pages.dart:241`).
- [ ] فلتر المشاريع: الـ chips بتغيّر الفلتر بس القائمة بتستخدم `allProjects` مش `filteredProjectsProvider` — [`projects_page.dart:37-41`](../../lib/features/projects/presentation/pages/projects_page.dart#L37). كمان أسماء الفلاتر ("أنا المالك"/"مشارك") مش مطابقة للـ enum (`active`/`archived`)، والأعداد كلها `allProjects.length`.
- [ ] كارت الدعوة في صفحة المشاريع بيظهر لما مساحة العمل **باعتة** دعوات، فالأدمن نفسه بيشوف "لديك دعوة للانضمام" (`projects_page.dart:125`).
- [ ] "المستحق" في بوابة العميل بيعرض `hourlyRate` بدل الإجمالي (`client_pages.dart` حوالين سطر 213).
- [ ] "مهامي" بتعرض كل مهام مساحة العمل مش مهام المستخدم.
- [ ] ألوان الـ labels كلها رمادي، لأن السيرفر بيبعت hex string والتطبيق بيقراه int — [`workspace_snapshot_mapper.dart:176`](../../lib/features/workspace/data/models/workspace_snapshot_mapper.dart#L176). (تفاصيل في [04-backend.md](04-backend.md)).

### 🟡 الترجمة (l10n)

- [ ] حوالي **946 نص عربي مكتوب مباشرة** في الكود، مقابل **4 استخدامات** بس لـ `context.l10n` (في projects و notifications و profile).
  - **النتيجة:** زر تغيير اللغة لـ English تقريبًا مالوش أي تأثير.
  - **الحل:** انقل النصوص تدريجيًا لـ `lib/l10n/app_ar.arb` و `app_en.arb`، وابدأ بالشاشات الأساسية (الدخول، المشاريع، المهام).
- [ ] رسائل الأخطاء في `api_client.dart` و `github_auth_data_source.dart` عربي ثابت. الأفضل الـ data layer يرجّع **كود** والـ UI هو اللي يترجم.

---

## الجزء التاني: تصميم الكود (المعمارية)

### 🟡 مصدر بيانات مزدوج

- [ ] في طريقين للبيانات في نفس الوقت:
  - `workspaceSnapshotProvider`: endpoint واحد بيرجّع كل حاجة.
  - `tasksNotifierProvider` و `projectsNotifierProvider`: endpoints منفصلة.
- **النتيجة:** لما تعمل مهمة جديدة بتتضاف في `tasksNotifier`، بس الشاشات اللي بتقرا من الـ snapshot (المراجعات، الـ sprints، العميل) مش بتتحدث.
- **الحل:** اختار مصدر واحد لكل نوع بيانات، أو اعمل `ref.invalidate(workspaceSnapshotProvider)` بعد أي كتابة.

### 🟡 Riverpod

- [ ] مفيش أي `ref.mounted` بعد الـ `await` في `create`/`updateStatus`/`remove`/`refresh`. في Riverpod 3 لو الـ provider اتعمله dispose (مثلًا تسجيل خروج في نص الطلب) الكتابة على `state` هترمي exception.
- [ ] الـ providers مش بتتعمل invalidate عند تغيير المستخدم: `currentWorkspaceProvider` و `apiClientProvider` بيعتمدوا على `secureStorageProvider` بس، فمش بيتعادوا لما الجلسة تتغير.

### ⚪ كود ميت ومكرر

- [ ] `lib/routes/auto_router_config.dart` فيه **13** route بس مقابل **86** `GoRoute` في go_router. ده إعداد AutoRoute ميت ومش متزامن، وبيزوّد dependency و codegen. **احذفه** هو و `auto_route` و `auto_route_generator` من `pubspec.yaml` و `@RoutePage()` من الصفحات.
- [ ] `isSignedInProvider` و `archiveProjectProvider` والدوال `reviewPullRequest`/`approveTimeEntries`/`submitClientDecision` مش مستخدمين (يا إما تربطهم يا تحذفهم).
- [ ] دالة `_guard` متكررة في كل repository بشكل مختلف. حطها في مكان واحد (`core/utils/result.dart`).
- [ ] ملفات صفحات ضخمة فيها صفحات كتير مع بعض (`insight_pages.dart` 791 سطر، `workspace_flow_pages.dart` 650 سطر). قسّمها: صفحة في كل ملف.
- [ ] بعض الملفات بتبدأ بـ BOM (`﻿`) زي `app_router.dart` و `app_endpoints.dart`. احفظها UTF-8 من غير BOM.
