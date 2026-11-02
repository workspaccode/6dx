import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';

@RoutePage()
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  static const List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      title: 'اربط مشروعك بمستودع GitHub',
      body:
          'الـ Issues تتحول لمهام، والـ PRs تحرّك حالة المهمة تلقائيًا. بلا نسخ ولصق بين أداتين.',
      icon: Icons.link_rounded,
      accent: AppColors.accent,
      stats: ['25 مهمة · 5 أعضاء', '12 issues', '3 pull requests', 'main'],
    ),
    _OnboardingSlide(
      title: 'وزّع العمل على فريقك',
      body:
          'كل عضو يرى مهامه فقط، وتعرف حجم الشغل الحالي قبل توزيع مهمة جديدة.',
      icon: Icons.groups_rounded,
      accent: AppColors.info,
      stats: ['4 مهام لكل عضو', '5 أعضاء', 'Sprint أسبوعي'],
    ),
    _OnboardingSlide(
      title: 'تابع كل شيء حتى الدمج',
      body:
          'مراجعات، فحوصات CI، تعليقات، وسجل نشاط كامل لكل مهمة — من تطبيقك.',
      icon: Icons.rocket_launch_rounded,
      accent: AppColors.purple,
      stats: ['فحوصات CI', 'مراجعة قبل الدمج', 'تتبّع الحالة'],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _slides.length - 1) {
      context.go(AppRoutes.login);
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('تخطٍّ'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) => setState(() => _index = index),
                itemCount: _slides.length,
                itemBuilder: (context, index) =>
                    _OnboardingSlideView(slide: _slides[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      final active = index == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.accent
                              : Theme.of(context).colorScheme.outline,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_index == _slides.length - 1 ? 'ابدأ' : 'التالي'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
    required this.stats,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color accent;
  final List<String> stats;
}

class _OnboardingSlideView extends StatelessWidget {
  const _OnboardingSlideView({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: slide.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: slide.accent.withValues(alpha: 0.35)),
            ),
            child: Icon(slide.icon, size: 52, color: slide.accent),
          ),
          const SizedBox(height: 28),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: slide.stats
                .map(
                  (stat) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      stat,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
