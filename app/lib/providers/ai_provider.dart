import 'package:flutter/foundation.dart';

import '../services/ai/ai_service.dart';

class AiProvider extends ChangeNotifier {
  final AiService _aiService = AiService();
  String _statusMessage = 'Initializing...';
  bool _isReady = false;
  bool _isInitializing = false;
  double _progress = 0;

  AiService get aiService => _aiService;
  String get statusMessage => _statusMessage;
  bool get isReady => _isReady;
  bool get isInitializing => _isInitializing;
  double get progress => _progress;

  Future<void> initialize() async {
    if (_isInitializing || _isReady) return;
    _isInitializing = true;
    notifyListeners();

    _aiService.initProgress.listen((msg) {
      _statusMessage = msg;

      // Parse progress percentage
      final match = RegExp(r'(\d+)%').firstMatch(msg);
      if (match != null) {
        _progress = int.parse(match.group(1)!) / 100;
      }

      if (msg == 'Ready') {
        _isReady = true;
        _isInitializing = false;
        _progress = 1.0;
      }
      notifyListeners();
    });

    try {
      await _aiService.initialize();
    } catch (e) {
      _statusMessage = 'Failed to initialize AI: $e';
      _isInitializing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }
}
