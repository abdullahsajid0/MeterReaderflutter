import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF0F172A); // slate-900
  static const Color background = Color(0xFFF1F5F9); // slate-100 (slightly darker than F8FAFC for better contrast with white cards)
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B); // slate-800
  static const Color textSecondary = Color(0xFF64748B); // slate-500
  static const Color accent = Color(0xFF3B82F6); // blue-500
  static const Color accentGradient = Color(0xFF60A5FA); // blue-400
  static const Color success = Color(0xFF10B981); // emerald-500
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color danger = Color(0xFFEF4444); // red-500
  static const Color border = Color(0xFFE2E8F0); // slate-200

  static ThemeData get light {
    final textTheme = GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold),
      displaySmall: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(color: textPrimary, fontSize: 16),
      bodyMedium: GoogleFonts.inter(color: textSecondary, fontSize: 14),
      labelLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    );

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: accent,
        secondary: accentGradient,
        surface: surface,
        error: danger,
        onPrimary: Colors.white,
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 6,
        shadowColor: const Color(0xFF94A3B8).withOpacity(0.2), // soft modern shadow
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 0.5),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textSecondary.withOpacity(0.6),
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
        elevation: 16,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primary.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
      ),
    );
  }
}
