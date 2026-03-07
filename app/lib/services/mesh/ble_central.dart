import 'dart:async';
import 'dart:math';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants.dart';
import '../../models/mesh_packet.dart';
import '../../models/mesh_message.dart';
import '../../models/peer_info.dart';

/// BLE Central — Flood-Then-Dedup with Probabilistic Convergence
///
/// Protocol:
///   1. Scan for RelayGo peers.
///   2. Connect to each peer and write ALL local packets.
///   3. Receiver deduplicates via SQLite INSERT OR IGNORE.
///   4. After 2 quiet cycles (store unchanged), enter CONVERGED state.
///   5. While converged, each cycle has a 20% chance to re-flood anyway,
///      preventing local convergence from hiding global inconsistency
///      (e.g., A↔B converged but B→C hasn't synced yet).
class BleCentralService {
  Timer? _scanTimer;
  final Set<String> _connectedDeviceIds = {};
  List<MeshPacket> _localPackets = [];
  List<PeerInfo> _discoveredPeers = [];
  bool _syncing = false;

  // ── Convergence tracking ──
  int _lastKnownCount = -1;
  int _quietCycles = 0;
  bool _converged = false;
  static const int _quietCyclesNeeded = 2;
  static const double _reprobeChance =
      0.20; // 20% chance to re-flood when converged
  final _rng = Random();

  /// Optional log callback.
  final void Function(String)? onLog;

  int get peerCount => _discoveredPeers.length;
  List<PeerInfo> get discoveredPeers => _discoveredPeers;
  bool get isConverged => _converged;

  final _peersController = StreamController<List<PeerInfo>>.broadcast();
  Stream<List<PeerInfo>> get onPeersChanged => _peersController.stream;

  BleCentralService({this.onLog});

  void _log(String msg) => onLog?.call(msg);

  void updateLocalPackets(List<MeshPacket> packets) {
    final n = packets.length;
    if (n != _lastKnownCount) {
      if (_converged) {
        _log('⚡ New data ($n pkts) — convergence broken, resuming flood');
      }
      _converged = false;
      _quietCycles = 0;
      _lastKnownCount = n;
    }
    _localPackets = packets;
  }

  Future<void> start() async {
    _log(
      'Starting central — interval: ${BleConstants.scanInterval.inSeconds}s',
    );
    _scanTimer = Timer.periodic(
      BleConstants.scanInterval,
      (_) => _scanAndSync(),
    );
    _scanAndSync();
  }

