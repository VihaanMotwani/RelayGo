import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'chat_models.dart';

class _Loc {
  final String type;
  final String name;
  final double lat;
  final double lon;
  final String addr;

  const _Loc({
    required this.type,
    required this.name,
    required this.lat,
    required this.lon,
    required this.addr,
  });

  factory _Loc.fromJson(Map<String, dynamic> j) => _Loc(
        type: j['type'] as String,
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        addr: (j['addr'] as String?) ?? '',
      );
}

/// Loads location assets once and answers nearest-facility queries.
///
/// Uses [category_relevance.json] to map emergency topic → facility types,
/// then finds the closest matching named facilities via Haversine distance.
class LocationFinder {
  List<_Loc> _locations = [];
  Map<String, List<String>> _relevance = {};
  bool _ready = false;

  bool get isReady => _ready;

  // AED entries all have name "AED_LOCATIONS" with no address — exclude
  // them from generic topic searches so we never show meaningless names.
  static const _skipInGenericSearch = {'aed'};

  // Map query keywords → specific facility type.
  // Checked longest-match first (entries ordered longest → shortest key).
  static const Map<String, String> _queryTypeMap = {
    'fire station': 'fire_station',
    'fire dept': 'fire_station',
    'fire department': 'fire_station',
    'scdf': 'fire_station',
    'emergency room': 'hospital',
    'defibrillator': 'aed',
    'hospital': 'hospital',
    'pharmacy': 'pharmacy',
    'medicine': 'pharmacy',
    'shelter': 'shelter',
    'refuge': 'shelter',
    'evacuation center': 'shelter',
    'police station': 'police_station',
    'police': 'police_station',
    'clinic': 'clinic',
    'doctor': 'clinic',
    'ambulance': 'hospital',
    'aed': 'aed',
  };

  Future<void> initialize() async {
    try {
      final locRaw =
          await rootBundle.loadString('assets/locations/locations.json');
      final relRaw = await rootBundle
          .loadString('assets/locations/category_relevance.json');

      final locList = jsonDecode(locRaw) as List<dynamic>;
      _locations = locList
          .map((e) => _Loc.fromJson(e as Map<String, dynamic>))
          .toList();

      final relMap = jsonDecode(relRaw) as Map<String, dynamic>;
      _relevance = relMap.map(
        (k, v) => MapEntry(
          k,
          (v as List<dynamic>).map((e) => e as String).toList(),
        ),
      );

      _ready = true;
      debugPrint('[LocationFinder] ${_locations.length} locations loaded');
    } catch (e) {
      debugPrint('[LocationFinder] init failed: $e');
    }
  }

  /// Detect if [query] is asking about a specific facility type.
  /// Returns the type string (e.g. "fire_station") or null.
  String? detectQueryType(String query) {
    final lower = query.toLowerCase();
    for (final entry in _queryTypeMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Returns the nearest [maxResults] facilities from ([userLat], [userLon]).
  ///
  /// If [queryType] is set, searches only that facility type (user asked
  /// for something specific). Otherwise falls back to topic-based types,
  /// excluding any types with no usable names (e.g. aed).
  List<NearbyResource> findNearest(
    String topic,
    double userLat,
    double userLon, {
    int maxResults = 2,
    String? queryType,
  }) {
    if (!_ready) return [];

    final List<String> types;
    if (queryType != null) {
      types = [queryType];
    } else {
      final all = _relevance[topic] ?? _relevance['other'] ?? [];
      types = all.where((t) => !_skipInGenericSearch.contains(t)).toList();
    }
    if (types.isEmpty) return [];

    final candidates = _locations
        .where((l) => types.contains(l.type))
        .map((l) => (loc: l, dist: _haversineKm(userLat, userLon, l.lat, l.lon)))
        .toList()
      ..sort((a, b) => a.dist.compareTo(b.dist));

    return candidates.take(maxResults).map((c) {
      // Shelters are all named "HDB" — use address as the display name.
      final raw = c.loc.name;
      final displayName =
          (raw == 'HDB' || raw == 'AED_LOCATIONS' || raw == c.loc.type)
              ? (c.loc.addr.isNotEmpty ? c.loc.addr : raw)
              : raw;
      return NearbyResource(
        name: displayName,
        type: c.loc.type,
        distanceKm: c.dist,
        address: c.loc.addr,
      );
    }).toList();
  }

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;
}
