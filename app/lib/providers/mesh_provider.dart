import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/emergency_report.dart';
import '../services/mesh/mesh_service.dart';

class MeshProvider extends ChangeNotifier {
  final MeshService _meshService;
  int _peerCount = 0;
  final List<EmergencyReport> _reports = [];
  bool _isActive = false;

  StreamSubscription? _reportSub;
  StreamSubscription? _peerSub;

  int get peerCount => _peerCount;
  List<EmergencyReport> get reports => List.unmodifiable(_reports);
  bool get isActive => _isActive;
  MeshService get meshService => _meshService;

  MeshProvider(this._meshService);

  Future<void> start() async {
    _reportSub = _meshService.onNewReport.listen((report) {
      _reports.insert(0, report);
      notifyListeners();
    });

    _peerSub = _meshService.onPeerCountChanged.listen((count) {
      _peerCount = count;
      notifyListeners();
    });

    await _meshService.start();
    _isActive = true;

    // Load existing reports from store
    final existing = await _meshService.store.getAllReports();
    _reports.addAll(existing);
    notifyListeners();
  }

  Future<void> stop() async {
    await _reportSub?.cancel();
    await _peerSub?.cancel();
    await _meshService.stop();
    _isActive = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _meshService.dispose();
    super.dispose();
  }
}