  Future<void> _scanAndSync() async {
    if (_syncing) return;
    _syncing = true;

    // ── Decide whether to flood this cycle ──
    bool shouldFlood = !_converged;
    if (_converged) {
      final roll = _rng.nextDouble();
      if (roll < _reprobeChance) {
        shouldFlood = true;
        _log(
          '━━━ Scan cycle (CONVERGED but re-probing, roll=${roll.toStringAsFixed(2)}) ━━━',
        );
      } else {
        _log(
          '━━━ Scan cycle (CONVERGED — scan only, roll=${roll.toStringAsFixed(2)}) ━━━',
        );
      }
    } else {
      _log('━━━ Scan cycle (${_localPackets.length} pkts to flood) ━━━');
    }

    try {
      // ── Phase 1: Scan ──
      final Map<String, BluetoothDevice> foundPeers = {};

      final sub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final isRelayGo = r.advertisementData.serviceUuids.any(
            (u) =>
                u.str.toLowerCase() == BleConstants.serviceUuid.toLowerCase(),
          );
          if (isRelayGo) {
            final id = r.device.remoteId.str;
            if (!foundPeers.containsKey(id)) {
              final name = r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : 'Unknown';
              _log('  📡 $name ($id) RSSI=${r.rssi}');
              foundPeers[id] = r.device;
            }
          }
        }
      });

      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.serviceUuid)],
        timeout: const Duration(seconds: 10),
      );
      await Future.delayed(const Duration(seconds: 11));
      sub.cancel();

      final newPeers = foundPeers.entries
          .map(
            (e) => PeerInfo(
              deviceId: e.key,
              displayName: e.value.platformName.isNotEmpty
                  ? e.value.platformName
                  : 'Relay Node',
              rssi:
                  0, // We could track RSSI if needed but FlutterBlue doesn't cache it on device easily outside of the result.
            ),
          )
          .toList();

      _log('Scan: ${newPeers.length} peer(s)');
      _discoveredPeers = newPeers;
      _peersController.add(_discoveredPeers);

      // ── Phase 2: Flood if needed ──
      if (!shouldFlood) {
        _log('Flood skipped this cycle');
      } else if (foundPeers.isEmpty) {
        _log('No peers — nothing to flood');
      } else {
        for (final entry in foundPeers.entries) {
          if (!_connectedDeviceIds.contains(entry.key)) {
            await _connectAndFlood(entry.value);
          }
        }
      }

      // ── Phase 3: Update convergence based on store growth ──
      if (foundPeers.isNotEmpty && !_converged) {
        final storeGrew = (_localPackets.length != _lastKnownCount);
        if (storeGrew) {
          _quietCycles = 0;
        } else {
          _quietCycles++;
          _log('Quiet cycle #$_quietCycles/$_quietCyclesNeeded');
          if (_quietCycles >= _quietCyclesNeeded) {
            _converged = true;
            _log(
              '✅ CONVERGED — flooding paused (${_reprobeChance * 100}% reprobe chance per cycle)',
            );
          }
        }
      }

      _log('━━━ Scan cycle ended ━━━');
    } catch (e) {
      _log('❌ Scan failed: $e');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _connectAndFlood(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;
    _connectedDeviceIds.add(deviceId);

    try {
      _log('[$deviceId] Connecting...');
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );
      _log('[$deviceId] Connected ✅');

      int mtu = BleConstants.fallbackMtu;
      try {
        mtu = await device.requestMtu(BleConstants.requestMtu);
        _log('[$deviceId] MTU=$mtu');
      } catch (e) {
        _log('[$deviceId] MTU failed → ${BleConstants.fallbackMtu}B');
      }
      final maxPayload = mtu - 3;

      final services = await device.discoverServices();
      BluetoothCharacteristic? packetChar;
      for (final svc in services) {
        if (svc.uuid.str.toLowerCase() ==
            BleConstants.serviceUuid.toLowerCase()) {
          for (final char in svc.characteristics) {
            if (char.uuid.str.toLowerCase() ==
                BleConstants.packetCharUuid.toLowerCase()) {
              packetChar = char;
              break;
            }
          }
        }
        if (packetChar != null) break;
      }

      if (packetChar == null) {
        _log('[$deviceId] ⚠️ Char not found');
        await device.disconnect();
        return;
      }

      final snapshot = List<MeshPacket>.from(_localPackets);
      if (snapshot.isEmpty) {
        _log('[$deviceId] Outbox empty');
      } else {
        _log('[$deviceId] Flooding ${snapshot.length} pkt(s)...');
        await _floodPackets(packetChar, deviceId, maxPayload, snapshot);
      }

      await device.disconnect();
      _log('[$deviceId] Disconnected');
    } catch (e) {
      _log('[$deviceId] ❌ Failed: $e');
      try {
        await device.disconnect();
      } catch (_) {}
    } finally {
      _connectedDeviceIds.remove(deviceId);
    }
  }

  Future<void> _floodPackets(
    BluetoothCharacteristic char,
    String peerId,
    int maxPayload,
    List<MeshPacket> packets,
  ) async {
    int sent = 0;
    for (final packet in packets) {
      final sid = packet.id.substring(0, 8);
      try {
        final bytes = packet.toBytes();
        if (bytes.length > maxPayload) {
          _log('  [$peerId] ⚠️ $sid ${bytes.length}B > limit — skip');
          continue;
        }

        try {
          await char.write(bytes, withoutResponse: true);
        } catch (e) {
          _log('  [$peerId] ↻ $sid busy, retry 150ms');
          await Future.delayed(const Duration(milliseconds: 150));
          await char.write(bytes, withoutResponse: true);
        }

        sent++;
        _log(
          '  [$peerId] → ${packet.kind} $sid ${bytes.length}B h=${packet.hops}',
        );
        await Future.delayed(const Duration(milliseconds: 80));
      } catch (e) {
        _log('  [$peerId] ❌ $sid failed: $e — aborting');
        break;
      }
    }
    _log('[$peerId] $sent/${packets.length} sent');
  }

  Future<bool> sendDirectMessage(
    String targetDeviceId,
    MeshMessage message,
  ) async {
    final device = BluetoothDevice.fromId(targetDeviceId);
    _log('DM: Connecting to [$targetDeviceId]...');
    try {
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );
      _log('DM: Connected to [$targetDeviceId] ✅');

      int mtu = BleConstants.fallbackMtu;
      try {
        mtu = await device.requestMtu(BleConstants.requestMtu);
      } catch (_) {
        _log('DM: MTU request failed, using fallback.');
      }
      final maxPayload = mtu - 3;

      final services = await device.discoverServices();
      BluetoothCharacteristic? messageChar;
      for (final svc in services) {
        if (svc.uuid.str.toLowerCase() ==
            BleConstants.serviceUuid.toLowerCase()) {
          for (final char in svc.characteristics) {
            if (char.uuid.str.toLowerCase() ==
                BleConstants.messageCharUuid.toLowerCase()) {
              messageChar = char;
              break;
            }
          }
        }
        if (messageChar != null) break;
      }

      if (messageChar == null) {
        _log('DM: ⚠️ messageChar not found on [$targetDeviceId]');
        await device.disconnect();
        return false;
      }

      final packet = MeshPacket.fromMessage(message);
      final bytes = packet.toBytes();
      if (bytes.length > maxPayload) {
        _log('DM: ⚠️ Message too large (${bytes.length} > $maxPayload)');
        await device.disconnect();
        return false;
      }

      await messageChar.write(bytes, withoutResponse: true);
      _log('DM: ✅ Successfully sent to [$targetDeviceId]');
      await device.disconnect();
      return true;
    } catch (e) {
      _log('DM: ❌ Failed to send to [$targetDeviceId]: $e');
      try {
        await device.disconnect();
      } catch (_) {}
      return false;
    }
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
    _peersController.close();
  }
}
