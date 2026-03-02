import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/backend_sync.dart';
import '../services/mesh/packet_store.dart';

class ConnectivityProvider extends ChangeNotifier {
  final BackendSync _backendSync;
  bool _isOnline = false;
  StreamSubscription? _sub;

  bool get isOnline => _isOnline;

  ConnectivityProvider(PacketStore store)
      : _backendSync = BackendSync(store);

  Future<void> start() async {
    _sub = _backendSync.onConnectivityChanged.listen((online) {
      _isOnline = online;
      notifyListeners();
    });

    await _backendSync.start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _backendSync.dispose();
    super.dispose();
  }
}
