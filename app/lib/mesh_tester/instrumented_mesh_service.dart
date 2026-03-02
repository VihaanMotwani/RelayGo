import 'dart:async';

import '../models/emergency_report.dart';
import '../models/mesh_message.dart';
import '../models/mesh_packet.dart';
import '../services/mesh/mesh_service.dart';
import '../services/mesh/packet_store.dart';
import 'log_service.dart';

/// Wraps [MeshService] with logging hooks that push all events to [LogService].
///
/// This does NOT modify production code. It decorates by composition:
/// listens to existing streams and logs every event for observability.
class InstrumentedMeshService {
  final MeshService _meshService;
  final PacketStore _store;
  final LogService _log = LogService.instance;

  StreamSubscription? _reportSub;
  StreamSubscription? _messageSub;
  StreamSubscription? _peerSub;

  int receivedReports = 0;
  int receivedMessages = 0;
  int storedReports = 0;
  int storedMessages = 0;

  final _statsController = StreamController<void>.broadcast();
  Stream<void> get onStatsChanged => _statsController.stream;

  InstrumentedMeshService()
      : _store = PacketStore(),
        _meshService = MeshService();

  PacketStore get store => _store;

  /// Start the mesh with full logging.
  Future<void> start() async {
    _log.mesh('Starting mesh service (Central + Peripheral)...');

    // Wire up logging before starting
    _reportSub = _meshService.onNewReport.listen(_onReport);
    _messageSub = _meshService.onNewMessage.listen(_onMessage);
    _peerSub = _meshService.onPeerCountChanged.listen(_onPeerCount);

    try {
      await _meshService.start();
      _log.mesh('Mesh service started ✅');

      // Log initial store state
      final reports = await _store.getAllReports();
      final messages = await _store.getAllMessages();
      storedReports = reports.length;
      storedMessages = messages.length;
      _log.store('Initial store: $storedReports reports, $storedMessages messages');
      _statsController.add(null);
    } catch (e) {
      _log.error('Mesh start failed: $e');
    }
  }

  /// Preload dummy packets into the store and refresh the mesh.
  Future<void> preloadReports(List<EmergencyReport> reports) async {
    _log.info('Preloading ${reports.length} emergency reports...');
    for (final r in reports) {
      final packet = MeshPacket.fromReport(r);
      final isNew = await _store.insertIfNew(packet);
      if (isNew) {
        storedReports++;
        _log.store('Stored report ${r.id.substring(0, 8)}... type=${r.type} urg=${r.urg}');
      } else {
        _log.store('Duplicate report ${r.id.substring(0, 8)}... — skipped');
      }
    }
    _statsController.add(null);
  }

  Future<void> preloadMessages(List<MeshMessage> messages) async {
    _log.info('Preloading ${messages.length} mesh messages...');
    for (final m in messages) {
      final packet = MeshPacket.fromMessage(m);
      final isNew = await _store.insertIfNew(packet);
      if (isNew) {
        storedMessages++;
        final target = m.to == null ? 'broadcast' : 'DM→${m.to!.substring(0, 8)}';
        _log.store('Stored message ${m.id.substring(0, 8)}... [$target] "${m.body.substring(0, 30)}..."');
      } else {
        _log.store('Duplicate message ${m.id.substring(0, 8)}... — skipped');
      }
    }
    _statsController.add(null);
  }

  void _onReport(EmergencyReport report) {
    receivedReports++;
    _log.peripheral(
      'Received report ${report.id.substring(0, 8)}... '
      'type=${report.type} urg=${report.urg} hops=${report.hops}',
    );
    _statsController.add(null);
  }

  void _onMessage(MeshMessage message) {
    receivedMessages++;
    final target = message.to == null ? 'broadcast' : 'DM→${message.to}';
    _log.peripheral(
      'Received message ${message.id.substring(0, 8)}... '
      '[$target] from=${message.name} hops=${message.hops}',
    );
    _statsController.add(null);
  }

  void _onPeerCount(int count) {
    _log.central('Peer count changed: $count');
    _statsController.add(null);
  }

  int get peerCount => _meshService.peerCount;

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
