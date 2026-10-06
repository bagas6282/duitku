import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
// Palet mengikuti Duitku brand: royal-blue accent di atas dark navy surface.
// Referensi: Revolut (zero-shadow flat depth) + Coinbase (blue-trust fintech).

class AppColors {
  const AppColors._();

  // Surfaces
  static const Color void0     = Color(0xFF080B12); // paling gelap — scaffold dark
  static const Color void1     = Color(0xFF0F1420); // card base dark
  static const Color void2     = Color(0xFF151C2E); // card raised dark
  static const Color frost     = Color(0xFFF0F2F8); // scaffold light
  static const Color frostCard = Color(0xFFFFFFFF); // card light

  // Brand — royal blue
  static const Color royal     = Color(0xFF1D4ED8); // primary CTA, links
  static const Color royalSoft = Color(0xFF2563EB); // hover / pressed
  static const Color royalMist = Color(0xFF1D4ED8); // 12% opacity tint backgrounds

  // Accent — mint (income / positive)
  static const Color mint      = Color(0xFF14B87A);
  static const Color mintDeep  = Color(0xFF0E9F66);

  // Semantic
  static const Color danger    = Color(0xFFE5484D); // expense / error
  static const Color warn      = Color(0xFFF59E0B); // warning / budget 80%
  static const Color info      = Color(0xFF38BDF8); // transfer / neutral

  // Text
  static const Color textHi    = Color(0xFFF1F4FC); // heading dark mode
  static const Color textBody  = Color(0xFFB4BCCE); // body dark mode
  static const Color textMuted = Color(0xFF6B7487); // caption dark mode
  static const Color textHiL   = Color(0xFF0C1024); // heading light mode
  static const Color textBodyL = Color(0xFF3D4562); // body light mode
  static const Color textMutedL= Color(0xFF8490A8); // caption light mode

  // Chart — 8-hue categorical ramp, legible on dark & light
  static const List<Color> categorical = [
    mint,
    royal,
    Color(0xFFF59E0B),
    danger,
    Color(0xFFA78BFA),
    info,
    Color(0xFFF472B6),
    Color(0xFF4ADE80),
  ];

  static Color forRatio(double r) {
    if (r >= 1.0) return danger;
    if (r >= 0.8) return warn;
    return mint;
  }
}

class AppSpacing {
  const AppSpacing._();
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 24;
  static const double xxl = 32;
  static const double h3x = 48;
}

class AppRadius {
  const AppRadius._();
  static const double xs   = 8;
  static const double sm   = 12;
  static const double md   = 18;
  static const double lg   = 24;
  static const double xl   = 32;
  static const double pill = 999;
}

// ─── ThemeData factory ────────────────────────────────────────────────────────

class AppTheme {
  const AppTheme._();

  static ThemeData dark() {
    final cs = ColorScheme.dark(
      primary:       AppColors.royal,
      onPrimary:     AppColors.textHi,
      secondary:     AppColors.mint,
      onSecondary:   AppColors.void0,
      surface:       AppColors.void1,
      onSurface:     AppColors.textHi,
      error:         AppColors.danger,
      onError:       AppColors.textHi,
      surfaceContainerHighest: AppColors.void2,
      outline:       const Color(0xFF252D42),
    );
    return _build(cs, brightness: Brightness.dark);
  }

  static ThemeData light() {
    final cs = ColorScheme.light(
      primary:       AppColors.royal,
      onPrimary:     Colors.white,
      secondary:     AppColors.mint,
      onSecondary:   Colors.white,
      surface:       AppColors.frost,
      onSurface:     AppColors.textHiL,
      error:         AppColors.danger,
      onError:       Colors.white,
      surfaceContainerHighest: AppColors.frostCard,
      outline:       const Color(0xFFDDE2F0),
    );
    return _build(cs, brightness: Brightness.light);
  }

  static ThemeData _build(ColorScheme cs, {required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3:     true,
      colorScheme:      cs,
      brightness:       brightness,
      scaffoldBackgroundColor: isDark ? AppColors.void0 : AppColors.frost,
      fontFamily:       'Inter',

      // ── AppBar ────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor:  isDark ? AppColors.void0 : AppColors.frost,
        surfaceTintColor: Colors.transparent,
        shadowColor:      Colors.transparent,
        elevation:        0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize:     18,
          fontWeight:   FontWeight.w700,
          letterSpacing:-0.5,
          color:        isDark ? AppColors.textHi : AppColors.textHiL,
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppColors.textBody : AppColors.textBodyL,
        ),
      ),

