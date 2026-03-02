import 'package:flutter/material.dart';

import 'mesh_tester_app.dart';

/// Alternate entry point for the BLE mesh tester.
///
/// Run with:
///   flutter run -t lib/mesh_tester/main_tester.dart
///
/// This launches a standalone tester app that exercises the real
/// BLE mesh stack without the full RelayGo AI/chat/dashboard UI.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MeshTesterApp());
}
