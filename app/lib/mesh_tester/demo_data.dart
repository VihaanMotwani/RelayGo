import '../models/emergency_report.dart';
import '../models/mesh_packet.dart';
import '../models/mesh_message.dart';

/// Predefined responses for the Iran missile strike demo scenario.
class DemoData {
  static const String _deviceId = 'dev01';
  static const String _deviceName = 'Reporter';
  static int _index = 0;

  static MeshPacket? getNextPacket() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Slight time staggers to look like it happened sequentially
    final packets = [
      MeshPacket.fromReport(
        EmergencyReport(
          ts: now - 300,
          lat: 35.6892,
          lng: 51.3890,
          type: 'structural',
          urg: 5,
          desc:
              'Missile strike! Multi-story collapse, people trapped inside debris.',
          src: _deviceId,
          hops: 2,
        ),
      ),
      MeshPacket.fromReport(
        EmergencyReport(
          ts: now - 280,
          lat: 35.6901,
          lng: 51.3881,
          type: 'fire',
          urg: 4,
          desc:
              'Large fire broke out near the collapse zone, spreading quickly.',
          src: '$_deviceId-b',
          hops: 1,
        ),
      ),
      MeshPacket.fromReport(
        EmergencyReport(
          ts: now - 180,
          lat: 35.6885,
          lng: 51.3905,
          type: 'medical',
          urg: 5,
          desc:
              'Mass casualties reported. Need immediate triage and tourniquets.',
          src: '$_deviceId-c',
          hops: 3,
        ),
      ),
      MeshPacket.fromMessage(
        MeshMessage(
          ts: now - 120,
          src: '$_deviceId-d',
          name: _deviceName,
          to: null,
          body:
              'Main roads blocked by rubble. Use northern access route to reach ground zero.',
          hops: 4,
        ),
      ),
      MeshPacket.fromReport(
        EmergencyReport(
          ts: now - 60,
          lat: 35.6912,
          lng: 51.3870,
          type: 'hazmat',
          urg: 4,
          desc:
              'Ruptured gas main detected. Strong odor, risk of secondary explosion.',
          src: _deviceId,
          hops: 2,
        ),
      ),
      MeshPacket.fromMessage(
        MeshMessage(
          ts: now,
          src: '$_deviceId-e',
          name: '$_deviceName-Rescue',
          to: null,
          body:
              'We have eyes on the trapped survivors. Moving in to extract now.',
          hops: 1,
        ),
      ),
    ];

    if (_index < packets.length) {
      return packets[_index++];
    }
    return null; // Out of sequence
  }

  static void reset() {
    _index = 0;
  }
}
