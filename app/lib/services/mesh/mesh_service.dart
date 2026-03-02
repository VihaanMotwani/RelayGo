import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/emergency_report.dart';
import '../../models/mesh_message.dart';
import '../../models/mesh_packet.dart';
import '../../models/peer_info.dart';
import 'ble_central.dart';
import 'ble_peripheral.dart';
import 'packet_store.dart';

class MeshService {
  final PacketStore _store;
  final BlePeripheralService _peripheral;
  final BleCentralService _central;
  StreamSubscription? _peripheralSub;

  final _reportController = StreamController<EmergencyReport>.broadcast();
  final _messageController = StreamController<MeshMessage>.broadcast();
  final _packetController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStatusController = StreamController<String>.broadcast();

  Stream<EmergencyReport> get onNewReport => _reportController.stream;
  Stream<MeshMessage> get onNewMessage => _messageController.stream;
  Stream<int> get onPeerCountChanged => _central.onPeerCountChanged;
  Stream<Map<String, dynamic>> get onPacketReceived => _packetController.stream;
  Stream<String> get onConnectionStatusChanged => _connectionStatusController.stream;

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
  List<MeshMessage> get broadcastMessages => _messages.where((m) => m.to == null).toList();
  List<PeerInfo> get peers => _peers;

  MeshService({PacketStore? store})
      : _store = store ?? PacketStore(),
        _peripheral = BlePeripheralService(),
        _central = BleCentralService() {
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

  Future<void> start() async {
    // Listen for incoming packets from peripheral
    _peripheralSub = _peripheral.onPacketReceived.listen(_handleIncomingPacket);

    // Start both BLE roles
    await _peripheral.start();
    await _central.start();

    // Feed existing packets to central for sync
    await _refreshCentralPackets();

    // Load cached data
    _reports = await _store.getAllReports();
    _messages = await _store.getAllMessages();

    _isConnected = true;
    _connectionStatusController.add('connected');
  }

  Future<void> _handleIncomingPacket(MeshPacket packet) async {
    final isNew = await _store.insertIfNew(packet);
    if (!isNew) return; // Duplicate, already seen

    if (packet.isReport && packet.report != null) {
      _reports.insert(0, packet.report!);
      _reportController.add(packet.report!);
      _packetController.add({'kind': 'report', ...packet.report!.toJson()});
    } else if (packet.isMessage && packet.message != null) {
      _messages.insert(0, packet.message!);
      _messageController.add(packet.message!);
      _packetController.add({'kind': 'message', ...packet.message!.toJson()});
    }

    // Update central's packet list for forwarding
    await _refreshCentralPackets();
  }

  Future<void> _refreshCentralPackets() async {
    final reports = await _store.getAllReports();
    final messages = await _store.getAllMessages();
    final allPackets = [
      ...reports.map(MeshPacket.fromReport),
      ...messages.map(MeshPacket.fromMessage),
    ];
    _central.updateLocalPackets(allPackets);
  }

  Future<void> broadcastReport(EmergencyReport report) async {
    final packet = MeshPacket.fromReport(report);
    await _store.insertIfNew(packet);
    _reportController.add(report);
    await _refreshCentralPackets();
  }

  Future<void> broadcastMessage(MeshMessage message) async {
    final packet = MeshPacket.fromMessage(message);
    await _store.insertIfNew(packet);
    _messageController.add(message);
    await _refreshCentralPackets();
  }

  Future<void> stop() async {
    await _peripheralSub?.cancel();
    await _peripheral.stop();
    await _central.stop();
    _isConnected = false;
    _connectionStatusController.add('disconnected');
  }

  void dispose() {
    stop();
    _peripheral.dispose();
    _central.dispose();
    _reportController.close();
    _messageController.close();
    _packetController.close();
    _connectionStatusController.close();
  }
}
