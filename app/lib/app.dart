import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/ai_provider.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/loading_screen.dart';

class RelayGoApp extends StatelessWidget {
  const RelayGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RelayGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Consumer<AiProvider>(
        builder: (context, ai, _) {
          if (!ai.isReady) {
            return const LoadingScreen();
          }
          return const HomeScreen();
        },
      ),
    );
  }
}
