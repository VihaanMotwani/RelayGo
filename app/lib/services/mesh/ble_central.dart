import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants.dart';
import '../../models/mesh_packet.dart';

class BleCentralService {
  Timer? _scanTimer;
  final Set<String> _connectedDeviceIds = {};
  List<MeshPacket> _localPackets = [];
  int _peerCount = 0;
  bool _syncing = false; // true while a scan+sync cycle is running

  /// Tracks which packet IDs we've already written to each peer.
  /// Key = peer device ID, Value = set of packet IDs already sent.
  /// This prevents the gossip "echo" problem where packets bounce
  /// infinitely between two nodes.
  final Map<String, Set<String>> _sentToPeer = {};

  /// Optional log callback — wired by InstrumentedMeshService for the tester.
  final void Function(String)? onLog;

  int get peerCount => _peerCount;

  final _peerCountController = StreamController<int>.broadcast();
  Stream<int> get onPeerCountChanged => _peerCountController.stream;

  BleCentralService({this.onLog});

  void _log(String msg) => onLog?.call(msg);

  void updateLocalPackets(List<MeshPacket> packets) {
    _localPackets = packets;
    _log('Local packet queue updated: ${packets.length} total packets');
  }

  Future<void> start() async {
    _log(
      'Starting central — scan interval: ${BleConstants.scanInterval.inSeconds}s',
    );
    _scanTimer = Timer.periodic(
      BleConstants.scanInterval,
      (_) => _scanAndSync(),
    );
    _scanAndSync(); // Initial scan
  }

  Future<void> _scanAndSync() async {
    if (_syncing) {
      _log('Sync cycle already in progress, skipping');
      return;
    }
    _syncing = true;
    _log('━━━ Scan cycle started ━━━');

    try {
      // ── Phase 1: Scan for RelayGo peers ──
      final Map<String, BluetoothDevice> foundPeers = {};

      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final hasRelayGoService = result.advertisementData.serviceUuids.any(
            (uuid) =>
                uuid.str.toLowerCase() ==
                BleConstants.serviceUuid.toLowerCase(),
          );
          if (hasRelayGoService) {
            final deviceId = result.device.remoteId.str;
            if (!foundPeers.containsKey(deviceId)) {
              final name = result.device.platformName.isNotEmpty
                  ? result.device.platformName
                  : 'Unknown';
              _log('  📡 RelayGo peer: $name ($deviceId) RSSI=${result.rssi}');
              foundPeers[deviceId] = result.device;
            }
          }
        }
      });

      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.serviceUuid)],
        timeout: const Duration(seconds: 10),
      );
      await Future.delayed(const Duration(seconds: 11));
      subscription.cancel();

      final meshPeers = foundPeers.length;
      _log('Scan complete: $meshPeers RelayGo peer(s) found');
      if (_peerCount != meshPeers) {
        _peerCount = meshPeers;
        _peerCountController.add(_peerCount);
      }

      // ── Phase 2: Sync with each peer (scan is stopped) ──
      for (final entry in foundPeers.entries) {
        if (!_connectedDeviceIds.contains(entry.key)) {
          await _connectAndSync(entry.value);
        }
      }

      _log('━━━ Scan cycle ended ━━━');
    } catch (e) {
      _log('❌ Scan failed: $e');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _connectAndSync(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;
    _connectedDeviceIds.add(deviceId);

    try {
      _log('Connecting to $deviceId...');
      await device.connect(
        timeout: const Duration(seconds: 8),
        autoConnect: false,
      );
      _log('Connected to $deviceId ✅');

      // Negotiate larger MTU
      int mtu = BleConstants.fallbackMtu;
      try {
        mtu = await device.requestMtu(BleConstants.requestMtu);
        _log('MTU negotiated: $mtu bytes');
      } catch (e) {
        _log('⚠️ MTU negotiation failed, using ${BleConstants.fallbackMtu}B');
      }
      final maxPayload = mtu - 3;

      _log('Discovering services on $deviceId...');
      final services = await device.discoverServices();

      bool foundChar = false;
      for (final service in services) {
        if (service.uuid.str.toLowerCase() ==
            BleConstants.serviceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            if (char.uuid.str.toLowerCase() ==
                BleConstants.packetCharUuid.toLowerCase()) {
              foundChar = true;

              // ── Dedup: only send packets this peer hasn't seen ──
              final alreadySent = _sentToPeer[deviceId] ?? <String>{};
              final toSend = _localPackets
                  .where((p) => !alreadySent.contains(p.id))
                  .toList();

              if (toSend.isEmpty) {
                _log('Peer $deviceId is up-to-date — 0 new packets to send');
              } else {
                _log(
                  'Sending ${toSend.length} NEW packet(s) to $deviceId (${alreadySent.length} already sent before, ${_localPackets.length} total)',
                );
                await _writePackets(char, deviceId, maxPayload, toSend);
              }
            }
          }
        }
      }

      if (!foundChar) {
        _log('⚠️ RelayGo characteristic NOT found on $deviceId');
      }

      await device.disconnect();
      _log('Disconnected from $deviceId');
    } catch (e) {
      _log('❌ Sync with $deviceId failed: $e');
    } finally {
      _connectedDeviceIds.remove(deviceId);
    }
  }

  Future<void> _writePackets(
    BluetoothCharacteristic char,
    String peerId,
    int maxPayload,
    List<MeshPacket> packetsToSend,
  ) async {
    // Ensure the sent-set exists for this peer
    _sentToPeer.putIfAbsent(peerId, () => <String>{});

    int written = 0;
    int skipped = 0;
    for (final packet in packetsToSend) {
      try {
        final bytes = packet.toBytes();
        if (bytes.length <= maxPayload) {
          await char.write(bytes, withoutResponse: true);
          written++;
          _sentToPeer[peerId]!.add(packet.id); // Mark as sent to this peer
          _log(
            '  → Wrote ${packet.kind} ${packet.id.substring(0, 8)}... (${bytes.length}B hops=${packet.hops})',
          );
          await Future.delayed(const Duration(milliseconds: 50));
        } else {
          skipped++;
          _log(
            '  ⚠️ Skipped ${packet.id.substring(0, 8)}... — ${bytes.length}B > ${maxPayload}B',
          );
        }
      } catch (e) {
        _log('  ❌ Write failed for ${packet.id.substring(0, 8)}...: $e');
        break;
      }
    }
    _log('Write complete → $peerId: $written sent, $skipped skipped');
  }

  Future<void> stop() async {
    _log('Stopping central...');
    _scanTimer?.cancel();
    _scanTimer = null;
    await FlutterBluePlus.stopScan();
    _log('Central stopped');
  }

  void dispose() {
    stop();
    _peerCountController.close();
  }
}
