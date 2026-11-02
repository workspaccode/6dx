import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/app_logo.dart';
import 'web_routes.dart';

/// Responsive shell for the public website and the web app.
///
/// Wide screens get a sidebar, narrow screens get a top bar. The shell always
/// lays out left-to-right, which is what the web design uses.
class WebShellPage extends StatelessWidget {
  const WebShellPage({super.key, required this.route});

  final WebRoute route;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Row(
              children: [
                if (wide) const _WebSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      if (!wide) const _WebTopBar(),
                      Expanded(child: _WebContent(route: route)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WebSidebar extends StatelessWidget {
  const _WebSidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Directionality(
              textDirection: TextDirection.rtl,
              child: AppLogo(),
            ),
            const SizedBox(height: 24),
            for (final section in _sections)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                    child: Text(
                      section.title,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  for (final route in section.routes)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: _SidebarLink(route: route),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarLink extends StatelessWidget {
  const _SidebarLink({required this.route});

  final WebRoute route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Text(
        route.title,
        style: const TextStyle(fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {},
    );
  }
}

class _WebTopBar extends StatelessWidget {
  const _WebTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: const AppLogo(),
      ),
    );
  }
}

class _WebContent extends StatelessWidget {
  const _WebContent({required this.route});

  final WebRoute route;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                route.section,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (route.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        route.description!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (route.isMarketing)
                      const _MarketingBlocks()
                    else
                      const AppEmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'لا توجد بيانات بعد',
                        message: 'تُعرض هنا بيانات الـ API فور توفّره — '
                            'لا يعرض التطبيق أي محتوى مختلق.',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketingBlocks extends StatelessWidget {
  const _MarketingBlocks();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 720 ? 3 : 1;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final block in const [
                  ('اربط مستودع GitHub', 'الـ Issues تتحول لمهام والـ PRs تحرّك الحالة.'),
                  ('ادعُ فريقك', 'صلاحيات واضحة لكل عضو وكل دور.'),
                  ('تابع حتى الدمج', 'مراجعات، فحوصات، وسجل نشاط كامل.'),
                ])
                  SizedBox(
                    width: columns == 3
                        ? (constraints.maxWidth - 32) / 3
                        : constraints.maxWidth,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            block.$1,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            block.$2,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () {},
          child: const Text('ابدأ مجانًا'),
        ),
      ],
    );
  }
}

class _WebSection {
  const _WebSection(this.title, this.routes);

  final String title;
  final List<WebRoute> routes;
}

final List<_WebSection> _sections = _buildSections();

List<_WebSection> _buildSections() {
  final map = <String, List<WebRoute>>{};
  for (final route in webRoutes) {
    map.putIfAbsent(route.section, () => []).add(route);
  }
  return map.entries
      .map((entry) => _WebSection(entry.key, entry.value))
      .toList(growable: false);
}
