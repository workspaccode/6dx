import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/task.dart';
import '../../../../shared/widgets/ui_kit.dart';

/// المهام الفرعية — V2Subtasks.dc.html
@RoutePage()
class SubtasksPage extends StatefulWidget {
  const SubtasksPage({super.key, required this.task});

  final Task task;

  @override
  State<SubtasksPage> createState() => _SubtasksPageState();
}

class _SubtasksPageState extends State<SubtasksPage> {
  final _items = <Map<String, Object>>[
    {'title': 'شاشة إدخال الكود', 'done': true},
    {'title': 'التحقق من انتهاء الكود', 'done': true},
    {'title': 'قفل مؤقت بعد 5 محاولات', 'done': true},
    {'title': 'تصميم شاشة الخطأ', 'done': false},
  ];

  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _items.where((i) => i['done'] == true).length;

    return AppScreen(
      title: 'المهام الفرعية',
      subtitle: '${widget.task.key} · صفحة تسجيل الدخول بكود OTP',
      children: [
        SectionLabel('المهام الفرعية · $done / ${_items.length}'),
        const HintBanner(
          'تتزامن مع قائمة المهام (- [ ]) في وصف الـ PR #58، فتُعلَّم هنا عندما تُعلَّم هناك.',
        ),
        for (var i = 0; i < _items.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() {
                    _items[i]['done'] = !(_items[i]['done'] == true);
                  }),
                  child: Icon(
                    _items[i]['done'] == true
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: _items[i]['done'] == true
                        ? AppColors.accent
                        : AppColors.textDim,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _items[i]['title'] as String,
                    style: TextStyle(
                      decoration: _items[i]['done'] == true
                          ? TextDecoration.lineThrough
                          : null,
                      color: _items[i]['done'] == true
                          ? AppColors.textMuted
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        TextField(
          controller: _controller,
          onSubmitted: (value) {
            if (value.trim().isEmpty) return;
            setState(() => _items.add({'title': value.trim(), 'done': false}));
            _controller.clear();
          },
          decoration: const InputDecoration(
            hintText: 'مهمة فرعية جديدة',
            suffixIcon: Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

/// التعليقات والإشارات — V3Comments.dc.html
class CommentEntry {
  const CommentEntry({
    required this.author,
    required this.time,
    required this.text,
    this.attachment,
    this.code,
    this.isAuthor,
  });

  final String author;
  final String time;
  final String text;
  final String? attachment;
  final String? code;
  final bool? isAuthor;
}

@RoutePage()
class CommentsPage extends StatefulWidget {
  const CommentsPage({super.key, this.taskKey = 'MOB-24'});

  final String taskKey;

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final _items = const <CommentEntry>[
    CommentEntry(
      author: 'سارة',
      time: 'منذ ساعة',
      text: 'هل عدد المحاولات محدود قبل قفل الكود مؤقتًا؟ مرفق تصميم شاشة الخطأ.',
      attachment: 'otp-error.png',
    ),
    CommentEntry(
      author: 'أحمد',
      time: 'منذ 40 د',
      text: 'نعم، 5 محاولات ثم قفل 15 دقيقة:',
      code: 'if (attempts >= 5) {\n  lockUntil = now + 15.minutes\n}',
      isAuthor: true,
    ),
  ];

  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'التعليقات · 4',
      subtitle: '${widget.taskKey} · صفحة تسجيل الدخول بكود OTP',
      children: [
        for (final item in _items)
          AppPanel(
            margin: const EdgeInsetsDirectional.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InitialsAvatar(
                  name: item.author,
                  color: item.isAuthor == true
                      ? AppColors.accent
                      : AppColors.info,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.author,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Text(item.time,
                              style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(item.text, style: Theme.of(context).textTheme.bodySmall),
                      if (item.attachment != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.image_outlined,
                                  size: 16, color: AppColors.textMuted),
                              const SizedBox(width: 8),
                              Text(item.attachment!,
                                  style: Theme.of(context).textTheme.labelSmall),
                            ],
                          ),
                        ),
                      ],
                      if (item.code != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            item.code!,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'اكتب تعليقًا',
            suffixIcon: Icon(Icons.send_rounded),
          ),
        ),
      ],
    );
  }
}