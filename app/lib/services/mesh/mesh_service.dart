import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/emergency_report.dart';
import '../../models/mesh_message.dart';
import '../../models/mesh_packet.dart';
import '../../models/peer_info.dart';
import '../backend_sync.dart';
import 'ble_central.dart';
import 'ble_peripheral.dart';
import 'packet_store.dart';

class MeshService {
  final PacketStore _store;
  final BlePeripheralService _peripheral;
  final BleCentralService _central;
  late final BackendSync _backendSync;
  StreamSubscription? _peripheralSub;
  StreamSubscription? _peripheralMessageSub;

  /// Optional log callback for observability.
  final void Function(String)? onLog;

  final _reportController = StreamController<EmergencyReport>.broadcast();
  final _messageController = StreamController<MeshMessage>.broadcast();
  final _packetController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStatusController = StreamController<String>.broadcast();

  Stream<EmergencyReport> get onNewReport => _reportController.stream;
  Stream<MeshMessage> get onNewMessage => _messageController.stream;
  Stream<List<PeerInfo>> get onPeersChanged => _central.onPeersChanged;
  Stream<Map<String, dynamic>> get onPacketReceived => _packetController.stream;
  Stream<String> get onConnectionStatusChanged =>
      _connectionStatusController.stream;

  int get peerCount => _central.peerCount;
  bool get isConnected => _isConnected;

  bool _isConnected = false;
  bool _relayEnabled = false;
  String _deviceId = '';
  String _displayName = 'User';

  String get deviceId => _deviceId;
  String get displayName => _displayName;
  bool get isRelayEnabled => _relayEnabled;

  // Cached lists
  List<EmergencyReport> _reports = [];
  List<MeshMessage> _messages = [];
  List<PeerInfo> _peers = [];

  List<EmergencyReport> get reports => _reports;
  List<MeshMessage> get messages => _messages;
  List<PeerInfo> get peers => _peers;

  MeshService({PacketStore? store, this.onLog})
    : _store = store ?? PacketStore(),
      _peripheral = BlePeripheralService(onLog: onLog),
      _central = BleCentralService(onLog: onLog) {
    _backendSync = BackendSync(
      _store,
      onLog: onLog,
      getDeviceId: () => _deviceId,
    );
    _initIdentity();
  }

  Future<void> _initIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('relaygo_device_id') ?? const Uuid().v4();
    _displayName = prefs.getString('relaygo_display_name') ?? 'User';
    _relayEnabled = prefs.getBool('relaygo_relay_enabled') ?? false;
    await prefs.setString('relaygo_device_id', _deviceId);
  }

  Future<void> setDisplayName(String name) async {
    _displayName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('relaygo_display_name', name);
  }

  Future<void> setRelayEnabled(bool enabled) async {
    _relayEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('relaygo_relay_enabled', enabled);

    if (enabled && !_isConnected) {
      await start();
    } else if (!enabled && _isConnected) {
      await stop();
    }
  }

  PacketStore get store => _store;

  void _log(String msg) => onLog?.call(msg);

  Future<void> start() async {
    // Listen for incoming packets from peripheral
    _peripheralSub = _peripheral.onPacketReceived.listen(_handleIncomingPacket);
    _peripheralMessageSub = _peripheral.onMessageReceived.listen(
      _handleIncomingMessage,
    );

    _central.onPeersChanged.listen((newPeers) {
      _peers = newPeers;
    });
    await _peripheral.start();
    await _central.start();
    await _backendSync.start();

    // Feed existing packets to central for sync
    await refreshOutbox();

    // Load cached data
    _reports = await _store.getAllReports();
    _messages = await _store.getAllMessages();

    _isConnected = true;
    _connectionStatusController.add('connected');
  }

  Future<void> _handleIncomingPacket(MeshPacket packet) async {
    _log(
      '[MESH] Incoming ${packet.kind} ${packet.id.substring(0, 8)}... from peripheral',
    );
    final isNew = await _store.insertIfNew(packet);
    if (!isNew) {
      _log(
        '[MESH] Duplicate ${packet.id.substring(0, 8)}... — already in store, skipping',
      );
      return;
    }

    _log(
      '[MESH] NEW ${packet.kind} ${packet.id.substring(0, 8)}... inserted into store ✅',
    );

    if (packet.isReport && packet.report != null) {
      _reports.insert(0, packet.report!);
      _reportController.add(packet.report!);
      _packetController.add({'kind': 'report', ...packet.report!.toJson()});
    }

    // Update central's packet list for forwarding
    await refreshOutbox();
  }

  Future<void> _handleIncomingMessage(MeshMessage message) async {
    _log('[MESH] Received DM from ${message.name}');
    final isNew = await _store.insertMessage(message);
    if (!isNew) return; // Prevent duplicates

    _messages.insert(0, message);
    _messageController.add(message);
    _packetController.add({'kind': 'message', ...message.toJson()});
  }

  /// Manually force a sync to the backend. Returns the status message.
  Future<String> forceBackendSync() async {
    return await _backendSync.syncNow();
  }

  /// Refresh the central's outbox from the store.
  /// Call after preloading data to ensure the central picks it up.
  Future<void> refreshOutbox() async {
    final reports = await _store.getAllReports();
    // Messages are excluded from the outbox to prevent mesh-flooding.
    final allPackets = reports.map(MeshPacket.fromReport).toList();

    _log(
      '[MESH] Refreshed central queue: ${allPackets.length} packets (Reports only)',
    );
    _central.updateLocalPackets(allPackets);
  }

  Future<void> broadcastReport(EmergencyReport report) async {
    final packet = MeshPacket.fromReport(report);
    await _store.insertIfNew(packet);
    _reportController.add(report);
    await refreshOutbox();
  }

  Future<bool> sendDirectMessage(
    String targetDeviceId,
    MeshMessage message,
  ) async {
    final success = await _central.sendDirectMessage(targetDeviceId, message);
    if (success) {
      await _store.insertMessage(message);
      _messages.insert(0, message);
      _messageController.add(message);
    }
    return success;
  }

  Future<void> stop() async {
    await _peripheralSub?.cancel();
    await _peripheralMessageSub?.cancel();
    await _peripheral.stop();
    await _central.stop();
    _backendSync.stop();
    _isConnected = false;
    _connectionStatusController.add('disconnected');
  }

  void dispose() {
    stop();
    _peripheral.dispose();
    _central.dispose();
    _backendSync.dispose();
    _reportController.close();
    _messageController.close();
    _packetController.close();
    _connectionStatusController.close();
  }
}
