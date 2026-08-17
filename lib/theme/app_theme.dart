import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand & Palette Tokens
  static const Color primary = Color(0xFF0F172A); // slate-900
  static const Color background = Color(0xFFF8FAFC); // slate-50 (clean, bright canvas)
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A); // slate-900
  static const Color textSecondary = Color(0xFF64748B); // slate-500
  static const Color textMuted = Color(0xFF94A3B8); // slate-400
  
  static const Color accent = Color(0xFF2563EB); // blue-600 (vibrant energy)
  static const Color accentGradient = Color(0xFF3B82F6); // blue-500
  static const Color accentLight = Color(0xFFEFF6FF); // blue-50
  
  static const Color success = Color(0xFF059669); // emerald-600
  static const Color successLight = Color(0xFFECFDF5); // emerald-50
  
  static const Color warning = Color(0xFFD97706); // amber-600
  static const Color warningLight = Color(0xFFFFFBEB); // amber-50
  
  static const Color danger = Color(0xFFDC2626); // red-600
  static const Color dangerLight = Color(0xFFFEF2F2); // red-50
  
  static const Color border = Color(0xFFE2E8F0); // slate-200
  static const Color borderLight = Color(0xFFF1F5F9); // slate-100

  static ThemeData get light {
    final textTheme = GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.outfit(
        color: textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      displayMedium: GoogleFonts.outfit(
        color: textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      displaySmall: GoogleFonts.outfit(
        color: textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineMedium: GoogleFonts.outfit(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleLarge: GoogleFonts.outfit(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.outfit(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      titleSmall: GoogleFonts.outfit(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      bodyLarge: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 15,
        height: 1.45,
      ),
      bodyMedium: GoogleFonts.inter(
        color: textSecondary,
        fontSize: 14,
        height: 1.45,
      ),
      bodySmall: GoogleFonts.inter(
        color: textSecondary,
        fontSize: 12,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.inter(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.2,
      ),
      labelSmall: GoogleFonts.inter(
        color: textMuted,
        fontWeight: FontWeight.w600,
        fontSize: 11,
        letterSpacing: 0.5,
      ),
    );

    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: accent,
        secondary: accentGradient,
        surface: surface,
        error: danger,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
