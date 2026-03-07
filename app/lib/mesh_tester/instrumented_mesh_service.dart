import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/emergency_report.dart';
import '../models/mesh_message.dart';
import '../models/mesh_packet.dart';
import '../models/peer_info.dart';
import '../services/mesh/mesh_service.dart';
import '../services/mesh/packet_store.dart';
import 'log_service.dart';

/// Wraps [MeshService] with logging hooks that push all events to [LogService].
///
/// CRITICAL: Uses a SHARED [PacketStore] so that preloaded data is visible
/// to the Central when it syncs with peers.
class InstrumentedMeshService {
  final PacketStore _store;
  final MeshService _meshService;
  final LogService _log = LogService.instance;

  StreamSubscription? _reportSub;
  StreamSubscription? _messageSub;
  StreamSubscription? _peerSub;

  int receivedReports = 0;
  int receivedMessages = 0;

  /// Live list of packet IDs currently in SQLite.
  List<String> storedPacketIds = [];

  final _statsController = StreamController<void>.broadcast();
  Stream<void> get onStatsChanged => _statsController.stream;

  /// Creates an instrumented mesh with a SHARED store and onLog wiring.
  InstrumentedMeshService()
    : _store = PacketStore(),
      _meshService = _buildMesh(PacketStore()) {
    throw UnsupportedError('Use InstrumentedMeshService.create() instead');
  }

  /// Proper constructor — shared store flows through to MeshService.
  InstrumentedMeshService._internal(this._store, this._meshService);

  /// Factory that ensures the PacketStore is shared between the tester and MeshService.
  factory InstrumentedMeshService.create() {
    final store = PacketStore();
    final log = LogService.instance;

    void onLog(String msg) {
      if (msg.startsWith('[MESH]')) {
        log.mesh(msg.replaceFirst('[MESH] ', ''));
      } else if (msg.contains('Scan') ||
          msg.contains('central') ||
          msg.contains('Connect') ||
          msg.contains('Wrote') ||
          msg.contains('Write') ||
          msg.contains('peer') ||
          msg.contains('MTU') ||
          msg.contains('━━━')) {
        log.central(msg);
      } else if (msg.contains('peripheral') ||
          msg.contains('dvertis') ||
          msg.contains('GATT') ||
          msg.contains('📥') ||
          msg.contains('Decoded') ||
          msg.contains('Hop') ||
          msg.contains('TTL') ||
          msg.contains('forwarding')) {
        log.peripheral(msg);
      } else {
        log.log('BLE', msg);
      }
    }

    final meshService = MeshService(store: store, onLog: onLog);
    return InstrumentedMeshService._internal(store, meshService);
  }

  static MeshService _buildMesh(PacketStore store) => MeshService(store: store);

  PacketStore get store => _store;

  /// Get this device's Bluetooth adapter address / identifier.
  Future<String> getDeviceAddress() async {
    try {
      final name = await FlutterBluePlus.adapterName;
      return name.isNotEmpty ? name : 'Unknown';
    } catch (_) {
      return 'Unavailable';
    }
  }

  /// Refresh the stored packet ID list from SQLite.
  Future<void> refreshStoredIds() async {
    storedPacketIds = await _store.getAllPacketIds();
    _statsController.add(null);
  }

  /// Start the mesh with full logging.
  Future<void> start() async {
    _log.mesh('Starting mesh service (Central + Peripheral)...');

    _reportSub = _meshService.onNewReport.listen(_onReport);
    _messageSub = _meshService.onNewMessage.listen(_onMessage);
    _peerSub = _meshService.onPeersChanged.listen(
      (p) => _onPeerCount(p.length),
    );

    try {
      await _meshService.start();
      _log.mesh('Mesh service started ✅');

      await refreshStoredIds();
      _log.store(
        'Initial store: ${storedPacketIds.length} packets [${storedPacketIds.map((id) => id.substring(0, 8)).join(", ")}]',
      );
    } catch (e) {
      _log.error('Mesh start failed: $e');
    }
  }

