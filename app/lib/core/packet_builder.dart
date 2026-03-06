import 'package:geolocator/geolocator.dart';

import '../models/emergency_report.dart';
import '../models/extraction_result.dart';

/// Builds an [EmergencyReport] from an [ExtractionResult] + GPS position.
///
/// Handles desc truncation, GPS fallback, and auto-computes IDs
/// via the [EmergencyReport] constructor (which delegates to [PacketHash]).
class PacketBuilder {
  /// Maximum description length to fit within the 183B BLE wire budget.
  /// Fixed overhead (IDs, ts, type, urg, hops, TTL, src) ≈ 80B → ~100 chars for desc.
  static const int maxDescLength = 100;

  /// Build an [EmergencyReport] from extraction data and GPS.
  ///
  /// - Truncates [ExtractionResult.desc] to [maxDescLength] chars
  /// - Uses GPS [position] for lat/lng/acc, or `0/0/999` sentinel if null
  /// - Sets `ttl=10`, `hops=0`
  /// - IDs auto-computed by [EmergencyReport] constructor
  static EmergencyReport build({
    required ExtractionResult extraction,
    required Position? position,
    required String deviceId,
  }) {
    // Truncate description to fit wire budget
    var desc = extraction.desc;
    if (desc.length > maxDescLength) {
      desc = '${desc.substring(0, maxDescLength - 1)}…';
    }

    return EmergencyReport(
      ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      lat: position?.latitude ?? 0.0,
      lng: position?.longitude ?? 0.0,
      acc: position?.accuracy ?? 999.0,
      type: extraction.type,
      urg: extraction.urg,
      haz: extraction.haz,
      desc: desc,
      src: deviceId,
      hops: 0,
      ttl: 10,
    );
  }

  /// Rebuild a report with updated GPS but identical content.
  ///
  /// Produces a new `id` (lat/lng changed) but preserves the same
  /// `eventId` (src+ts+type+desc are identical).
  static EmergencyReport rebuildWithNewLocation({
    required ExtractionResult extraction,
    required int originalTs,
    required Position position,
    required String deviceId,
  }) {
    var desc = extraction.desc;
    if (desc.length > maxDescLength) {
      desc = '${desc.substring(0, maxDescLength - 1)}…';
    }

    return EmergencyReport(
      ts: originalTs,
      lat: position.latitude,
      lng: position.longitude,
      acc: position.accuracy,
      type: extraction.type,
      urg: extraction.urg,
      haz: extraction.haz,
      desc: desc,
      src: deviceId,
      hops: 0,
      ttl: 10,
    );
  }
}
