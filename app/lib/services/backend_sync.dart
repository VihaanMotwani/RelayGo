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

  /// Optional log callback.
  final void Function(String)? onLog;

  bool get isOnline => _isOnline;

  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  BackendSync(this._store, {this.onLog});

  void _log(String msg) => onLog?.call(msg);

  Future<void> start() async {
    // Check initial connectivity
    final result = await Connectivity().checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
    _connectivityController.add(_isOnline);

    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((results) {
      _isOnline = !results.contains(ConnectivityResult.none);
      _connectivityController.add(_isOnline);
      if (_isOnline) syncNow();
    });

    // Periodic sync
    _syncTimer = Timer.periodic(BackendConfig.syncInterval, (_) => syncNow());
  }

  /// Manually trigger a sync. Returns a status message.
  Future<String> syncNow() async {
    if (_isSyncing) return 'Sync already in progress';
    _isSyncing = true;

    try {
      final packets = await _store.getUnuploaded();
      if (packets.isEmpty) {
        _log('Sync: 0 unuploaded packets.');
        return 'Up to date (0 packets to sync)';
      }

      _log('Sync: Found ${packets.length} packets to upload.');

      final body = jsonEncode({
        'packets': packets.map((p) => p.toJson()).toList(),
      });

      final uri = Uri.parse(
        '${BackendConfig.baseUrl}${BackendConfig.reportsEndpoint}',
      );
      _log('Sync: POSTing to $uri...');

      final response = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final repCount = data['inserted_reports'] ?? 0;
        final msgCount = data['inserted_messages'] ?? 0;

        await _store.markUploaded(packets.map((p) => p.id).toList());

        final result =
            'Sync Success: Sent ${packets.length} (Backend accepted: $repCount reports, $msgCount msgs)';
        _log(result);
        return result;
      } else {
        final err =
            'Sync Failed: HTTP ${response.statusCode} - ${response.body}';
        _log(err);
        return err;
      }
    } catch (e) {
      final err = 'Sync Error: $e';
      _log(err);
      return err;
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
