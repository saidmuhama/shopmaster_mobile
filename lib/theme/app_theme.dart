import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary     = Color(0xFF0F2D1A);
  static const Color primaryMid  = Color(0xFF164D2E);
  static const Color primaryLight= Color(0xFF1E6B3F);
  static const Color accent      = Color(0xFFF4A261);
  static const Color accentDark  = Color(0xFFD97706);
  static const Color accentLight = Color(0xFFFBBF24);
  static const Color navy        = Color(0xFF12182E);
  static const Color navyMid     = Color(0xFF1C2E5E);
  static const Color gold        = Color(0xFFC49430);
  static const Color goldLight   = Color(0xFFE4C06A);
  static const Color success     = Color(0xFF059669);
  static const Color successBg   = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF047857);
  static const Color warning     = Color(0xFFD97706);
  static const Color warningBg   = Color(0xFFFEF3C7);
  static const Color danger      = Color(0xFFDC2626);
  static const Color dangerBg    = Color(0xFFFEE2E2);
  static const Color info        = Color(0xFF2563EB);
  static const Color infoBg      = Color(0xFFDBEAFE);
  static const Color bg          = Color(0xFFF2F4F7);
  static const Color surface     = Color(0xFFFFFFFF);
  static const Color surfaceAlt  = Color(0xFFF8FAFC);
  static const Color border      = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color textPrimary    = Color(0xFF0F172A);
  static const Color textSecondary  = Color(0xFF475569);
  static const Color textMuted      = Color(0xFF94A3B8);
  static const Color darkCard       = Color(0xFF1A3828);
  static const Color darkCardBorder = Color(0xFF2D5540);
}

class AppTextStyles {
  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
    fontSize: 28, fontWeight: FontWeight.w900,
    color: AppColors.textPrimary, letterSpacing: -1.2, height: 1.1);

  static TextStyle get displayMedium => GoogleFonts.plusJakartaSans(
    fontSize: 22, fontWeight: FontWeight.w900,
    color: AppColors.textPrimary, letterSpacing: -0.8, height: 1.1);

  static TextStyle get headingLarge => GoogleFonts.plusJakartaSans(
    fontSize: 18, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, letterSpacing: -0.4);

  static TextStyle get headingMedium => GoogleFonts.plusJakartaSans(
    fontSize: 16, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, letterSpacing: -0.3);

  static TextStyle get headingSmall => GoogleFonts.plusJakartaSans(
    fontSize: 14, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.2);

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w500,
    color: AppColors.textPrimary, height: 1.5);

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w500,
    color: AppColors.textSecondary, height: 1.4);

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: AppColors.textMuted, letterSpacing: 0.1);

  static TextStyle get label => GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w700,
    color: AppColors.textMuted, letterSpacing: 0.6);

  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontSize: 13, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary);

  // White variants
  static TextStyle get displayWhite => displayLarge.copyWith(color: Colors.white);
  static TextStyle get headingWhite => headingMedium.copyWith(color: Colors.white);
  static TextStyle get bodyWhite => bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.8));
}

class AppShadows {
  static List<BoxShadow> get sm => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 6, offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> get md => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 12, offset: const Offset(0, 4)),
    BoxShadow(color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 4, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> get lg => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.10),
      blurRadius: 24, offset: const Offset(0, 8)),
    BoxShadow(color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8, offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> get primary => [
    BoxShadow(color: AppColors.primary.withValues(alpha: 0.30),
      blurRadius: 20, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> get accent => [
    BoxShadow(color: AppColors.accent.withValues(alpha: 0.35),
      blurRadius: 16, offset: const Offset(0, 6)),
  ];

  static List<BoxShadow> get navy => [
    BoxShadow(color: AppColors.navy.withValues(alpha: 0.40),
      blurRadius: 24, offset: const Offset(0, 10)),
  ];
}

class AppTheme {
  static ThemeData get light {
    final base = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        background: AppColors.bg,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: base.copyWith(
        displayLarge: AppTextStyles.displayLarge,
        headlineLarge: AppTextStyles.headingLarge,
        titleLarge: AppTextStyles.headingMedium,
        titleMedium: AppTextStyles.headingSmall,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelSmall: AppTextStyles.label,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.headingWhite,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.06),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: AppTextStyles.bodyMedium,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}
