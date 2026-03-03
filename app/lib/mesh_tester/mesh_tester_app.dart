import 'package:flutter/material.dart';

import 'theme.dart';
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
      theme: ModernMinimalTheme.light,
      home: const TesterScreen(),
    );
  }
}
