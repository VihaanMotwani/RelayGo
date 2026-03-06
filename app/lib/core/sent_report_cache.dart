import 'dart:math';

import '../models/extraction_result.dart';

/// Entry in the sent report cache.
class SentReportEntry {
  final ExtractionResult extraction;
  final String eventId;
  final int ts; // original timestamp (for eventId stability on rebuild)
  final DateTime sentAt;
  double lastLat;
  double lastLng;

  SentReportEntry({
    required this.extraction,
    required this.eventId,
    required this.ts,
    required this.lastLat,
    required this.lastLng,
  }) : sentAt = DateTime.now();
}

/// In-memory, session-scoped cache of sent emergency reports.
///
/// Powers the "Update Location" button and lets the chat detect
/// re-triggers of previously reported incidents.
class SentReportCache {
  final List<SentReportEntry> _entries = [];

  /// All sent reports this session.
  List<SentReportEntry> get entries => List.unmodifiable(_entries);

  /// Whether any reports have been sent this session.
  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;

  /// Add a newly sent report to the cache.
  void add({
    required ExtractionResult extraction,
    required String eventId,
    required int ts,
    required double lat,
    required double lng,
  }) {
    _entries.add(
      SentReportEntry(
        extraction: extraction,
        eventId: eventId,
        ts: ts,
        lastLat: lat,
        lastLng: lng,
      ),
    );
  }

  /// Find a previously sent report by its eventId.
  SentReportEntry? findByEventId(String eventId) {
    for (final entry in _entries) {
      if (entry.eventId == eventId) return entry;
    }
    return null;
  }

  /// The most recently sent report (for "Update Location").
  SentReportEntry? get latest => _entries.isEmpty ? null : _entries.last;

  /// Check if the device has moved significantly from the last-sent
  /// position for a given report.
  ///
  /// Uses Haversine distance. Default threshold is 25 meters.
  bool hasMoved(
    String eventId,
    double newLat,
    double newLng, {
    double thresholdMeters = 25.0,
  }) {
    final entry = findByEventId(eventId);
    if (entry == null) return true; // no previous data, treat as moved

    final distance = _haversineMeters(
      entry.lastLat,
      entry.lastLng,
      newLat,
      newLng,
    );
    return distance >= thresholdMeters;
  }

  /// Update the cached GPS for a report after a location-only re-broadcast.
  void updateLocation(String eventId, double lat, double lng) {
    final entry = findByEventId(eventId);
    if (entry != null) {
      entry.lastLat = lat;
      entry.lastLng = lng;
    }
  }

  /// Haversine distance in meters between two lat/lng pairs.
  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusM = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusM * c;
  }

  static double _degToRad(double deg) => deg * pi / 180;
}
