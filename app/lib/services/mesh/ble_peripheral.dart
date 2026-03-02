import 'dart:async';
import 'dart:typed_data';

import 'package:ble_peripheral/ble_peripheral.dart';

import '../../core/constants.dart';
import '../../models/mesh_packet.dart';

class BlePeripheralService {
  final _packetController = StreamController<MeshPacket>.broadcast();
  Stream<MeshPacket> get onPacketReceived => _packetController.stream;
  bool _isAdvertising = false;

  Future<void> start() async {
    await BlePeripheral.initialize();

    // Add the RelayGo service with a writable characteristic
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
            permissions: [
              AttributePermissions.writeable.index,
            ],
          ),
        ],
      ),
    );

    // Listen for writes from central devices
    BlePeripheral.setWriteRequestCallback(
      (deviceId, characteristicId, offset, value) {
        if (value != null && characteristicId == BleConstants.packetCharUuid) {
          _handleIncomingData(Uint8List.fromList(value));
        }
        return WriteRequestResult(
          characteristicId: characteristicId,
          offset: offset,
          status: true,
        );
      },
    );

    // Start advertising
    await BlePeripheral.startAdvertising(
      services: [BleConstants.serviceUuid],
      localName: 'RelayGo',
    );
    _isAdvertising = true;
  }

  void _handleIncomingData(Uint8List data) {
    try {
      final packet = MeshPacket.fromBytes(data);

      // Increment hop count
      packet.hops = packet.hops + 1;

      // Check TTL
      if (packet.hops >= packet.ttl) return;

      _packetController.add(packet);
    } catch (e) {
      // Malformed packet, ignore
    }
  }

  Future<void> stop() async {
    if (_isAdvertising) {
      await BlePeripheral.stopAdvertising();
      _isAdvertising = false;
    }
  }

  void dispose() {
    _packetController.close();
  }
}
