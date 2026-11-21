import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_logo.dart';

/// A primary destination of the app shell.
class HomeNavDestination {
  const HomeNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.shortcut,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Digit shown in the desktop shortcut hint (`Ctrl+1` … `Ctrl+4`).
  final int shortcut;
}

const List<HomeNavDestination> homeNavDestinations = [
  HomeNavDestination(
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder,
    label: 'المشاريع',
    shortcut: 1,
  ),
  HomeNavDestination(
    icon: Icons.checklist_outlined,
    selectedIcon: Icons.checklist,
    label: 'مهامي',
    shortcut: 2,
  ),
  HomeNavDestination(
    icon: Icons.rate_review_outlined,
    selectedIcon: Icons.rate_review,
    label: 'المراجعات',
    shortcut: 3,
  ),
  HomeNavDestination(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: 'حسابي',
    shortcut: 4,
  ),
];

/// The sidebar the desktop shell shows instead of the bottom navigation bar.
///
/// [extended] is false in a narrow desktop window: the rail keeps only the
/// icons and reveals each label through a tooltip.
class HomeSidebar extends StatelessWidget {
  const HomeSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.extended,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  static double widthFor(bool extended) => extended
      ? AppBreakpoints.sidebarExpandedWidth
      : AppBreakpoints.sidebarCollapsedWidth;

  /// macOS gets the ⌘ hints, Windows and Linux get Ctrl.
  static String get modifierLabel =>
      defaultTargetPlatform == TargetPlatform.macOS ? '⌘' : 'Ctrl';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: widthFor(extended),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: BorderDirectional(end: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                extended ? 20 : 0,
                20,
                extended ? 20 : 0,
                18,
              ),
              child: Center(
                child: AppLogo(
                  size: extended ? 34 : 30,
                  showWordmark: extended,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (
                    var index = 0;
                    index < homeNavDestinations.length;
                    index++
                  )
                    _SidebarItem(
                      destination: homeNavDestinations[index],
                      selected: index == selectedIndex,
                      extended: extended,
                      onTap: () => onDestinationSelected(index),
                    ),
                ],
              ),
            ),
            if (extended) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اختصارات',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 8),
                    _ShortcutHint(keys: modifierLabel, label: '1–4 للتنقل'),
                    const SizedBox(height: 4),
                    _ShortcutHint(keys: '$modifierLabel K', label: 'البحث'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final HomeNavDestination destination;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textMuted;
    final item = Material(
      color: selected
          ? AppColors.accent.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: extended
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              if (extended) const SizedBox(width: 12),
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 20,
                color: color,
              ),
              if (extended) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: extended
            ? item
            : Tooltip(
                message: destination.label,
                waitDuration: const Duration(milliseconds: 400),
                child: item,
              ),
      ),
    );
  }
}

class _ShortcutHint extends StatelessWidget {
  const _ShortcutHint({required this.keys, required this.label});

  final String keys;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: scheme.outline),
          ),
          child: Text(
            keys,
            style: const TextStyle(
              fontFamily: AppTheme.monoFontFamily,
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }
}
