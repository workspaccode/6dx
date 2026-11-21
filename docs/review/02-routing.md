# 02 — مشاكل الراوت (go_router)

كل الكلام هنا عن [`lib/routes/app_router.dart`](../../lib/routes/app_router.dart). فيه **86** `GoRoute`.

---

## 🟠 ترتيب المسارات: `/tasks/bulk` بيفتح صفحة مهمة اسمها "bulk"

- [ ] `taskDetail = '/tasks/:id'` متعرّف في [سطر 268](../../lib/routes/app_router.dart#L268)، و `bulkActions = '/tasks/bulk'` في [سطر 522](../../lib/routes/app_router.dart#L522).
- go_router بيطابق بالترتيب، فـ `/tasks/bulk` بيتطابق مع `:id` الأول و `TaskDetailPage(taskId: 'bulk')` هي اللي بتفتح.
- التعليق في [سطر 249](../../lib/routes/app_router.dart#L249) بيقول إن المسارات الثابتة لازم تيجي قبل `:id`، وده اتعمل لـ `new`/`list`/`calendar`/`search` بس، و `bulk` اتنسي.
- **الحل:** انقل `GoRoute(path: AppRoutes.bulkActions, ...)` فوق `taskDetail`.

## 🟠 مسارات فيها `:id` مش بتبعت الـ id للصفحة

- [ ] `editTask` (`/tasks/:id/edit`)، `taskStatus` (`/tasks/:id/status`)، `taskDependencies` (`/tasks/:id/dependencies`)، و `taskContext` (`/tasks/:id/context`) — [سطور 501-516](../../lib/routes/app_router.dart#L501).
- كلهم `builder: (_, __) => const EditTaskPage()` من غير `state.pathParameters['id']`، فالصفحة متعرفش هي بتعدّل أنهي مهمة.
- كمان دول متعرّفين **top-level**، مع إن `/tasks/:id` عنده `routes:` (`subtasks` و `comments`). خليهم sub-routes تحت `taskDetail` زي `subtasks`:

```dart
GoRoute(
  path: AppRoutes.taskDetail,
  builder: ...,
  routes: [
    GoRoute(path: 'subtasks', ...),
    GoRoute(path: 'comments', ...),
    GoRoute(
      path: 'edit',
      builder: (context, state) =>
          EditTaskPage(taskId: state.pathParameters['id']!),
    ),
    GoRoute(path: 'status', ...),
    GoRoute(path: 'dependencies', ...),
    GoRoute(path: 'context', ...),
  ],
),
```

## 🟡 قيم افتراضية وهمية في الراوت

- [ ] [سطر 289](../../lib/routes/app_router.dart#L289): `taskKey: state.pathParameters['id'] ?? 'MOB-24'`.
- [ ] [سطر 309](../../lib/routes/app_router.dart#L309): `prNumber: int.tryParse(...) ?? 58`. أي رقم PR غلط في الرابط بيفتح PR #58.
- [ ] [سطر 276-282](../../lib/routes/app_router.dart#L276): `subtasks` بيقرا المهمة من `ref.read(tasksNotifierProvider).value`، ولو مش موجودة بيعمل `Task(id: id, title: 'مهمة')` وهمية. لو المستخدم فتح الرابط مباشرة (deep link / refresh في الويب) هيشوف مهمة فاضية.
- **الحل:** لو الـ parameter غلط روّح لصفحة `notFound` بدل قيمة وهمية، واقرا المهمة جوه الصفحة نفسها بـ provider family (`taskByIdProvider(id)`).

## 🟠 الـ redirect مش بيتفاعل مع تغيّر الجلسة

- [x] [سطر 153](../../lib/routes/app_router.dart#L153): `ref.read(authNotifierProvider)` ومفيش `refreshListenable`.
  - go_router بينفّذ الـ redirect بس عند التنقل، فلو التوكن انتهى أو السيرفر رجّع 401 المستخدم بيفضل جوه التطبيق.
  - تسجيل الخروج شغال بس لأن [`profile_page.dart`](../../lib/features/profile/presentation/pages/profile_page.dart) بيعمل `context.go(login)` يدوي.
- [x] الـ `ApiClient` بيحوّل الـ 401 لـ `UnauthorizedException`، بس محدش بيعمل `authNotifier.signOut()` / `invalidate` بعدها.
- **الحل:**

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authNotifierProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      // ...
    },
    // ...
  );
});
```

وفي الـ `ApiClient` لما ييجي 401: امسح التوكن ونادِ `ref.invalidate(authNotifierProvider)`.

## 🟡 السبلاش ممكن يعلّق

- [ ] [سطر 590](../../lib/routes/app_router.dart#L590): `SplashPage` بيعتمد على `ref.listen` بس. الـ `listen` مش بيشتغل على القيمة الحالية، فلو `authNotifierProvider` كان خلص تحميل قبل ما السبلاش يتبني (مثلًا رجعت لـ `/`) الشاشة هتفضل spinner على طول.
- **الحل:** الأسهل تشيل منطق السبلاش من الصفحة وتخلّي الـ `redirect` هو اللي يقرر (`/` + loaded → `/home` أو `/onboarding`). أو استخدم `ref.watch` وقرّر في `build` بـ `addPostFrameCallback`.
- [ ] الـ onboarding بيظهر في كل مرة المستخدم مش مسجّل، لأن `setOnboardingDone` عمره ما بيتنادى.

## 🟡 مفيش errorBuilder، وصفحات الويب مش بتفتح

- [x] مفيش `errorBuilder` في `GoRouter(...)`، فأي مسار غلط بيطلع صفحة الخطأ الافتراضية بتاعة go_router (إنجليزي ورمادي). عندك صفحة جاهزة `NotFoundPage` في `state_pages.dart`، استخدمها:

```dart
errorBuilder: (context, state) => const NotFoundPage(),
```

- [ ] مسار الويب [سطر 562](../../lib/routes/app_router.dart#L562) متعرّف كـ `path: '/web'` من غير sub-routes. go_router بيطابق المسار كله، فـ `/web/pricing` و `/web/help` **مش هيتطابقوا** ويروحوا لصفحة الخطأ. يعني من 51 شاشة ويب في [`web_routes.dart`](../../lib/features/web/presentation/pages/web_routes.dart) بتفتح بس الصفحة الرئيسية.
  - **الحل:** `path: '/web/:page(.*)'` أو اعمل `GoRoute` لكل صفحة ويب تحت `/web`.
  - كمان مفيش ولا مكان في التطبيق بيعمل `go('/web...')`، وروابط الـ sidebar في الويب `() {}`.

## 🟡 مفيش حراسة حسب الصلاحية

- [ ] الـ redirect بيفرّق بين مسجّل/مش مسجّل بس. العميل (client) أو المشاهد (viewer) يقدر يفتح `/projects/settings`، `/projects/members`، `/projects/archive`، و `/settings/billing`. السيرفر هيرفض الكتابة، بس المستخدم هيشوف شاشات وأزرار مش من حقه.
- **الحل:** اقرا `role` من الـ snapshot واعمل guard للمسارات الإدارية (روّح لـ `NoPermissionPage` الموجودة).

## ⚪ تنظيم

- [ ] مسارات `/states/*` (offline, skeleton, not-found, push-permission...) شاشات تصميم معمولة routes. دي المفروض **حالات** بتظهر جوه الشاشات، مش صفحات المستخدم يقدر يروحلها بلينك. خليها widgets، أو حطها ورا `kDebugMode`.
- [ ] الملف 600 سطر و 86 route في قائمة واحدة. قسّمه حسب الـ feature: `tasksRoutes`، `projectRoutes`، `reviewRoutes`... كل واحدة `List<RouteBase>` في ملف الـ feature بتاعها.
- [ ] الـ deep link بيضيع بعد الدخول: لو المستخدم مش مسجّل وفتح `/tasks/123` بيروح `/login`، وبعد الدخول بيروح `/home` مش `/tasks/123`. ابعت المسار الأصلي كـ `?from=` وارجعله بعد الدخول.
- [x] **(المراجعة التانية) أي تطبيق تاني يقدر يفتح مسارات جوه التطبيق:** scheme الـ Supabase القديم (`io.supabase.flutter`) لسه متسجل في Android و iOS، والـ deep linking بتاع Flutter شغال تلقائي. يعني أي موقع أو تطبيق يقدر يبعت `/states/*` أو `/invite/accept` أو `/github/*`. ومع إن مفيش حراسة حسب الصلاحية (فوق)، ده بيكبّر المشكلة. تفاصيل في [06-platform-release.md](06-platform-release.md).
- [ ] `auto_router_config.dart` فيه 13 route بس ومش متزامن مع go_router. احذفه (تفاصيل في [01-design.md](01-design.md)).
