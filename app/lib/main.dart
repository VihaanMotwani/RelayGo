import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'app.dart';
import 'core/permissions.dart';
import 'providers/ai_provider.dart';
import 'providers/awareness_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/mesh_provider.dart';
import 'providers/messaging_provider.dart';
import 'services/mesh/mesh_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Dark status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  // Request permissions
  await PermissionHelper.requestAll();

  // Get or create device ID and display name
  final prefs = await SharedPreferences.getInstance();
  String deviceId = prefs.getString('device_id') ?? '';
  if (deviceId.isEmpty) {
    deviceId = const Uuid().v4().substring(0, 12);
    await prefs.setString('device_id', deviceId);
  }
  String displayName = prefs.getString('display_name') ?? '';
  if (displayName.isEmpty) {
    displayName = 'User-${deviceId.substring(0, 4)}';
    await prefs.setString('display_name', displayName);
  }

  // Initialize core services
  final meshService = MeshService();
  final aiProvider = AiProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: aiProvider),
        ChangeNotifierProvider(
          create: (_) => MeshProvider(meshService)..start(),
        ),
        ChangeNotifierProvider(
          create: (_) => ConnectivityProvider(meshService.store)..start(),
        ),
        ChangeNotifierProxyProvider<AiProvider, ChatProvider>(
          create: (_) => ChatProvider(
            aiProvider.aiService,
            meshService,
            deviceId,
          ),
          update: (_, ai, prev) => prev!,
        ),
        ChangeNotifierProvider(
          create: (_) => MessagingProvider(meshService, deviceId, displayName)
            ..start(),
        ),
        ChangeNotifierProxyProvider<AiProvider, AwarenessProvider>(
          create: (_) => AwarenessProvider(
            aiProvider.aiService,
            meshService.store,
          )..startAutoRefresh(),
          update: (_, ai, prev) => prev!,
        ),
      ],
      child: const RelayGoApp(),
    ),
  );

  // Start AI initialization (async, shows loading screen)
  aiProvider.initialize();
}
