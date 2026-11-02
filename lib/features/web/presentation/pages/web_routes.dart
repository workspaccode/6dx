/// The public website + web app screens, in the order of the design export.
///
/// Every entry is a real route: `/web/<path>`.
class WebRoute {
  const WebRoute({
    required this.path,
    required this.title,
    required this.section,
    this.description,
    this.isMarketing = false,
  });

  final String path;
  final String title;
  final String section;
  final String? description;
  final bool isMarketing;
}

const List<WebRoute> webRoutes = [
  // الموقع والتسويق
  WebRoute(
    path: '',
    title: '6DX — فريقك ومهامك ومستودعك في مكان واحد',
    section: 'الموقع والتسويق',
    isMarketing: true,
    description: 'أنشئ مشروعًا، اربطه بمستودع GitHub، ادعُ فريقك، '
        'ووزّع المهام وتابعها من الـ PR حتى الدمج.',
  ),
  WebRoute(
    path: 'pricing',
    title: 'الأسعار والمقارنة',
    section: 'الموقع والتسويق',
    isMarketing: true,
    description: 'خطط مرنة للمشاريع الصغيرة والفرق الكبيرة.',
  ),
  WebRoute(
    path: 'agencies',
    title: 'page الوكالات',
    section: 'الموقع والتسويق',
    isMarketing: true,
    description: 'لوكالات البرمجة: workspaces لكل عميل، فوترة، وتقارير أسبوعية.',
  ),
  WebRoute(
    path: 'help',
    title: 'المساعدة وما الجديد',
    section: 'الموقع والتسويق',
    isMarketing: true,
  ),
  // الحساب والدخول
  WebRoute(path: 'login', title: 'تسجيل الدخول', section: 'الحساب والدخول'),
  WebRoute(path: 'signup', title: 'إنشاء حساب', section: 'الحساب والدخول'),
  WebRoute(path: 'verify', title: 'كود التحقق', section: 'الحساب والدخول'),
  WebRoute(path: 'onboarding', title: 'إعداد مساحة العمل', section: 'الحساب والدخول'),
  WebRoute(path: 'accept-invite', title: 'قبول الدعوة', section: 'الحساب والدخول'),
  WebRoute(path: 'invite-expired', title: 'دعوة منتهية', section: 'الحساب والدخول'),
  WebRoute(path: 'profile', title: 'الملف الشخصي والتفضيلات', section: 'الحساب والدخول'),
  WebRoute(path: 'workspace-admin', title: 'إدارة مساحة العمل', section: 'الحساب والدخول'),
  // المشاريع والربط بـ GitHub
  WebRoute(path: 'projects', title: 'المشاريع', section: 'المشاريع والربط'),
  WebRoute(path: 'projects/new', title: 'مشروع جديد', section: 'المشاريع والربط'),
  WebRoute(path: 'projects/repositories', title: 'ربط المستودعات', section: 'المشاريع والربط'),
  WebRoute(
      path: 'projects/import', title: 'استيراد الـ Issues والمساهمين', section: 'المشاريع والربط'),
  WebRoute(path: 'projects/invite', title: 'دعوة الفريق وطلبات الانضمام', section: 'المشاريع والربط'),
  WebRoute(path: 'projects/settings', title: 'إعدادات المشروع والأعضاء', section: 'المشاريع والربط'),
  // المهام
  WebRoute(path: 'my-tasks', title: 'مهامي', section: 'المهام'),
  WebRoute(path: 'board', title: 'لوحة المشروع', section: 'المهام'),
  WebRoute(path: 'table', title: 'عرض الجدول', section: 'المهام'),
  WebRoute(path: 'calendar', title: 'التقويم', section: 'المهام'),
  WebRoute(path: 'timeline', title: 'الجدول الزمني والاعتماديات', section: 'المهام'),
  WebRoute(path: 'tasks/:id', title: 'تفاصيل المهمة', section: 'المهام'),
  WebRoute(path: 'tasks/new', title: 'مهمة جديدة', section: 'المهام'),
  WebRoute(path: 'search', title: 'البحث ولوحة الأوامر', section: 'المهام'),
  WebRoute(path: 'workflow', title: 'سير العمل والـ Labels والأتمتة', section: 'المهام'),
  // الـ Sprints والفريق والتقارير
  WebRoute(path: 'sprints/plan', title: 'تخطيط الـ Sprint', section: 'الـ Sprints والتقارير'),
  WebRoute(path: 'sprints/summary', title: 'ملخص الـ Sprint والـ Retro', section: 'الـ Sprints والتقارير'),
  WebRoute(path: 'team/workload', title: 'حجم شغل الفريق', section: 'الـ Sprints والتقارير'),
  WebRoute(path: 'reports', title: 'التقارير', section: 'الـ Sprints والتقارير'),
  // GitHub ومراجعة والإصدارات
  WebRoute(path: 'reviews', title: 'المراجعات', section: 'GitHub والمراجعة'),
  WebRoute(path: 'pull-requests/:number', title: 'تفاصيل الـ PR والدمج', section: 'GitHub والمراجعة'),
  WebRoute(path: 'ci/failure', title: 'فشل الـ CI', section: 'GitHub والمراجعة'),
  WebRoute(path: 'commits', title: 'سجل الـ commits', section: 'GitHub والمراجعة'),
  WebRoute(path: 'releases', title: 'الإصدارات', section: 'GitHub والمراجعة'),
  WebRoute(path: 'activity', title: 'سجل النشاط', section: 'GitHub والمراجعة'),
  // الإشعارات والـ Agents والمعرفة
  WebRoute(path: 'notifications', title: 'الإشعارات ووضع التركيز', section: 'الإشعارات والـ Agents'),
  WebRoute(path: 'digest', title: 'الملخص اليومي', section: 'الإشعارات والـ Agents'),
  WebRoute(path: 'agents', title: 'الـ AI Agents وقواعدها', section: 'الإشعارات والـ Agents'),
  WebRoute(path: 'knowledge', title: 'خريطة المعرفة', section: 'الإشعارات والـ Agents'),
  WebRoute(path: 'ask', title: 'اسأل المشروع', section: 'الإشعارات والـ Agents'),
  // العملاء والوكالات
  WebRoute(path: 'clients', title: 'بوابة العميل', section: 'العملاء والوكالات'),
  WebRoute(path: 'clients/weekly', title: 'الملخص الأسبوعي للعميل', section: 'العملاء والوكالات'),
  WebRoute(path: 'clients/time', title: 'الوقت المحسوب', section: 'العملاء والوكالات'),
  WebRoute(path: 'clients/invoices', title: 'الفواتير وتقارير العملاء', section: 'العملاء والوكالات'),
  // الحالات والنسخ
  WebRoute(path: 'not-found', title: 'الصفحة غير موجودة', section: 'الحالات والنسخ'),
  WebRoute(path: 'no-permission', title: 'لا تملك صلاحية', section: 'الحالات والنسخ'),
  WebRoute(path: 'sync-error', title: 'فشل المزامنة', section: 'الحالات والنسخ'),
  WebRoute(path: 'board-light', title: 'اللوحة — الوضع الفاتح', section: 'الحالات والنسخ'),
  WebRoute(path: 'board-en', title: 'Board — English LTR', section: 'الحالات والنسخ'),
];

/// Looks up a web route by its path.
WebRoute? webRouteFor(String path) {
  for (final route in webRoutes) {
    if (route.path == path) return route;
  }
  return null;
}
