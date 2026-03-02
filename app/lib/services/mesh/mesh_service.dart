import 'dart:async';

import '../../models/emergency_report.dart';
import '../../models/mesh_message.dart';
import '../../models/mesh_packet.dart';
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

  Stream<EmergencyReport> get onNewReport => _reportController.stream;
  Stream<MeshMessage> get onNewMessage => _messageController.stream;
  Stream<int> get onPeerCountChanged => _central.onPeerCountChanged;
  int get peerCount => _central.peerCount;

  MeshService({PacketStore? store})
      : _store = store ?? PacketStore(),
        _peripheral = BlePeripheralService(),
        _central = BleCentralService();

  PacketStore get store => _store;

  Future<void> start() async {
    // Listen for incoming packets from peripheral
    _peripheralSub = _peripheral.onPacketReceived.listen(_handleIncomingPacket);

    // Start both BLE roles
    await _peripheral.start();
    await _central.start();

    // Feed existing packets to central for sync
    await _refreshCentralPackets();
  }

  Future<void> _handleIncomingPacket(MeshPacket packet) async {
    final isNew = await _store.insertIfNew(packet);
    if (!isNew) return; // Duplicate, already seen

    if (packet.isReport && packet.report != null) {
      _reportController.add(packet.report!);
    } else if (packet.isMessage && packet.message != null) {
      _messageController.add(packet.message!);
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
  }

  void dispose() {
    stop();
    _peripheral.dispose();
    _central.dispose();
    _reportController.close();
    _messageController.close();
  }
}
