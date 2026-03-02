import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/ai/ai_service.dart';
import '../services/ai/awareness_service.dart';
import '../services/mesh/packet_store.dart';

class AwarenessProvider extends ChangeNotifier {
  final AwarenessService _awarenessService;
  AwarenessSummary _summary = AwarenessSummary.empty();
  bool _isGenerating = false;
  Timer? _refreshTimer;

  AwarenessSummary get summary => _summary;
  bool get isGenerating => _isGenerating;

  AwarenessProvider(AiService aiService, PacketStore store)
      : _awarenessService = AwarenessService(aiService, store);

  void startAutoRefresh() {
    // Refresh every 60 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => refresh(),
    );
  }

  Future<void> refresh({bool force = false}) async {
    if (_isGenerating) return;
    _isGenerating = true;
    notifyListeners();

    try {
      _summary = await _awarenessService.generateSummary(force: force);
    } catch (e) {
      // Keep existing summary on error
    }

    _isGenerating = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
