import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// The 6DX logo mark — a monospaced `{ }` badge.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 40, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Text(
            '{ }',
            style: TextStyle(
              fontFamily: AppTheme.monoFontFamily,
              fontSize: size * 0.4,
              fontWeight: FontWeight.w500,
              color: AppColors.background,
            ),
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(width: 10),
          Text(
            '6DX',
            style: TextStyle(
              fontFamily: AppTheme.monoFontFamily,
              fontSize: size * 0.45,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }
}
