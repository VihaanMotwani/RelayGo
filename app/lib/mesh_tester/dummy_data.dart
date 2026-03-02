import 'package:uuid/uuid.dart';

import '../models/emergency_report.dart';
import '../models/mesh_message.dart';

/// Generates a fixed set of test packets for BLE mesh validation.
///
/// 5 EmergencyReports + 3 MeshMessages = 8 total packets,
/// with varied types, locations, and broadcast/DM mix.
class DummyData {
  static const _uuid = Uuid();
  static const String _deviceId = 'tester-device-001';
  static const String _deviceName = 'MeshTester';

  /// Generate 5 emergency reports covering different types and locations.
  static List<EmergencyReport> generateReports() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return [
      EmergencyReport(
        id: _uuid.v4(),
        ts: now,
        lat: 37.7749,
        lng: -122.4194,
        acc: 10,
        type: 'fire',
        urg: 5,
        haz: ['smoke', 'fire_spread'],
        desc: 'Building fire downtown, 3rd floor',
        src: _deviceId,
      ),
      EmergencyReport(
        id: _uuid.v4(),
        ts: now - 30,
        lat: 37.7751,
        lng: -122.4180,
        acc: 15,
        type: 'medical',
        urg: 4,
        haz: ['unconscious_person'],
        desc: 'Person collapsed on Market St',
        src: _deviceId,
      ),
      EmergencyReport(
        id: _uuid.v4(),
        ts: now - 60,
        lat: 37.7730,
        lng: -122.4200,
        acc: 8,
        type: 'structural',
        urg: 3,
        haz: ['debris'],
        desc: 'Partial wall collapse at 5th Ave',
        src: _deviceId,
      ),
      EmergencyReport(
        id: _uuid.v4(),
        ts: now - 90,
        lat: 37.7760,
        lng: -122.4220,
        acc: 20,
        type: 'flood',
        urg: 3,
        haz: ['rising_water'],
        desc: 'Street flooding on Main St',
        src: _deviceId,
      ),
      EmergencyReport(
        id: _uuid.v4(),
        ts: now - 120,
        lat: 37.7740,
        lng: -122.4210,
        acc: 12,
        type: 'hazmat',
        urg: 4,
        haz: ['gas_leak', 'chemical_spill'],
        desc: 'Gas leak near intersection',
        src: _deviceId,
      ),
    ];
  }

  /// Generate 3 messages: 2 broadcasts + 1 DM.
  static List<MeshMessage> generateMessages({String? dmTarget}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return [
      MeshMessage(
        id: _uuid.v4(),
        ts: now,
        src: _deviceId,
        name: _deviceName,
        to: null, // broadcast
        body: 'Road blocked on 5th St — use alternate route via Oak St',
      ),
      MeshMessage(
        id: _uuid.v4(),
        ts: now - 15,
        src: _deviceId,
        name: _deviceName,
        to: null, // broadcast
        body: 'Shelter open at Central Park community center',
      ),
      MeshMessage(
        id: _uuid.v4(),
        ts: now - 45,
        src: _deviceId,
        name: _deviceName,
        to: dmTarget, // DM if target provided, otherwise broadcast
        body: 'Are you safe? We are at the park.',
      ),
    ];
  }
}
