import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// iOS system colors used throughout the app.
abstract class AppColors {
  static const scaffold = Color(0xFFF2F2F7);
  static const surface = Color(0xFFFFFFFF);
  static const separator = Color(0xFFE5E5EA);
  static const textPrimary = Color(0xFF1C1C1E);
  static const textSecondary = Color(0xFF6D6D72);
  static const textTertiary = Color(0xFFAEAEB2);
  static const blue = Color(0xFF007AFF);
  static const green = Color(0xFF34C759);
  static const red = Color(0xFFFF3B30);
  static const orange = Color(0xFFFF9500);
  static const purple = Color(0xFFAF52DE);
  static const logBackground = Color(0xFFF8F8FB);
}

/// Typography helpers — Inter for UI, Source Code Pro for monospace.
abstract class AppType {
  static TextStyle stat() => GoogleFonts.inter(
        fontSize: 22,
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
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
      );
}
