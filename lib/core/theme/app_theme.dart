import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'IBMPlexSansArabic';
  static const String monoFontFamily = 'JetBrainsMono';

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: AppColors.background,
      secondary: AppColors.info,
      onSecondary: AppColors.background,
      error: AppColors.danger,
      onError: Colors.white,
      surface: isDark ? AppColors.surface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.text : AppColors.lightText,
      outline: isDark ? AppColors.border : AppColors.lightBorder,
      outlineVariant: isDark ? AppColors.border : AppColors.lightBorder,
      surfaceContainerHighest:
          isDark ? AppColors.surfaceElevated : AppColors.lightBorder,
      surfaceContainerHigh: isDark ? AppColors.surfaceElevated : AppColors.lightSurface,
      surfaceContainer: isDark ? AppColors.surface : AppColors.lightBackground,
      inverseSurface: isDark ? AppColors.text : AppColors.lightText,
      onInverseSurface: isDark ? AppColors.background : AppColors.lightSurface,
      inversePrimary: AppColors.accentSoft,
      scrim: Colors.black54,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor:
          isDark ? AppColors.background : AppColors.lightBackground,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, isDark),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.background : AppColors.lightBackground,
        foregroundColor: isDark ? AppColors.text : AppColors.lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.text : AppColors.lightText,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.surface : AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? AppColors.border : AppColors.lightBorder,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surface : AppColors.lightSurface,
        hintStyle: TextStyle(color: isDark ? AppColors.textDim : AppColors.textMuted),
        labelStyle: TextStyle(color: isDark ? AppColors.textMuted : AppColors.textDim),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.border : AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.border : AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.background,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.text : AppColors.lightText,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: isDark ? AppColors.border : AppColors.lightBorder),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.surfaceElevated : AppColors.lightSurface,
        side: BorderSide(color: isDark ? AppColors.border : AppColors.lightBorder),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: isDark ? AppColors.textMuted : AppColors.textDim,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.border : AppColors.lightBorder,
        space: 1,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.surface : AppColors.lightSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceElevated : AppColors.lightText,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: isDark ? AppColors.text : Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.surface : AppColors.lightSurface,
        indicatorColor: AppColors.accent.withValues(alpha: 0.16),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textMuted : AppColors.textDim,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, bool isDark) {
    final color = isDark ? AppColors.text : AppColors.lightText;
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.25,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.3,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
          bodyMedium: base.bodyMedium?.copyWith(color: color, height: 1.5),
          bodySmall: base.bodySmall?.copyWith(
            color: isDark ? AppColors.textMuted : AppColors.textDim,
            height: 1.5,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontFamily: monoFontFamily,
            color: isDark ? AppColors.textDim : AppColors.textMuted,
          ),
        )
        .apply(fontFamily: fontFamily);
  }
}
