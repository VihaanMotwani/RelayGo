import 'dart:async';

import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'dart:typed_data';

import '../../core/constants.dart';
import '../../models/mesh_packet.dart';

class BlePeripheralService {
  final _packetController = StreamController<MeshPacket>.broadcast();
  Stream<MeshPacket> get onPacketReceived => _packetController.stream;
  bool _isAdvertising = false;

  /// Optional log callback — wired by InstrumentedMeshService for the tester.
  final void Function(String)? onLog;

  BlePeripheralService({this.onLog});

  void _log(String msg) => onLog?.call(msg);

  Future<void> start() async {
    _log('Initializing BLE peripheral...');
    await BlePeripheral.initialize();
    _log('BLE peripheral initialized ✅');

    // CRITICAL: On iOS, adding a service immediately after initialize() fails
    // because the internal CBPeripheralManager is not yet 'poweredOn'.
    _log('Waiting for Bluetooth adapter to be READY...');
    await fbp.FlutterBluePlus.adapterState
        .where((s) => s == fbp.BluetoothAdapterState.on)
        .first;
    // Add a tiny extra delay just to let the hardware settle
    await Future.delayed(const Duration(milliseconds: 300));

    // Add the RelayGo service with a writable characteristic
    _log('Adding GATT service ${BleConstants.serviceUuid.substring(0, 8)}...');
    await BlePeripheral.addService(
      BleService(
        uuid: BleConstants.serviceUuid,
        primary: true,
        characteristics: [
          BleCharacteristic(
            uuid: BleConstants.packetCharUuid,
            properties: [
              CharacteristicProperties.write.index,
              CharacteristicProperties.writeWithoutResponse.index,
            ],
            permissions: [AttributePermissions.writeable.index],
          ),
        ],
      ),
    );
    _log('GATT service added ✅');

    // Listen for writes from central devices
    BlePeripheral.setWriteRequestCallback((
      deviceId,
      characteristicId,
      offset,
      value,
    ) {
      _log(
        '📥 Write request from $deviceId — ${value?.length ?? 0} bytes (char: $characteristicId)',
      );
      if (value != null &&
          characteristicId.toLowerCase() ==
              BleConstants.packetCharUuid.toLowerCase()) {
        _handleIncomingData(Uint8List.fromList(value), deviceId);
      } else if (value != null) {
        _log(
          '  ⚠️ Characteristic mismatch — got: $characteristicId, expected: ${BleConstants.packetCharUuid}',
        );
      }
      return WriteRequestResult(
        offset: offset,
        status: 0, // 0 = success
      );
    });

    // Start advertising
    _log('Starting BLE advertisement...');
    await BlePeripheral.startAdvertising(
      services: [BleConstants.serviceUuid],
      localName: 'RelayGo',
    );
    _isAdvertising = true;
    _log(
      'Advertising as "RelayGo" ✅ (service: ${BleConstants.serviceUuid.substring(0, 8)}...)',
    );
  }

  void _handleIncomingData(Uint8List data, String fromDevice) {
    try {
      final packet = MeshPacket.fromBytes(data);
      _log(
        '  Decoded: ${packet.kind} id=${packet.id.substring(0, 8)}... hops=${packet.hops} ttl=${packet.ttl}',
      );

      // Increment hop count
      packet.hops = packet.hops + 1;
      _log('  Hop incremented: ${packet.hops - 1} → ${packet.hops}');

      // Check TTL
      if (packet.hops >= packet.ttl) {
        _log(
          '  ⛔ TTL expired (hops=${packet.hops} >= ttl=${packet.ttl}) — DROPPED',
        );
        return;
      }

      _log(
        '  ✅ Packet alive (hops=${packet.hops} < ttl=${packet.ttl}) — forwarding to store',
      );
      _packetController.add(packet);
    } catch (e) {
      _log('  ❌ Failed to decode packet (${data.length}B): $e');
    }
  }

  Future<void> stop() async {
    if (_isAdvertising) {
      _log('Stopping advertisement...');
      await BlePeripheral.stopAdvertising();
      _isAdvertising = false;
      _log('Advertisement stopped');
    }
  }

  void dispose() {
    _packetController.close();
  }
}
