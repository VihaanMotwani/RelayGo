import 'package:flutter/material.dart';

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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF58A6FF),
          surface: Color(0xFF161B22),
          error: Color(0xFFF85149),
        ),
        fontFamily: 'Roboto',
      ),
      home: const TesterScreen(),
    );
  }
}
