import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tester_screen.dart';

/// Minimal MaterialApp for the BLE mesh tester.
///
/// No providers, no AI, no backend sync — just the raw mesh + UI.
class MeshTesterApp extends StatelessWidget {
  const MeshTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RelayGo Mesh Tester',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF007AFF),
          surface: Color(0xFFFFFFFF),
          error: Color(0xFFFF3B30),
        ),
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1C1C1E),
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const TesterScreen(),
    );
  }
}
