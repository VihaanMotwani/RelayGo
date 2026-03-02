import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../../core/constants.dart';

/// A nearby emergency resource with distance and direction.
class NearbyResource {
  final String id;
  final String type;
  final String name;
  final double lat;
  final double lon;
  final String address;
  final int distanceMeters;
  final String direction;

  NearbyResource({
    required this.id,
    required this.type,
    required this.name,
    required this.lat,
    required this.lon,
    required this.address,
    required this.distanceMeters,
    required this.direction,
  });

  String get distanceFormatted {
    // Defensive check for unreasonable distances (>100km in Singapore context)
    if (distanceMeters > 100000) {
      return 'far';
    }
    if (distanceMeters < 1000) {
      return '${distanceMeters}m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
  }

  /// Human-readable location description
  String get locationDescription => '$distanceFormatted $direction';
}

/// Service for querying nearby emergency resources.
class LocationService {
  List<Map<String, dynamic>>? _locations;
  Map<String, List<String>>? _categoryRelevance;

  // Pre-indexed locations by type for fast filtering
  Map<String, List<Map<String, dynamic>>>? _locationsByType;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize the location service by loading data files.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load locations
      final locationsJson =
          await rootBundle.loadString('assets/locations/locations.json');
      _locations = List<Map<String, dynamic>>.from(jsonDecode(locationsJson));

      // Load category relevance
      final relevanceJson =
          await rootBundle.loadString('assets/locations/category_relevance.json');
      final relevanceRaw = jsonDecode(relevanceJson) as Map<String, dynamic>;
      _categoryRelevance = relevanceRaw.map(
        (k, v) => MapEntry(k, List<String>.from(v)),
      );

      // Pre-index locations by type
      _locationsByType = {};
      for (final loc in _locations!) {
        final type = loc['type'] as String? ?? '';
        _locationsByType!.putIfAbsent(type, () => []).add(loc);
      }

      _initialized = true;
      print('[LocationService] Loaded ${_locations!.length} locations');
    } catch (e) {
      print('[LocationService] Failed to initialize: $e');
    }
  }

  /// Calculate haversine distance in meters.
  int _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Earth radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return (R * c).round();
  }

  double _toRadians(double deg) => deg * pi / 180;

  /// Calculate bearing from point 1 to point 2 in degrees (0-360).
  double _bearing(double lat1, double lon1, double lat2, double lon2) {
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);
    final dLon = _toRadians(lon2 - lon1);

    final x = sin(dLon) * cos(lat2Rad);
    final y = cos(lat1Rad) * sin(lat2Rad) -
        sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

    final bearingRad = atan2(x, y);
    return (bearingRad * 180 / pi + 360) % 360;
  }

  /// Convert bearing degrees to cardinal direction.
  String _bearingToDirection(double bearingDeg) {
    const directions = [
      (22.5, 'north'),
      (67.5, 'northeast'),
      (112.5, 'east'),
      (157.5, 'southeast'),
      (202.5, 'south'),
      (247.5, 'southwest'),
      (292.5, 'west'),
      (337.5, 'northwest'),
      (360.1, 'north'),
    ];

    for (final (threshold, direction) in directions) {
      if (bearingDeg < threshold) {
        return direction;
      }
    }
    return 'north';
  }

  /// Get relevant resource types for an emergency type.
  List<String> _getRelevantTypes(EmergencyType emergencyType) {
    if (_categoryRelevance == null) {
      return ['hospital', 'police_station', 'fire_station', 'shelter', 'aed'];
    }
    return _categoryRelevance![emergencyType.name] ??
        _categoryRelevance!['other'] ??
        [];
  }

  /// Query nearby resources using brute force distance calculation.
  /// Returns up to [maxPerType] resources per relevant type.
  List<NearbyResource> queryNearby({
    required double lat,
    required double lon,
    required EmergencyType emergencyType,
    int maxPerType = 3,
  }) {
    if (!_initialized || _locationsByType == null) {
      return [];
    }

    final relevantTypes = _getRelevantTypes(emergencyType);
    final allResults = <NearbyResource>[];

    for (final type in relevantTypes) {
      final locations = _locationsByType![type] ?? [];

      // Calculate distance for all locations of this type
      final withDistance = <(Map<String, dynamic>, int, String)>[];
      for (final loc in locations) {
        final rLat = (loc['lat'] as num?)?.toDouble() ?? 0;
        final rLon = (loc['lon'] as num?)?.toDouble() ?? 0;
        final distance = _haversineDistance(lat, lon, rLat, rLon);
        final bearing = _bearing(lat, lon, rLat, rLon);
        final direction = _bearingToDirection(bearing);
        withDistance.add((loc, distance, direction));
      }

      // Sort by distance and take top N
      withDistance.sort((a, b) => a.$2.compareTo(b.$2));

      for (var i = 0; i < min(maxPerType, withDistance.length); i++) {
        final (loc, distance, direction) = withDistance[i];
        allResults.add(NearbyResource(
          id: loc['id'] as String? ?? '',
          type: type,
          name: loc['name'] as String? ?? type,
          lat: (loc['lat'] as num?)?.toDouble() ?? 0,
          lon: (loc['lon'] as num?)?.toDouble() ?? 0,
          address: loc['addr'] as String? ?? '',
          distanceMeters: distance,
          direction: direction,
        ));
      }
    }

    return allResults;
  }

  /// Format nearby resources as context string for LLM.
  String formatForLLM({
    required double lat,
    required double lon,
    required EmergencyType emergencyType,
    int maxPerType = 3,
  }) {
    final resources = queryNearby(
      lat: lat,
      lon: lon,
      emergencyType: emergencyType,
      maxPerType: maxPerType,
    );

    if (resources.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('[NEARBY EMERGENCY RESOURCES]');

    // Group by type for cleaner output
    final byType = <String, List<NearbyResource>>{};
    for (final r in resources) {
      byType.putIfAbsent(r.type, () => []).add(r);
    }

    for (final entry in byType.entries) {
      final typeLabel = entry.key.toUpperCase().replaceAll('_', ' ');
      buffer.writeln('\n$typeLabel:');
      for (final r in entry.value) {
        // Show name with distance, skip empty addresses
        if (r.address.isNotEmpty && r.address.length < 80) {
          buffer.writeln('  • ${r.name} — ${r.locationDescription} (${r.address})');
        } else {
          buffer.writeln('  • ${r.name} — ${r.locationDescription}');
        }
      }
    }

    return buffer.toString();
  }
}
