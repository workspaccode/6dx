import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../app/app_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

@RoutePage()
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.profile)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.surfaceElevated,
                child: Icon(Icons.person_outline, color: AppColors.textMuted),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'مستخدم 6DX',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mobile Lead · Acme',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Icon(Icons.verified_rounded,
                            size: 14, color: AppColors.accent),
                        SizedBox(width: 4),
                        Text(
                          '@github-username ✓',
                          style: TextStyle(fontSize: 11, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(child: _StatCard(value: '4', label: 'مهام مفتوحة')),
              SizedBox(width: 10),
              Expanded(child: _StatCard(value: '2', label: 'بانتظار مراجعتي')),
              SizedBox(width: 10),
              Expanded(child: _StatCard(value: '9', label: 'نقاط هذا Sprint')),
            ],
          ),
          const SizedBox(height: 24),
          _MenuTile(
            icon: Icons.group_work_outlined,
            title: 'حجم شغل الفريق',
            onTap: () {},
          ),
          _MenuTile(
            icon: Icons.notifications_none_rounded,
            title: 'الإشعارات',
            onTap: () => context.push(AppRoutes.notifications),
          ),
          _MenuTile(
            icon: Icons.lock_outline_rounded,
            title: 'الحسابات المربوطة والأمان',
            onTap: () {},
          ),
          _MenuTile(
            icon: Icons.folder_outlined,
            title: 'المشاريع',
            onTap: () => context.go(AppRoutes.projects),
          ),
          const Divider(height: 32),
          const AppLogo(),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.translate_rounded, color: AppColors.textMuted),
            title: const Text('اللغة'),
            subtitle: Text(
              (ref.watch(localeProvider)?.languageCode ?? 'ar') == 'ar'
                  ? 'العربية'
                  : 'English',
            ),
            trailing: const Icon(Icons.chevron_left_rounded,
                color: AppColors.textDim),
            onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.l10n.logout),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.accent,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textMuted),
      title: Text(title),
      trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.textDim),
      onTap: onTap,
    );
  }
}