  /// Preload dummy packets into the SHARED store.
  Future<void> preloadReports(List<EmergencyReport> reports) async {
    _log.info('Preloading ${reports.length} emergency reports...');
    for (final r in reports) {
      final packet = MeshPacket.fromReport(r);
      final isNew = await _store.insertIfNew(packet);
      if (isNew) {
        _log.store('✅ Stored report ${r.id.substring(0, 8)}... type=${r.type}');
      } else {
        _log.store(
          '🔁 DEDUP: report ${r.id.substring(0, 8)}... already exists — skipped',
        );
      }
    }
    await _meshService.refreshOutbox();
    await refreshStoredIds();
  }

  Future<void> preloadMessages(List<MeshMessage> messages) async {
    _log.info('Preloading ${messages.length} mesh messages...');
    for (final m in messages) {
      final packet = MeshPacket.fromMessage(m);
      final isNew = await _store.insertIfNew(packet);
      if (isNew) {
        final target = m.to == null ? 'broadcast' : 'DM';
        _log.store('✅ Stored msg ${m.id.substring(0, 8)}... [$target]');
      } else {
        _log.store(
          '🔁 DEDUP: msg ${m.id.substring(0, 8)}... already exists — skipped',
        );
      }
    }
    await _meshService.refreshOutbox();
    await refreshStoredIds();
  }

  /// Inject a single user-confirmed emergency report into the mesh.
  ///
  /// Wraps the report as a [MeshPacket], stores it, and refreshes the outbox
  /// so the Central advertises it on the next scan cycle.
  Future<bool> injectReport(EmergencyReport report) async {
    final packet = MeshPacket.fromReport(report);
    final isNew = await _store.insertIfNew(packet);
    if (isNew) {
      _log.store(
        '📡 Injected report ${report.id.substring(0, 8)}... '
        'type=${report.type} urg=${report.urg}',
      );
      await _meshService.refreshOutbox();
      await refreshStoredIds();
    } else {
      _log.store(
        '🔁 DEDUP: report ${report.id.substring(0, 8)}... already exists',
      );
    }
    return isNew;
  }

  /// Clear database and reset counters.
  Future<void> resetDatabase() async {
    _log.info('Resetting database...');
    await _store.clearAll();
    storedPacketIds = [];
    receivedReports = 0;
    receivedMessages = 0;
    _log.info('Database cleared ✅');
    _statsController.add(null);
  }

  void _onReport(EmergencyReport report) {
    receivedReports++;
    _log.peripheral(
      '📥 NEW report ${report.id.substring(0, 8)}... '
      'type=${report.type} urg=${report.urg} hops=${report.hops}',
    );
    // Refresh stored IDs to reflect the new packet
    refreshStoredIds();
  }

  void _onMessage(MeshMessage message) {
    receivedMessages++;
    final target = message.to == null ? 'broadcast' : 'DM→${message.to}';
    _log.peripheral(
      '📥 NEW msg ${message.id.substring(0, 8)}... '
      '[$target] from=${message.name} hops=${message.hops}',
    );
    refreshStoredIds();
  }

  void _onPeerCount(int count) {
    _log.central('Peer count changed: $count');
    _statsController.add(null);
  }

  int get peerCount => _meshService.peerCount;
  List<PeerInfo> get peers => _meshService.peers;
  String get deviceId => _meshService.deviceId;
  String get displayName => _meshService.displayName;
  Stream<MeshMessage> get onNewMessage => _meshService.onNewMessage;
  Stream<EmergencyReport> get onNewReport => _meshService.onNewReport;
  List<MeshMessage> get messages => _meshService.messages;

  Future<bool> sendDirectMessage(
    String targetDeviceId,
    MeshMessage message,
  ) async {
    _log.mesh('📤 Sending DM to $targetDeviceId');
    return await _meshService.sendDirectMessage(targetDeviceId, message);
  }

  /// Manually force a sync to the backend. Returns the status message.
  Future<String> forceBackendSync() async {
    return await _meshService.forceBackendSync();
  }

  /// Stop the mesh.
  Future<void> stop() async {
    _log.mesh('Stopping mesh service...');
    await _reportSub?.cancel();
    await _messageSub?.cancel();
    await _peerSub?.cancel();
    await _meshService.stop();
    _log.mesh('Mesh service stopped');
  }

  void dispose() {
    stop();
    _meshService.dispose();
    _statsController.close();
  }
}
