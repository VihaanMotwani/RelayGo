import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants.dart';
import '../../models/mesh_packet.dart';

class BleCentralService {
  Timer? _scanTimer;
  final Set<String> _connectedDeviceIds = {};
  List<MeshPacket> _localPackets = [];
  int _peerCount = 0;

  int get peerCount => _peerCount;

  final _peerCountController = StreamController<int>.broadcast();
  Stream<int> get onPeerCountChanged => _peerCountController.stream;

  void updateLocalPackets(List<MeshPacket> packets) {
    _localPackets = packets;
  }

  Future<void> start() async {
    // Begin periodic scanning
    _scanTimer = Timer.periodic(BleConstants.scanInterval, (_) => _scan());
    // Initial scan
    _scan();
  }

  Future<void> _scan() async {
    try {
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final deviceId = result.device.remoteId.str;
          if (!_connectedDeviceIds.contains(deviceId)) {
            _connectAndSync(result.device);
          }
        }
        _peerCount = results.length;
        _peerCountController.add(_peerCount);
      });

      await FlutterBluePlus.startScan(
        withServices: [Guid(BleConstants.serviceUuid)],
        timeout: const Duration(seconds: 10),
      );

      await Future.delayed(const Duration(seconds: 12));
      subscription.cancel();
    } catch (e) {
      // Scan failed, will retry next cycle
    }
  }

  Future<void> _connectAndSync(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;
    _connectedDeviceIds.add(deviceId);

    try {
      await device.connect(timeout: const Duration(seconds: 5));
      final services = await device.discoverServices();

      for (final service in services) {
        if (service.uuid.str.toLowerCase() == BleConstants.serviceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            if (char.uuid.str.toLowerCase() == BleConstants.packetCharUuid.toLowerCase()) {
              // Write all local packets to the peer
              await _writePackets(char);
            }
          }
        }
      }

      await device.disconnect();
    } catch (e) {
      // Connection failed, will retry next scan
    } finally {
      _connectedDeviceIds.remove(deviceId);
    }
  }

  Future<void> _writePackets(BluetoothCharacteristic char) async {
    for (final packet in _localPackets) {
      try {
        final bytes = packet.toBytes();
        // Respect MTU limit
        if (bytes.length <= BleConstants.maxMtu) {
          await char.write(bytes, withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 50));
        }
      } catch (e) {
        break; // Connection likely lost
      }
    }
  }

  Future<void> stop() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    await FlutterBluePlus.stopScan();
  }

  void dispose() {
    stop();
    _peerCountController.close();
  }
}