      // ── Card ──────────────────────────────────────────────────────────
      cardTheme: CardTheme(
        elevation:    0,
        color:        isDark ? AppColors.void1 : AppColors.frostCard,
        shape:        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: isDark
                ? const Color(0xFF1E2840)
                : const Color(0xFFE4E9F4),
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Buttons ───────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor:  AppColors.royal,
          foregroundColor:  Colors.white,
          minimumSize:      const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: const TextStyle(
            fontSize:     16,
            fontWeight:   FontWeight.w600,
            letterSpacing:-0.2,
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.textHi : AppColors.textHiL,
          minimumSize:     const Size.fromHeight(52),
          side: BorderSide(
            color: isDark
                ? const Color(0xFF252D42)
                : const Color(0xFFD0D8EE),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: const TextStyle(
            fontSize:     16,
            fontWeight:   FontWeight.w600,
            letterSpacing:-0.2,
          ),
          elevation: 0,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.royal,
          textStyle: const TextStyle(
            fontSize:   14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input ─────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   isDark ? AppColors.void2 : const Color(0xFFF4F7FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF1E2840)
                : const Color(0xFFDDE3F5),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.royal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(
          color:    isDark ? AppColors.textMuted : AppColors.textMutedL,
          fontSize: 15,
        ),
        labelStyle: TextStyle(
          color:    isDark ? AppColors.textBody : AppColors.textBodyL,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        floatingLabelStyle: TextStyle(
          color:    AppColors.royal,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),

      // ── BottomNavBar ──────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:    isDark ? AppColors.void1 : AppColors.frostCard,
        surfaceTintColor:   Colors.transparent,
        shadowColor:        Colors.transparent,
        elevation:          0,
        indicatorColor:     AppColors.royal.withOpacity(0.14),
        labelTextStyle:     WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize:   11,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color:      s.contains(WidgetState.selected)
              ? AppColors.royal
              : (isDark ? AppColors.textMuted : AppColors.textMutedL),
        )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.royal
              : (isDark ? AppColors.textMuted : AppColors.textMutedL),
          size: 22,
        )),
      ),

      // ── Divider ───────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color:    isDark ? const Color(0xFF1A2036) : const Color(0xFFE8EDF8),
        thickness: 1,
        space:    1,
      ),

      // ── Chip ──────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.void2 : const Color(0xFFF0F3FF),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF1E2840)
              : const Color(0xFFD8DFFF),
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelStyle: TextStyle(
          fontSize:   13,
          fontWeight: FontWeight.w600,
          color:      isDark ? AppColors.textBody : AppColors.textBodyL,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // ── ListTile ──────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor:    Colors.transparent,
        shape:        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical:   AppSpacing.xs,
        ),
      ),

      // ── Snackbar ──────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior:         SnackBarBehavior.floating,
        backgroundColor:  isDark ? AppColors.void2 : AppColors.textHiL,
        contentTextStyle: TextStyle(
          color:      isDark ? AppColors.textHi : Colors.white,
          fontSize:   14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),

      // ── BottomSheet ───────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor:   isDark ? AppColors.void1 : AppColors.frostCard,
        surfaceTintColor:  Colors.transparent,
        elevation:         0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
      ),

      // ── Dialog ────────────────────────────────────────────────────────
      dialogTheme: DialogTheme(
        backgroundColor:  isDark ? AppColors.void1 : AppColors.frostCard,
        surfaceTintColor: Colors.transparent,
        elevation:        0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      // ── Switch ────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.royal
              : (isDark ? AppColors.void2 : const Color(0xFFD8DFF0)),
        ),
      ),

      // ── ProgressIndicator ─────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.royal,
      ),

      // ── Text ──────────────────────────────────────────────────────────
      textTheme: TextTheme(
        displayLarge:  _t(isDark, 57, FontWeight.w700, -2.0),
        displayMedium: _t(isDark, 45, FontWeight.w700, -1.5),
        displaySmall:  _t(isDark, 36, FontWeight.w700, -1.0),
        headlineLarge: _t(isDark, 32, FontWeight.w700, -0.8),
        headlineMedium:_t(isDark, 26, FontWeight.w700, -0.5),
        headlineSmall: _t(isDark, 22, FontWeight.w600, -0.3),
        titleLarge:    _t(isDark, 18, FontWeight.w700, -0.4),
        titleMedium:   _t(isDark, 16, FontWeight.w600, -0.2),
        titleSmall:    _t(isDark, 14, FontWeight.w600, -0.1),
        bodyLarge:     _t(isDark, 16, FontWeight.w400,  0.1),
        bodyMedium:    _t(isDark, 14, FontWeight.w400,  0.1),
        bodySmall:     _t(isDark, 12, FontWeight.w400,  0.2),
        labelLarge:    _t(isDark, 14, FontWeight.w600, -0.1),
        labelMedium:   _t(isDark, 12, FontWeight.w600,  0.0),
        labelSmall:    _t(isDark, 11, FontWeight.w600,  0.2),
      ),
    );
  }

  static TextStyle _t(bool isDark, double size, FontWeight w, double ls) =>
      TextStyle(
        fontSize:      size,
        fontWeight:    w,
        letterSpacing: ls,
        color: isDark ? AppColors.textHi : AppColors.textHiL,
        height: 1.3,
      );
}
