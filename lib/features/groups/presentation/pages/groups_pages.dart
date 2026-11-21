import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../domain/group_models.dart';
import '../providers/group_providers.dart';
import '../widgets/group_widgets.dart';

/// `/groups` — my groups, the plan counter and pending invites.
class MyGroupsPage extends ConsumerWidget {
  const MyGroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(groupsOverviewProvider);
    final invites = ref.watch(pendingInvitesProvider).value ?? const [];

    return overview.when(
      loading: () => const Scaffold(body: AppLoadingView()),
      error: (error, _) => AppScreen(
        title: 'مجموعاتي',
        children: [
          AppErrorView(
            message: describeError(error, fallback: 'تعذّر تحميل المجموعات.'),
            onRetry: () => ref.invalidate(groupsOverviewProvider),
          ),
        ],
      ),
      data: (data) {
        final plan = data.plan;
        return AppScreen(
          title: 'مجموعاتي',
          subtitle: 'خطة ${plan.name} · ${plan.usedGroups} / ${plan.maxGroups} مجموعات',
          trailing: IconButton(
            tooltip: 'الرئيسية',
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/home'),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => plan.canAddGroup
                ? context.push('/groups/new')
                : _showLimit(context, plan),
            icon: const Icon(Icons.add_rounded),
            label: const Text('مجموعة جديدة'),
          ),
          children: [
            for (final invite in invites)
              if (invite.id.isNotEmpty)
                AppPanel(
                  accent: AppColors.purple,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline_rounded, color: AppColors.purple),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('عندك دعوة للانضمام لمجموعة')),
                      TextButton(
                        onPressed: () => context.push('/invite/${invite.id}'),
                        child: const Text('عرض'),
                      ),
                    ],
                  ),
                ),
            _PlanMeter(plan: plan),
            const SizedBox(height: 16),
            if (data.active.isEmpty)
              AppEmptyState(
                icon: Icons.groups_2_outlined,
                title: 'مفيش مجموعات لسه',
                message: 'اعمل مجموعة Software أو Hardware وادعي فريقك، '
                    'أو استنى دعوة من قائد مجموعة.',
                action: FilledButton.icon(
                  onPressed: () => context.push('/groups/new'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('اعمل أول مجموعة'),
                ),
              )
            else
              for (final group in data.active) _GroupCard(group: group),
            if (data.archived.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('مؤرشفة (${data.archived.length})'),
                children: [for (final group in data.archived) _GroupCard(group: group)],
              ),
            ],
          ],
        );
      },
    );
  }

  void _showLimit(BuildContext context, PlanUsage plan) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('وصلت لحد الخطة'),
        content: Text(
          'خطتك (${plan.name}) بتسمح بـ ${plan.maxGroups} مجموعات. '
          '${plan.isPaid ? 'أرشف مجموعة قديمة علشان تعمل واحدة جديدة.' : 'الخطة المدفوعة (60\$ / شهر) بتسمح بـ 50 مجموعة، أو أرشف مجموعة قديمة.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('تمام'),
          ),
        ],
      ),
    );
  }
}

class _PlanMeter extends StatelessWidget {
  const _PlanMeter({required this.plan});
  final PlanUsage plan;

  @override
  Widget build(BuildContext context) {
    final ratio = plan.maxGroups == 0 ? 0.0 : plan.usedGroups / plan.maxGroups;
    final color = ratio >= 1 ? AppColors.danger : (ratio >= 0.8 ? AppColors.warning : AppColors.accent);
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('المجموعات', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text('${plan.usedGroups} / ${plan.maxGroups}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1).toDouble(),
              minHeight: 6,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'الأعضاء مفتوح · المجموعات المؤرشفة مش بتتحسب',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});
  final GroupSummary group;

  @override
  Widget build(BuildContext context) {
    final color = group.type == GroupType.hardware ? AppColors.warning : AppColors.info;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        child: InkWell(
          onTap: () => context.go('/g/${group.id}/home'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                InitialsAvatar(name: group.name, color: color, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(group.name,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium),
                          ),
                          const SizedBox(width: 8),
                          GroupTypeBadge(group.type),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(group.roleLabel, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text(
                        '${group.projectCount} مشروع · ${group.memberCount} عضو',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded, color: AppColors.textDim),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `/groups/new` — name, type (fixed afterwards) and template.
class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  GroupType _type = GroupType.software;
  String _template = 'scrum';
  bool _busy = false;

  static const _templates = <GroupType, Map<String, String>>{
    GroupType.software: {'scrum': 'Scrum (sprints)', 'kanban': 'Kanban'},
    GroupType.hardware: {
      'evt_dvt_pvt': 'EVT → DVT → PVT → MP',
      'custom': 'مراحل مخصصة',
    },
  };

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'اكتب اسم المجموعة');
      return;
    }
    setState(() => _busy = true);
    try {
      final group = await ref.read(groupsApiProvider).create(
            name: name,
            type: _type,
            template: _template,
            description: _description.text.trim(),
          );
      ref.invalidate(groupsOverviewProvider);
      if (!mounted) return;
      context.go('/g/${group.id}/home');
    } catch (error) {
      if (mounted) showSnack(context, describeError(error, fallback: 'تعذّر إنشاء المجموعة.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'مجموعة جديدة',
      subtitle: 'انت هتبقى قائد المجموعة',
      children: [
        TextField(
          controller: _name,
          maxLength: 80,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'اسم المجموعة', hintText: 'مثلًا: تيم الـ Power Board'),
        ),
        const SizedBox(height: 8),
        Text('النوع', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<GroupType>(
          segments: const [
            ButtonSegment(value: GroupType.software, icon: Icon(Icons.code_rounded), label: Text('Software')),
            ButtonSegment(value: GroupType.hardware, icon: Icon(Icons.memory_rounded), label: Text('Hardware')),
          ],
          selected: {_type},
          onSelectionChanged: _busy
              ? null
              : (selection) => setState(() {
                    _type = selection.first;
                    _template = _templates[_type]!.keys.first;
                  }),
        ),
        const SizedBox(height: 8),
        HintBanner(
          _type == GroupType.hardware
              ? 'Hardware: مراحل (EVT/DVT/PVT)، قطع و BOM، ECO، builds واختبارات، ومشتريات ومخزن. النوع مش بيتغير بعد الإنشاء.'
              : 'Software: مهام، sprints، و Pull Requests من GitHub. النوع مش بيتغير بعد الإنشاء.',
          color: _type == GroupType.hardware ? AppColors.warning : AppColors.info,
        ),
        const SizedBox(height: 8),
        Text('القالب', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _templates[_type]!.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _template == entry.key,
                onSelected: _busy ? null : (_) => setState(() => _template = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _description,
          maxLength: 2000,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'وصف (اختياري)'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('إنشاء المجموعة'),
        ),
      ],
    );
  }
}
