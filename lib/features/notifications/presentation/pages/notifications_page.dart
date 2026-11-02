import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/status_badge.dart';

@RoutePage()
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _items = <_NotificationItem>[
    const _NotificationItem(
      glyph: '🔀',
      label: 'مراجعة',
      text: 'سارة طلبت مراجعتك على PR #58',
      time: 'منذ 5 دقائق',
      action: 'افتح',
      color: AppColors.warning,
      unread: true,
    ),
    const _NotificationItem(
      glyph: '✅',
      label: 'فحوصات',
      text: 'كل فحوصات PR #61 ناجحة',
      time: 'منذ 22 دقيقة',
      action: 'عرض',
      color: AppColors.success,
      unread: true,
    ),
    const _NotificationItem(
      glyph: '💬',
      label: 'تعليق',
      text: 'أحمد علّق على مهمة «تقرير المشروع»',
      time: 'منذ ساعة',
      action: 'رد',
      color: AppColors.info,
      unread: false,
    ),
    const _NotificationItem(
      glyph: '👥',
      label: 'دعوة',
      text: 'انضممت إلى مشروع «لوحة التحكم»',
      time: 'أمس',
      action: null,
      color: AppColors.purple,
      unread: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notifications),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              for (var i = 0; i < _items.length; i++) {
                _items[i] = _items[i].copyWith(unread: false);
              }
            }),
            child: const Text('تعليم الكل كمقروء'),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _items[index];
          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(item.glyph, style: const TextStyle(fontSize: 18)),
            ),
            title: Row(
              children: [
                StatusBadge(label: item.label, color: item.color, dense: true),
                const SizedBox(width: 8),
                if (item.unread)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.text),
                  const SizedBox(height: 2),
                  Text(item.time, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
            trailing: item.action == null
                ? null
                : TextButton(onPressed: () {}, child: Text(item.action!)),
          );
        },
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.glyph,
    required this.label,
    required this.text,
    required this.time,
    required this.action,
    required this.color,
    required this.unread,
  });

  final String glyph;
  final String label;
  final String text;
  final String time;
  final String? action;
  final Color color;
  final bool unread;

  _NotificationItem copyWith({bool? unread}) => _NotificationItem(
        glyph: glyph,
        label: label,
        text: text,
        time: time,
        action: action,
        color: color,
        unread: unread ?? this.unread,
      );
}
