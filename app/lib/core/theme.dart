import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _bg = Color(0xFF0F0F1A);
  static const _surface = Color(0xFF1A1A2E);
  static const _card = Color(0xFF16213E);
  static const _primary = Color(0xFFFF4444); // Emergency red
  static const _secondary = Color(0xFF00D9FF); // Cyan accent
  static const _text = Color(0xFFE4E4E7);
  static const _textMuted = Color(0xFF71717A);

  static const emergencyRed = _primary;
  static const cyan = _secondary;
  static const bg = _bg;
  static const surface = _surface;
  static const card = _card;
  static const textColor = _text;
  static const textMuted = _textMuted;

  // Emergency type colors
  static const fireColor = Color(0xFFFF4444);
  static const medicalColor = Color(0xFF4488FF);
  static const structuralColor = Color(0xFFFF8800);
  static const floodColor = Color(0xFF00CCCC);
  static const hazmatColor = Color(0xFFAA44FF);
  static const otherColor = Color(0xFF888888);

  static Color colorForType(String type) {
    switch (type) {
      case 'fire':
        return fireColor;
      case 'medical':
        return medicalColor;
      case 'structural':
        return structuralColor;
      case 'flood':
        return floodColor;
      case 'hazmat':
        return hazmatColor;
      default:
        return otherColor;
    }
  }

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: _primary,
      secondary: _secondary,
      surface: _surface,
    ),
    scaffoldBackgroundColor: _bg,
    textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: _text,
      displayColor: _text,
    ),
    cardTheme: CardThemeData(
      color: _card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _secondary.withValues(alpha: 0.15)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _secondary.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _secondary.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _secondary, width: 2),
      ),
      labelStyle: const TextStyle(color: _textMuted),
      hintStyle: const TextStyle(color: _textMuted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: _bg,
      foregroundColor: _text,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: _text,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: _surface,
      selectedItemColor: _primary,
      unselectedItemColor: _textMuted,
    ),
  );

  static BoxDecoration glowBox({Color color = _primary}) => BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    color: _card,
    boxShadow: [
      BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: -5),
    ],
  );
}
