// Design tokens, light/dark theme configuration, and aviation-themed palette
// for the Flight Path app.
import 'package:flutter/material.dart';

/// Colour palette used throughout the app.
/// Uses a warm, sophisticated orange palette with aviation-inspired accents.
class AppColors {
  // ── Primary orange palette ──────────────────────────────────────────────
  static const Color primary = Color(0xFFE8742A);        // Warm sophisticated orange
  static const Color primaryBright = Color(0xFFFF6B00);   // Bright orange for CTAs only
  static const Color primaryDark = Color(0xFFBF5A1A);
  static const Color primaryLight = Color(0x1AE8742A);   // ~10% opacity for tints

  // ── Dark theme surfaces ─────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0A0E1A);   // Dark navy
  static const Color surfaceDark = Color(0xFF141928);
  static const Color surfaceVariantDark = Color(0xFF1E2538);
  static const Color surfaceElevatedDark = Color(0xFF1A2035); // Slightly lighter for hero cards
  static const Color onSurfaceDark = Color(0xFFECEFF4);
  // Lifted from #8A94A6 → #A6B0C2 to maintain ≥4.5:1 contrast on
  // surfaceDark (#141928) when widgets apply withValues(alpha: 0.5–0.7) to
  // titles and labels. Direct contrast: 7.4:1, ≈ 4.4:1 at alpha 0.6.
  static const Color onSurfaceVariantDark = Color(0xFFA6B0C2);
  static const Color dividerDark = Color(0xFF2A3045);

  // ── Light theme surfaces ────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFE3E8F0);   // Noticeable cool grey
  static const Color surfaceLight = Color(0xFFF8FAFC);       // Slightly tinted white
  static const Color surfaceVariantLight = Color(0xFFD8DEEA); // Inputs/chips
  static const Color onSurfaceLight = Color(0xFF1A1A2E);
  static const Color onSurfaceVariantLight = Color(0xFF6B7280);
  static const Color dividerLight = Color(0xFFC8D0DF);

  // ── Semantic colours ────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ── Lesson status colours ────────────────────────────────────────────────
  static const Color statusScheduled = Color(0xFF42A5F5);   // Blue — upcoming
  static const Color statusManualEntry = Color(0xFFAB47BC); // Purple — manually logged

  // ── Stat card accent colours ─────────────────────────────────────────────
  static const Color statHours = Color(0xFF4FC3F7);        // Sky blue — hours flown
  static const Color statExercises = Color(0xFFCE93D8);    // Lavender — exercises

  // ── Hero card gradient (dark theme) ─────────────────────────────────────
  static const Color heroGradientStart = Color(0xFF1E1006); // Warm dark brown
  static const Color heroGradientEnd = Color(0xFF141525);   // Deep navy

  // ── Achievement category colours ─────────────────────────────────────────
  static const Color achievementDedication = Color(0xFF8B5CF6); // Purple

  // ── Tinted colours (pre-computed for const contexts) ─────────────────────
  static const Color primaryBrightSubtle = Color(0x33FF6B00); // primaryBright @ 20%

  // ── Brightness-aware legacy accessors ────────────────────────────────────
  // These resolve to the correct light/dark variant based on the current
  // brightness set by [updateBrightness]. Call this from a widget near the
  // root that observes [Theme.of(context).brightness].
  //
  // For new code, prefer Theme.of(context).colorScheme or the explicit
  // dark/light variants above.
  static Brightness _brightness = Brightness.dark;

  /// Call from a widget that rebuilds on theme changes to keep the legacy
  /// accessors in sync with the active theme.
  static void updateBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  static bool get _isDark => _brightness == Brightness.dark;

  static Color get background => _isDark ? backgroundDark : backgroundLight;
  static Color get surface => _isDark ? surfaceDark : surfaceLight;
  static Color get surfaceVariant => _isDark ? surfaceVariantDark : surfaceVariantLight;
  static Color get onSurface => _isDark ? onSurfaceDark : onSurfaceLight;
  static Color get onSurfaceVariant => _isDark ? onSurfaceVariantDark : onSurfaceVariantLight;
  static Color get divider => _isDark ? dividerDark : dividerLight;
}

/// Spacing constants for consistent whitespace throughout the app.
class AppSpacing {
  /// Horizontal page padding (20px).
  static const double pagePadding = 20;
  /// Spacing between cards in a list (16px).
  static const double cardGap = 16;
  /// Spacing between sections (24px).
  static const double sectionGap = 24;
  /// Inner card padding (20px).
  static const double cardPadding = 20;

