import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import 'mesh/packet_store.dart';

class BackendSync {
  final PacketStore _store;
  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isOnline = false;

  bool get isOnline => _isOnline;

  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  BackendSync(this._store);

  Future<void> start() async {
    // Check initial connectivity
    final result = await Connectivity().checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
    _connectivityController.add(_isOnline);

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((results) {
      _isOnline = !results.contains(ConnectivityResult.none);
      _connectivityController.add(_isOnline);
      if (_isOnline) _sync();
    });

    // Periodic sync
    _syncTimer = Timer.periodic(BackendConfig.syncInterval, (_) => _sync());
  }

  Future<void> _sync() async {
    if (!_isOnline || _isSyncing) return;
    _isSyncing = true;

    try {
      final packets = await _store.getUnuploaded();
      if (packets.isEmpty) return;

      final body = jsonEncode({
        'packets': packets.map((p) => p.toJson()).toList(),
      });

      final response = await http.post(
        Uri.parse('${BackendConfig.baseUrl}${BackendConfig.reportsEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _store.markUploaded(packets.map((p) => p.id).toList());
      }
    } catch (e) {
      // Sync failed, will retry next cycle
    } finally {
      _isSyncing = false;
    }
  }

  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  void dispose() {
    stop();
    _connectivityController.close();
  }
}
