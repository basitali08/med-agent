import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ══════════════════════════════════════════════════════════════════
///  MED AGENT — Modern Healthcare Design System
///  Inspired by HealthSync AI: clean, professional, gradient-rich
/// ══════════════════════════════════════════════════════════════════

class AppColors {
  // ── Brand / Primary ──
  static const primary = Color(0xFF22C55E);        // emerald-500
  static const primaryDark = Color(0xFF16A34A);     // emerald-600
  static const primaryLight = Color(0xFF86EFAC);    // emerald-300

  // ── Secondary ──
  static const secondary = Color(0xFF2563EB);       // blue-600
  static const secondaryDark = Color(0xFF1D4ED8);   // blue-700
  static const secondaryLight = Color(0xFF93C5FD);  // blue-300

  // ── Accent ──
  static const accent = Color(0xFFFACC15);          // yellow-400

  // ── Semantic ──
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);         // amber-500
  static const danger = Color(0xFFEF4444);          // red-500
  static const info = Color(0xFF3B82F6);            // blue-500

  // ── Backgrounds (Light mode) ──
  static const background = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF1F5F9);

  // ── Backgrounds (Dark mode) ──
  static const darkBg = Color(0xFF0F172A);          // slate-900
  static const darkSurface = Color(0xFF1E293B);     // slate-800
  static const darkSurface2 = Color(0xFF334155);    // slate-700

  // ── Text (Light mode) ──
  static const textDark = Color(0xFF1E293B);
  static const textMuted = Color(0xFF64748B);
  static const textLight = Color(0xFF94A3B8);
  static const textOnPrimary = Color(0xFFFFFFFF);

  // ── Border ──
  static const border = Color(0xFFE2E8F0);
  static const borderLight = Color(0xFFF1F5F9);

  // ── Backward-compat aliases (old neon names → new healthcare colors) ──
  static const neonCyan = primary;
  static const neonBlue = secondary;
  static const neonPurple = accent;
  static const neonGreen = primary;
  static const neonRed = danger;
  static const neonOrange = warning;
  static const neonMagenta = Color(0xFFEC4899);
  static const neonYellow = accent;

  static const deepBg = background;
  static const surface1 = surface;
  static const surface2 = surfaceVariant;
  static const surface3 = border;

  static const textPrimary = textDark;
  static const textSecondary = textMuted;

  // ── Gradients ──
  static const appGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradCyan = [primary, secondary];
  static const gradPurple = [secondary, primary];
  static const gradGreen = [primary, primaryDark];
  static const gradRed = [danger, warning];
  static const gradBlue = [secondary, secondaryLight];
  static const gradMagenta = [Color(0xFFEC4899), Color(0xFFF472B6)];

  // ── Radii ──
  static const radius = 16.0;
  static const radiusSmall = 12.0;
  static const radiusLarge = 20.0;
  static const radiusXLarge = 28.0;

  static Color neonGlow(Color c, [double a = 0.4]) => c.withValues(alpha: a);
}

class AppText {
  static const title = 28.0;
  static const heading = 22.0;
  static const cardTitle = 18.0;
  static const body = 16.0;
  static const caption = 13.0;
}

/// ══════════════════════════════════════════════════════════════════
///  Glass card decorations — frosted glass with soft shadows
/// ══════════════════════════════════════════════════════════════════
class Card3D {
  static BoxDecoration glass({
    Color borderColor = AppColors.border,
    double borderOpacity = 0.4,
    List<Color>? gradient,
    Color? backgroundColor,
  }) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(AppColors.radius),
        color: backgroundColor ?? AppColors.surface,
        gradient: gradient != null
            ? LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        border: Border.all(
          color: borderColor.withValues(alpha: borderOpacity),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static BoxDecoration light({List<Color>? gradient}) => glass(gradient: gradient);
  static BoxDecoration dark({List<Color>? gradient}) => glass(gradient: gradient);
}

/// ══════════════════════════════════════════════════════════════════
///  Theme Data — Light & Dark healthcare themes
/// ══════════════════════════════════════════════════════════════════
class AppTheme {
  // ── Light Theme ──
  static ThemeData get light {
    final textTheme = GoogleFonts.poppinsTextTheme(
      TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textDark),
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textDark),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textDark),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.textDark),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textMuted),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.textLight),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textOnPrimary),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.accent,
        surface: AppColors.surface,
        onPrimary: AppColors.textOnPrimary,
        onSurface: AppColors.textDark,
        error: AppColors.danger,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textDark,
        ),
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.danger)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintStyle: const TextStyle(color: AppColors.textLight),
      ),
      dividerColor: AppColors.border,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurface,
        contentTextStyle: GoogleFonts.poppins(color: AppColors.textOnPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Dark Theme ──
  static ThemeData get dark {
    final textTheme = GoogleFonts.poppinsTextTheme(
      TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textOnPrimary),
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textOnPrimary),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textOnPrimary),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textOnPrimary),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textOnPrimary),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.textOnPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textLight),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.textLight),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textOnPrimary),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textLight),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.accent,
        surface: AppColors.darkSurface,
        onPrimary: AppColors.textOnPrimary,
        onSurface: AppColors.textOnPrimary,
        error: AppColors.danger,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radius),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textOnPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textOnPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        labelStyle: TextStyle(color: AppColors.textLight),
        hintStyle: TextStyle(color: AppColors.textLight.withValues(alpha: 0.5)),
      ),
      dividerColor: Colors.white.withValues(alpha: 0.1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurface2,
        contentTextStyle: GoogleFonts.poppins(color: AppColors.textOnPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Convenience ──
  static InputDecoration inputDecoration(String label, IconData icon, {Color? iconColor}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.surface,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      );

  /// Gradient background for screens
  static BoxDecoration screenBackground({bool dark = false}) => BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? [AppColors.darkBg, AppColors.darkSurface.withValues(alpha: 0.5), AppColors.darkBg]
              : [AppColors.background, AppColors.accent.withValues(alpha: 0.08), AppColors.secondary.withValues(alpha: 0.05)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
}