  /// Convenience EdgeInsets for page-level horizontal padding.
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: pagePadding);
  /// Convenience EdgeInsets for full page padding (horizontal + top).
  static const EdgeInsets pagePaddingAll = EdgeInsets.fromLTRB(pagePadding, 16, pagePadding, 0);
}

/// Provides both light and dark [ThemeData] for the app.
class AppTheme {
  // ── Dark theme ──────────────────────────────────────────────────────────
  static final ThemeData dark = _buildDark();
  // ── Light theme ─────────────────────────────────────────────────────────
  static final ThemeData light = _buildLight();

  static ThemeData _buildDark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryBright,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.onSurfaceDark,
        error: AppColors.error,
        outline: AppColors.dividerDark,
        surfaceContainerHighest: AppColors.surfaceVariantDark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.onSurfaceDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.onSurfaceDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.dividerDark, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariantDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBright,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          shadowColor: AppColors.primaryBright.withValues(alpha: 0.3),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurfaceDark,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
          minimumSize: const Size(double.infinity, 52),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 48),
          // padded (Material default) so a TextButton always meets the 48dp
          // tap target even when its child has compact padding (e.g. login
          // "Sign in" link, welcome "Skip" button).
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dividerDark, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.onSurfaceVariantDark),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 1,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.onSurfaceDark,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: AppColors.onSurfaceDark,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          color: AppColors.onSurfaceDark,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: AppColors.onSurfaceDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppColors.onSurfaceDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: AppColors.onSurfaceDark,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: AppColors.onSurfaceDark,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: AppColors.onSurfaceVariantDark,
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: AppColors.onSurfaceVariantDark,
          fontSize: 13,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: AppColors.onSurfaceVariantDark,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
        labelMedium: TextStyle(
          color: AppColors.onSurfaceVariantDark,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: AppColors.onSurfaceDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.onSurfaceVariantDark,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariantDark,
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: AppColors.dividerDark, width: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        contentPadding: EdgeInsets.symmetric(horizontal: 20),
        minTileHeight: 48,
      ),
    );
  }

  static ThemeData _buildLight() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryBright,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.onSurfaceLight,
        error: AppColors.error,
        outline: AppColors.dividerLight,
        surfaceContainerHighest: AppColors.surfaceVariantLight,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.onSurfaceLight,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.onSurfaceLight,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariantLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBright,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
          shadowColor: AppColors.primaryBright.withValues(alpha: 0.25),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurfaceLight,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
          minimumSize: const Size(double.infinity, 52),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariantLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dividerLight, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.onSurfaceVariantLight),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLight,
        thickness: 1,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.onSurfaceLight,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: AppColors.onSurfaceLight,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          color: AppColors.onSurfaceLight,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: AppColors.onSurfaceLight,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppColors.onSurfaceLight,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: AppColors.onSurfaceLight,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: AppColors.onSurfaceLight,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: AppColors.onSurfaceVariantLight,
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: AppColors.onSurfaceVariantLight,
          fontSize: 13,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: AppColors.onSurfaceVariantLight,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
        labelMedium: TextStyle(
          color: AppColors.onSurfaceVariantLight,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(
          color: AppColors.onSurfaceLight,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.onSurfaceVariantLight,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariantLight,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: AppColors.dividerLight, width: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 12,
        contentPadding: EdgeInsets.symmetric(horizontal: 20),
        minTileHeight: 48,
      ),
    );
  }
}

/// Extension on [BuildContext] for convenient access to theme-aware colours.
/// Use these instead of hardcoded AppColors in widget code.
extension FlightPathColors on BuildContext {
  ColorScheme get _cs => Theme.of(this).colorScheme;
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get fpBackground => _isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
  Color get fpSurface => _cs.surface;
  Color get fpSurfaceVariant => _isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight;
  Color get fpOnSurface => _cs.onSurface;
  Color get fpOnSurfaceVariant => _isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight;
  Color get fpDivider => _cs.outline;
  Color get fpPrimary => AppColors.primary;
  Color get fpPrimaryBright => AppColors.primaryBright;
  Color get fpPrimaryLight => AppColors.primaryLight;

  /// Hero card gradient — dark navy to slightly lighter for dark theme,
  /// subtle warm white gradient for light theme.
  LinearGradient get fpHeroGradient => _isDark
      ? const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceDark, AppColors.surfaceElevatedDark],
        )
      : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceLight,
            AppColors.primary.withValues(alpha: 0.03),
          ],
        );
}
