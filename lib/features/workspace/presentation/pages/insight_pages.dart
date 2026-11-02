import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../providers/workspace_providers.dart';

/// البشر والـ Agents
@RoutePage()
class AgentsTeamPage extends ConsumerWidget {
  const AgentsTeamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(workspaceAgentsProvider);
    final rules = ref.watch(agentRulesProvider);

    return AppScreen(
      title: 'الفريق: بشر و Agents',
      children: [
        const SectionLabel('Agent'),
        if (agents.isEmpty)
          const AppEmptyState(
            icon: Icons.smart_toy_outlined,
            title: 'لا يوجد Agents',
            message: 'اربط مزوّد AI لتظهر هنا.',
          )
        else
          for (final agent in agents)
            AppPanel(
              margin: const EdgeInsetsDirectional.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InitialsAvatar(
                        name: agent.name,
                        color: agent.isOnline
                            ? AppColors.accent
                            : AppColors.info,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(agent.name,
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      Text(agent.kind,
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                  if (agent.pullRequests.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('PRs بانتظار مراجعة',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    for (final pr in agent.pullRequests)
                      Text(
                        pr,
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 11,
                          color: AppColors.info,
                        ),
                      ),
                  ],
                ],
              ),
            ),
        const SizedBox(height: 16),
        const SectionLabel('قواعد الـ Agents'),
        if (rules.isEmpty)
          const Text('لا توجد قواعد.',
              style: TextStyle(color: AppColors.textMuted))
        else
          for (final rule in rules)
            ToggleRow(
              title: rule.title,
              subtitle: rule.description,
              value: rule.enabled,
              onChanged: (v) {},
            ),
      ],
    );
  }
}

/// تعيين مهمة لـ Agent
@RoutePage()
class AssignAgentPage extends ConsumerWidget {
  const AssignAgentPage({super.key, this.taskKey, this.taskTitle});

  final String? taskKey;
  final String? taskTitle;

  @override
 Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(workspaceAgentsProvider);
    final members = ref.watch(workspaceMembersProvider);

    return AppScreen(
      title: 'تعيين مهمة لـ Agent',
      subtitle: taskKey,
      children: [
        if (taskTitle != null) ...[
          Text(taskTitle!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
        ],
        const SectionLabel('تعيين إلى'),
        if (agents.isEmpty)
          const Text('لا يوجد Agents متاحون.',
              style: TextStyle(color: AppColors.textMuted))
        else
          for (final agent in agents)
            RadioListTileSimple(
              label: agent.name,
              subtitle: agent.description,
              selected: false,
            ),
        if (members.isNotEmpty) ...[
          const SizedBox(height: 12),
          const SectionLabel('أو إلى عضو من الفريق'),
          for (final member in members)
            RadioListTileSimple(
              label: member.name,
              subtitle: member.role,
              selected: false,
            ),
        ],
        const SizedBox(height: 16),
        const TextField(
          decoration: InputDecoration(labelText: 'تعليمات إضافية'),
        ),
        const SizedBox(height: 12),
        ToggleRow(
          title: 'يتطلب مراجعة بشرية قبل الدمج',
          value: true,
          onChanged: (v) {},
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: () {}, child: const Text('تعيين')),
      ],
    );
  }
}

/// خريطة المعرفة
@RoutePage()
class KnowledgeMapPage extends ConsumerWidget {
  const KnowledgeMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = ref.watch(knowledgeAreasProvider);

    return AppScreen(
      title: 'خريطة المعرفة',
      subtitle: 'من يعرف كل جزء من الكود',
      children: [
        if (areas.isEmpty)
          const AppEmptyState(
            icon: Icons.hub_outlined,
            title: 'لا توجد بيانات',
            message: 'نحتاج أشهرًا من نشاط الكود لبناء الخريطة.',
          )
        else ...[
          for (final area in areas)
            AppPanel(
              margin: const EdgeInsetsDirectional.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area.path,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final entry in area.contributors.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          SizedBox(
                            width: 90,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: entry.value,
                                minHeight: 5,
                                backgroundColor: AppColors.border,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(entry.value * 100).round()}%',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  if (area.note != null) ...[
                    const SizedBox(height: 6),
                    Text(area.note!,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 8),
          const HintBanner(
            'لا ترتيب للأفراد — الهدف توزيع المعرفة حتى لا يتوقف العمل لغياب شخص.',
          ),
        ],
      ],
    );
  }
}

/// اسأل المشروع
@RoutePage()
class AskProjectPage extends StatefulWidget {
  const AskProjectPage({super.key, this.projectName});

  final String? projectName;

  @override
  State<AskProjectPage> createState() => _AskProjectPageState();
}

