import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/platform_bridge.dart';

/// RelayGo Flutter Module - Headless Service Layer
///
/// This module provides:
/// - On-device AI (Cactus LLM, STT, RAG)
/// - BLE mesh networking
/// - Backend sync
///
/// UI is handled by native platforms:
/// - iOS: SwiftUI (ios-native/)
/// - Android: Jetpack Compose (android-native/)
///
/// Communication via Platform Channels (com.relaygo/bridge)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize the platform bridge
  // This sets up method channel handlers for native UI communication
  PlatformBridge.instance;

  // Run minimal app to keep Flutter engine alive
  runApp(const _HeadlessApp());

  print('RelayGo Flutter service layer ready');
}

/// Minimal app - no UI, just keeps Flutter engine running
class _HeadlessApp extends StatelessWidget {
  const _HeadlessApp();

  @override
  Widget build(BuildContext context) {
    // Transparent container - native UI handles everything
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SizedBox.shrink(),
    );
  }
}
