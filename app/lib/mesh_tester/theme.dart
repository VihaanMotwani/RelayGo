import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class ModernMinimalTheme {
  static const _primary = Color(0xFF6366F1);    // Indigo
  static const _surface = Color(0xFFFAFAFA);
  static const _card = Colors.white;
  static const _text = Color(0xFF1F2937);
  static const _textMuted = Color(0xFF6B7280);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: _primary,
      secondary: _primary.withOpacity(0.8),
      surface: _surface,
    ),
    scaffoldBackgroundColor: _surface,
    textTheme: GoogleFonts.interTextTheme().apply(
      bodyColor: _text,
      displayColor: _text,
    ),
    dividerColor: Colors.grey.shade200,
    cardTheme: CardThemeData(
      color: _card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _surface,
      foregroundColor: _text,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _text,
      ),
    ),
  );
}

/// Kept for backwards compatibility while migrating screens to Spacing/ModernMinimalTheme concepts
abstract class AppColors {
  static const scaffold = Color(0xFFFAFAFA);
  static const surface = Colors.white;
  static const separator = Color(0xFFE5E7EB);
  static const textPrimary = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF4B5563);
  static const textTertiary = Color(0xFF9CA3AF);
  static const primary = Color(0xFF6366F1); // Indigo
  
  // Incident type colors adjusted to be modern and slightly muted from raw bold colors
  static const blue = Color(0xFF3B82F6);
  static const green = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF59E0B);
  static const purple = Color(0xFF8B5CF6);
  static const logBackground = Color(0xFFF3F4F6);
}

/// Kept for compatibility with existing widgets
abstract class AppType {
  static TextStyle stat() => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle title() => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle body() => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle label() => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle sectionHeader() => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
        letterSpacing: 1.2,
      );

  static TextStyle monoSmall() => GoogleFonts.sourceCodePro(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
      );
}