class _AskProjectPageState extends State<AskProjectPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'اسأل المشروع',
      subtitle: '${widget.projectName ?? 'المشروع'} · الإجابات من بيانات المشروع فقط',
      children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'سؤالك',
            suffixIcon: Icon(Icons.send_rounded),
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('المصادر'),
        const Text(
          'الإجابة تُبنى من المهام والـ PRs داخل هذا المشروع فقط.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        const SectionLabel('أسئلة مقترحة'),
        const _Suggestion(text: 'ما المهام التي تنتظر مراجعة؟'),
        const _Suggestion(text: 'ما الـ PRs الفاشلة؟'),
        const _Suggestion(text: 'ما المهام المتأخرة عن موعدها؟'),
      ],
    );
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        onPressed: () {},
        child: Text(text),
      ),
    );
  }
}

/// تقرير المشروع
@RoutePage()
class ProjectReportPage extends ConsumerWidget {
  const ProjectReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(projectReportsProvider);

    return AppScreen(
      title: 'تقرير المشروع',
      trailing: TextButton(onPressed: () {}, child: const Text('تصدير PDF')),
      children: [
        if (reports.isEmpty)
          const AppEmptyState(
            icon: Icons.insights_outlined,
            title: 'لا يوجد تقرير',
            message: 'يُبنى التقرير بعد إنجاز أول Sprint.',
          )
        else
          for (final report in reports) ...[
            Row(
              children: [
                StatTile(
                  value: report.averagePointsPerSprint?.toStringAsFixed(1) ?? '—',
                  label: 'متوسط النقاط لكل Sprint',
                ),
                const SizedBox(width: 10),
                StatTile(
                  value: report.averageCycleDays?.toStringAsFixed(1) ?? '—',
                  label: 'من أول commit للدمج (يوم)',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                StatTile(
                  value: report.reworkRatio == null
                      ? '—'
                      : '${(report.reworkRatio! * 100).round()}%',
                  label: 'مهام أُعيدت من المراجعة',
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                StatTile(
                  value: report.averageFirstReviewHours?.toStringAsFixed(0) ?? '—',
                  label: 'ساعات حتى أول مراجعة',
                  color: AppColors.info,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionLabel('أين يقضي العمل وقته'),
            for (final entry in report.workDistribution.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.key)),
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: entry.value,
                          minHeight: 6,
                          backgroundColor: AppColors.border,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${(entry.value * 100).round()}%',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
          ],
      ],
    );
  }
}

/// تقديرات تتحسن
@RoutePage()
class EstimateLearningPage extends ConsumerWidget {
  const EstimateLearningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(estimateRecordsProvider);

    return AppScreen(
      title: 'دقة تقديراتي',
      subtitle: 'هذه البيانات لك فقط ولا تظهر للمدير',
      children: [
        if (records.isEmpty)
          const AppEmptyState(
            icon: Icons.insights_outlined,
            title: 'لا توجد بيانات',
            message: 'نحتاج عددًا من المهام المنجزة لتقدير دقتك.',
          )
        else ...[
          const SectionLabel('آخر المهام (نقاط)'),
          for (final record in records)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.taskKey,
                            style: Theme.of(context).textTheme.labelSmall),
                        Text(record.title,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text('التقدير ${record.estimate}',
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(width: 10),
                  Text('الفعلي ${record.actual}',
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// أرشيف الـ Sprints والـ Retro
@RoutePage()
class SprintHistoryPage extends ConsumerWidget {
  const SprintHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final retros = ref.watch(sprintRetrosProvider);

    return AppScreen(
      title: 'أرشيف الـ Sprints',
      children: [
        if (retros.isEmpty)
          const AppEmptyState(
            icon: Icons.history_rounded,
            title: 'لا يوجد أرشيف',
            message: 'يُحفظ ملخص كل Sprint بعد انتهائه.',
          )
        else
          for (final retro in retros)
            AppPanel(
              margin: const EdgeInsetsDirectional.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(retro.sprintName,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${retro.completedPoints} / ${retro.committedPoints} نقطة',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(onPressed: () {}, child: const Text('+ إضافة')),
                    ],
                  ),
                  for (final note in retro.notes)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• $note'),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}

/// اختيار المراجِع الذكي
@RoutePage()
class ReviewerPickPage extends ConsumerWidget {
  const ReviewerPickPage({super.key, this.prNumber});

  final int? prNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(workspaceMembersProvider);

    return AppScreen(
      title: 'اختيار المراجِع',
      subtitle: prNumber == null ? null : 'PR #$prNumber',
      children: [
        const Text(
          'مرتّبون حسب الخبرة في الملفات المتغيرة، وعدد المراجعات الحالية، والتوفر.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        if (members.isEmpty)
          const AppEmptyState(
            icon: Icons.rate_review_outlined,
            title: 'لا يوجد مراجعون',
            message: 'ادعُ أعضاء الفريق أولًا.',
          )
        else
          for (final member in members)
            RadioListTileSimple(
              label: member.name,
              subtitle: member.role,
              selected: false,
            ),
      ],
    );
  }
}

/// تحذير PR كبير
@RoutePage()
class BigPrWarningPage extends ConsumerWidget {
  const BigPrWarningPage({super.key, this.prNumber, this.additions, this.deletions});

  final int? prNumber;
  final int? additions;
  final int? deletions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pr = ref.watch(pullRequestProvider(prNumber ?? 0));

    return AppScreen(
      title: 'PR كبير',
      subtitle: pr == null ? null : '#${pr.number} · ${pr.title}',
      children: [
        const HintBanner(
          'الـ PRs الأصغر من 200 سطر تُراجع أسرع بنحو 3 أضعاف، وأخطاؤها أقل.',
          color: AppColors.warning,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            StatTile(
              value: '+${pr?.additions ?? additions ?? 0}',
              label: 'سطر مضاف',
              color: AppColors.success,
            ),
            const SizedBox(width: 10),
            StatTile(
              value: '-${pr?.deletions ?? deletions ?? 0}',
              label: 'سطر محذوف',
              color: AppColors.danger,
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: () {}, child: const Text('اقتراح تقسيم')),
      ],
    );
  }
}

/// الدمج من التطبيق
@RoutePage()
class MergeFromAppPage extends ConsumerWidget {
  const MergeFromAppPage({super.key, this.prNumber});

  final int? prNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pr = ref.watch(pullRequestProvider(prNumber ?? 0));
    if (pr == null) {
      return const AppScreen(
        title: 'دمج PR',
        children: [
          AppEmptyState(
            icon: Icons.merge_rounded,
            title: 'الـ PR غير موجود',
            message: 'ربما تم دمجه أو حُذف.',
          ),
        ],
      );
    }

    return AppScreen(
      title: 'دمج PR #${pr.number}',
      subtitle: '${pr.branch} → ${pr.baseBranch}',
      children: [
        const SectionLabel('الموافقات المطلوبة (حماية الفرع)'),
        const SettingsTile(
          icon: Icons.check_circle_rounded,
          title: 'الموافقات',
          subtitle: '2/2 ✓',
          color: AppColors.success,
        ),
        SettingsTile(
          icon: Icons.check_circle_rounded,
          title: 'الفحوصات',
          subtitle: '${pr.checks.where((c) => c.passed).length}/${pr.checks.length} ✓',
          color: AppColors.success,
        ),
        const SettingsTile(
          icon: Icons.call_split_rounded,
          title: 'تعارضات',
          subtitle: 'لا يوجد',
          color: AppColors.success,
        ),
        const SizedBox(height: 16),
        const SectionLabel('طريقة الدمج'),
        const TextField(decoration: InputDecoration(labelText: 'رسالة الـ Commit')),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.merge_rounded),
          label: const Text('دمج الآن'),
        ),
      ],
    );
  }
}

/// سجل الـ commits
@RoutePage()
class CommitsPage extends ConsumerWidget {
  const CommitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commits = ref.watch(workspaceCommitsProvider);

    return AppScreen(
      title: 'سجل الـ commits',
      subtitle: 'آخر النشاط على الكود',
      children: [
        if (commits.isEmpty)
          const AppEmptyState(
            icon: Icons.commit_outlined,
            title: 'لا توجد commits',
            message: 'اربط مستودعًا لعرض نشاطه.',
          )
        else
          for (final commit in commits)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Row(
                children: [
                  Text(
                    commit.sha,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(commit.message,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  Text(commit.branch,
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
      ],
    );
  }
}

/// متابعة الإصدار
@RoutePage()
class ReleaseTrackerPage extends ConsumerWidget {
  const ReleaseTrackerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releases = ref.watch(workspaceReleasesProvider);

    return AppScreen(
      title: 'متابعة الإصدار',
      children: [
        if (releases.isEmpty)
          const AppEmptyState(
            icon: Icons.local_offer_outlined,
            title: 'لا يوجد إصدار',
            message: 'أنشئ إصدارًا لتتبّع ما سيصل للمستخدمين.',
          )
        else
          for (final release in releases) ...[
            AppPanel(
              margin: const EdgeInsetsDirectional.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(release.version,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(release.projectName,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                  if (release.blockedReason != null) ...[
                    const SizedBox(height: 10),
                    HintBanner(release.blockedReason!,
                        color: AppColors.danger),
                  ],
                  if (release.items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('ما الذي سيصل للمستخدمين',
                        style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    for (final item in release.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $item'),
                      ),
                  ],
                ],
              ),
            ),
          ],
      ],
    );
  }
}

/// الملخص الأسبوعي للعميل
@RoutePage()
class WeeklyClientSummaryPage extends ConsumerWidget {
  const WeeklyClientSummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(weeklyClientSummariesProvider);

    return AppScreen(
      title: 'ملخص الأسبوع للعميل',
      subtitle: 'راجعه قبل الإرسال',
      children: [
        if (summaries.isEmpty)
          const AppEmptyState(
            icon: Icons.summarize_outlined,
            title: 'لا يوجد ملخص',
            message: 'يُولَّد الملخص من الـ PRs المدموجة.',
          )
        else
          for (final summary in summaries) ...[
            AppPanel(
              margin: const EdgeInsetsDirectional.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary.clientName,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '${summary.pullRequestCount} PRs مدموجة',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  for (final item in summary.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $item'),
                    ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.send_rounded),
              label: const Text('إرسال للعميل الآن'),
            ),
          ],
      ],
    );
  }
}
