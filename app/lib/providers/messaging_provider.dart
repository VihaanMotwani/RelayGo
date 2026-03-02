import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/mesh_message.dart';
import '../services/mesh/mesh_service.dart';

class MessagingProvider extends ChangeNotifier {
  final MeshService _meshService;
  final String _deviceId;
  final String _displayName;

  final List<MeshMessage> _broadcastMessages = [];
  final Map<String, List<MeshMessage>> _dmThreads = {};
  final Map<String, int> _unreadCounts = {};
  StreamSubscription? _messageSub;

  List<MeshMessage> get broadcastMessages =>
      List.unmodifiable(_broadcastMessages);

  Map<String, List<MeshMessage>> get dmThreads =>
      Map.unmodifiable(_dmThreads);

  int get totalUnreadCount =>
      _unreadCounts.values.fold(0, (a, b) => a + b);

  MessagingProvider(this._meshService, this._deviceId, this._displayName);

  Future<void> start() async {
    _messageSub = _meshService.onNewMessage.listen(_handleMessage);

    // Load existing messages from store
    final existing = await _meshService.store.getAllMessages();
    for (final msg in existing) {
      _sortMessage(msg);
    }
    notifyListeners();
  }

  void _handleMessage(MeshMessage message) {
    _sortMessage(message);
    // Count as unread if it's a DM to us
    if (message.to == _deviceId) {
      _unreadCounts[message.src] = (_unreadCounts[message.src] ?? 0) + 1;
    }
    notifyListeners();
  }

  void _sortMessage(MeshMessage message) {
    if (message.isBroadcast) {
      _broadcastMessages.insert(0, message);
    } else if (message.to == _deviceId || message.src == _deviceId) {
      // DM relevant to us
      final peerId = message.src == _deviceId ? message.to! : message.src;
      _dmThreads.putIfAbsent(peerId, () => []);
      _dmThreads[peerId]!.add(message);
      _dmThreads[peerId]!.sort((a, b) => a.ts.compareTo(b.ts));
    }
  }

  Future<void> sendBroadcast(String text) async {
    final message = MeshMessage(
      id: const Uuid().v4(),
      ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      src: _deviceId,
      name: _displayName,
      body: text,
    );

    await _meshService.broadcastMessage(message);
  }

  Future<void> sendDirectMessage(String peerId, String text) async {
    final message = MeshMessage(
      id: const Uuid().v4(),
      ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      src: _deviceId,
      name: _displayName,
      to: peerId,
      body: text,
    );

    await _meshService.broadcastMessage(message);
  }

  void markThreadRead(String peerId) {
    _unreadCounts[peerId] = 0;
    notifyListeners();
  }

  List<MeshMessage> getThread(String peerId) {
    return _dmThreads[peerId] ?? [];
  }

  int getUnreadCount(String peerId) {
    return _unreadCounts[peerId] ?? 0;
  }

  /// Get list of peer IDs that we have DM threads with
  List<String> get dmPeerIds => _dmThreads.keys.toList();

  /// Get the latest message in a DM thread
  MeshMessage? getLatestDm(String peerId) {
    final thread = _dmThreads[peerId];
    if (thread == null || thread.isEmpty) return null;
    return thread.last;
  }

  /// Get the display name for a peer from their messages
  String getPeerName(String peerId) {
    final thread = _dmThreads[peerId];
    if (thread == null || thread.isEmpty) return peerId.substring(0, 8);
    final peerMsg = thread.firstWhere(
      (m) => m.src == peerId,
      orElse: () => thread.first,
    );
    return peerMsg.name;
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }
}
