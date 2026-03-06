import 'dart:math';

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

  // Fallback coordinates (Singapore)
  static const double _fallbackLat = 1.2830;
  static const double _fallbackLng = 103.8520;

  /// Generate 5 emergency reports.
  /// If [lat]/[lng] are provided, uses real device GPS with slight jitter.
  /// Otherwise falls back to hardcoded Singapore coordinates.
  static List<EmergencyReport> generateReports({
    double? lat,
    double? lng,
    double? acc,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final rng = Random();
    final baseLat = lat ?? _fallbackLat;
    final baseLng = lng ?? _fallbackLng;

    // Jitter offsets (±~100m) to spread reports around the device location
    double jitter() => (rng.nextDouble() - 0.5) * 0.002;

    return [
      EmergencyReport(
        ts: now,
        lat: baseLat + jitter(),
        lng: baseLng + jitter(),
        acc: acc ?? 10,
        type: 'fire',
        urg: 5,
        desc: 'Building fire 3rd floor',
        src: _deviceId,
      ),
      EmergencyReport(
        ts: now - 30,
        lat: baseLat + jitter(),
        lng: baseLng + jitter(),
        acc: acc ?? 10,
        type: 'medical',
        urg: 4,
        desc: 'Person collapsed Market St',
        src: _deviceId,
      ),
      EmergencyReport(
        ts: now - 60,
        lat: baseLat + jitter(),
        lng: baseLng + jitter(),
        acc: acc ?? 10,
        type: 'structural',
        urg: 3,
        desc: 'Wall collapse 5th Ave',
        src: _deviceId,
      ),
      EmergencyReport(
        ts: now - 90,
        lat: baseLat + jitter(),
        lng: baseLng + jitter(),
        acc: acc ?? 10,
        type: 'flood',
        urg: 3,
        desc: 'Street flooding Main St',
        src: _deviceId,
      ),
      EmergencyReport(
        ts: now - 120,
        lat: baseLat + jitter(),
        lng: baseLng + jitter(),
        acc: acc ?? 10,
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
