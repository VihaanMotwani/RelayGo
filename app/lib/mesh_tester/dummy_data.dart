import '../models/emergency_report.dart';
import '../models/mesh_message.dart';

/// Generates a fixed set of test packets for BLE mesh validation.
///
/// 5 EmergencyReports + 3 MeshMessages = 8 total packets,
/// with varied types, locations, and broadcast/DM mix.
/// All descriptions kept SHORT to fit within 185B BLE MTU.
class DummyData {
  static const String _deviceId = 'dev01';
  static const String _deviceName = 'Tester';

  /// Generate 5 emergency reports covering different types and locations.
  static List<EmergencyReport> generateReports() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return [
      EmergencyReport(
        ts: now,
        lat: 37.7749,
        lng: -122.4194,
        type: 'fire',
        urg: 5,
        desc: 'Building fire 3rd floor',
        src: _deviceId,
      ),
      EmergencyReport(
        ts: now - 30,
        lat: 37.7751,
        lng: -122.4180,
        type: 'medical',
        urg: 4,
        desc: 'Person collapsed Market St',
        src: _deviceId,
      ),
      EmergencyReport(
        ts: now - 60,
        lat: 37.7730,
        lng: -122.4200,
        type: 'structural',
        urg: 3,
        desc: 'Wall collapse 5th Ave',
        src: _deviceId,
      ),
      EmergencyReport(
        ts: now - 90,
        lat: 37.7760,
        lng: -122.4220,
        type: 'flood',
        urg: 3,
        desc: 'Street flooding Main St',
        src: _deviceId,
      ),
      EmergencyReport(
        ts: now - 120,
        lat: 37.7740,
        lng: -122.4210,
        type: 'hazmat',
        urg: 4,
        desc: 'Gas leak at intersection',
        src: _deviceId,
      ),
    ];
  }

  /// Generate 3 messages: 2 broadcasts + 1 DM.
  static List<MeshMessage> generateMessages({String? dmTarget}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return [
      MeshMessage(
        ts: now,
        src: _deviceId,
        name: _deviceName,
        to: null, // broadcast
        body: 'Road blocked 5th St use Oak',
      ),
      MeshMessage(
        ts: now - 15,
        src: _deviceId,
        name: _deviceName,
        to: null, // broadcast
        body: 'Shelter open Central Park',
      ),
      MeshMessage(
        ts: now - 45,
        src: _deviceId,
        name: _deviceName,
        to: dmTarget, // DM if target provided
        body: 'Are you safe? At the park',
      ),
    ];
  }
}
