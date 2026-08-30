import 'package:flutter/material.dart';

/// Palette and spacing tokens.
///
/// The palette leans on a deep ink base with a single mint accent. Charts get
/// a five-hue categorical ramp tuned for legibility on both light and dark
/// surfaces, so category colors stay recognizable when the theme flips.
class AppColors {
  const AppColors._();

  // Core surfaces
  static const Color ink = Color(0xFF10131A);
  static const Color inkSoft = Color(0xFF1A1F2B);
  static const Color paper = Color(0xFFF6F7FB);
  static const Color paperRaised = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimaryLight = Color(0xFF10131A);
  static const Color textMutedLight = Color(0xFF6B7280);
  static const Color textPrimaryDark = Color(0xFFF4F6FB);
  static const Color textMutedDark = Color(0xFF98A1B3);

  // Accent — mint carries "money in" and primary actions
  static const Color mint = Color(0xFF14B87A);
  static const Color mintDeep = Color(0xFF0E8F5D);

  // Semantic
  static const Color expense = Color(0xFFE5484D);
  static const Color warning = Color(0xFFF2A93B);
  static const Color info = Color(0xFF3B82F6);

  /// Category ramp for charts. Ordered so adjacent slices stay distinct.
  static const List<Color> categorical = [
    Color(0xFF14B87A),
    Color(0xFF3B82F6),
    Color(0xFFF2A93B),
    Color(0xFFE5484D),
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
    Color(0xFFEC4899),
    Color(0xFF65A30D),
  ];

  /// Progress bar color for a budget's consumption ratio.
  static Color forRatio(double ratio) {
    if (ratio >= 1.0) return expense;
    if (ratio >= 0.8) return warning;
    return mint;
  }
}

/// Spacing scale. Everything in the app picks from these steps so rhythm
/// stays consistent instead of drifting screen to screen.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii. Cards are noticeably rounder than chips, which keeps
/// hierarchy readable without borders.
class AppRadius {
  const AppRadius._();

  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double pill = 999;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.mint,
      brightness: Brightness.light,
    ).copyWith(
      surface: AppColors.paper,
      primary: AppColors.mint,
      error: AppColors.expense,
    );
    return _base(scheme, AppColors.textPrimaryLight, AppColors.textMutedLight);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.mint,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppColors.ink,
      primary: AppColors.mint,
      error: AppColors.expense,
    );
    return _base(scheme, AppColors.textPrimaryDark, AppColors.textMutedDark);
  }

  static ThemeData _base(
    ColorScheme scheme,
    Color textPrimary,
    Color textMuted,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    final raised = isDark ? AppColors.inkSoft : AppColors.paperRaised;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // Inter ships in the bundle, so typography is identical on every
      // Android skin and needs no network on first launch.
      fontFamily: 'Inter',
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: raised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.mint, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: raised,
        elevation: 0,
        height: 68,
        indicatorColor: AppColors.mint.withValues(alpha: 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(
        color: textMuted.withValues(alpha: 0.18),
        thickness: 1,
        space: AppSpacing.xl,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
