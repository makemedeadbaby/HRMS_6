import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Core Palette ────────────────────────────────────────────────────────────
class AppColors {
  // Backgrounds
  static const bg = Color(0xFF141414);
  static const surface = Color(0xFF1E1E1E);
  static const surfaceAlt = Color(0xFF1A1A1A);
  static const divider = Color(0xFF2A2A2A);
  static const inputBg = Color(0xFF252525);

  // Text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF888888);
  static const textTertiary = Color(0xFF555555);

  // Status colors
  static const statusPresent = Color(0xFF22C55E);
  static const statusAbsent = Color(0xFFEF4444);
  static const statusHalfDay = Color(0xFFF59E0B);
  static const statusOnBreak = Color(0xFFFB923C);
  static const statusLate = Color(0xFFA78BFA);
  static const statusCheckedOut = Color(0xFF6B7280);
  static const statusNotCheckedIn = Color(0xFF555555);

  // Company accent colors
  static const accentLearningSaint = Color(0xFFF09B1A);
  static const accentKhushLifestyle = Color(0xFFD5815A);
  static const accentVibgyor = Color(0xFF6366F1);
  static const accentPossessivePanda = Color(0xFF4ADE80);
  static const accentDefault = Color(0xFF60A5FA);

  // Priority
  static const priorityUrgent = Color(0xFFEF4444);
  static const priorityImportant = Color(0xFFF59E0B);
  static const priorityNormal = Color(0xFF6B7280);

  // Utility
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const red = Color(0xFFEF4444);
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF59E0B);

  // ── Aliases for consistent naming across screens ─────────────────────────
  // background → bg
  static const background = bg;
  // cardBg → surface
  static const cardBg = surface;
  // accent → accentDefault (generic accent for new screens)
  static const accent = accentDefault;
  // textHint → textTertiary
  static const textHint = textTertiary;

  /// Returns the accent color for a given company name
  static Color companyAccent(String companyName) {
    final name = companyName.toLowerCase();
    if (name.contains('learning saint') || name.contains('learningsaint')) {
      return accentLearningSaint;
    } else if (name.contains('khush')) {
      return accentKhushLifestyle;
    } else if (name.contains('vibgyor')) {
      return accentVibgyor;
    } else if (name.contains('possessive') || name.contains('panda')) {
      return accentPossessivePanda;
    }
    return accentDefault;
  }

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
      case 'active':
      case 'in office':
        return statusPresent;
      case 'absent':
        return statusAbsent;
      case 'half day':
        return statusHalfDay;
      case 'on break':
        return statusOnBreak;
      case 'late':
        return statusLate;
      case 'checked out':
        return statusCheckedOut;
      default:
        return statusNotCheckedIn;
    }
  }
}

// ─── App Theme ────────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.white,
        secondary: AppColors.textSecondary,
        error: AppColors.statusAbsent,
        onSurface: AppColors.textPrimary,
        onPrimary: AppColors.black,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 32,
        ),
        displayMedium: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 28,
        ),
        headlineLarge: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 24,
        ),
        headlineMedium: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        titleLarge: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        titleMedium: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodyLarge: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w400,
          fontSize: 15,
        ),
        bodyMedium: GoogleFonts.inter(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        bodySmall: GoogleFonts.inter(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
        labelLarge: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.white, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.textTertiary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
          minimumSize: const Size(double.infinity, 52),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
          minimumSize: const Size(0, 48),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        selectedItemColor: AppColors.white,
        unselectedItemColor: AppColors.textTertiary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: GoogleFonts.inter(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
