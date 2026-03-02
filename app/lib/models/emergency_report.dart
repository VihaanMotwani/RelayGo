import 'dart:convert';
import 'dart:typed_data';

import '../core/packet_hash.dart';

class EmergencyReport {
  final String kind = 'report';
  final String id;
  final int ts;
  final double lat;
  final double lng;
  final double acc;
  final String type;
  final int urg;
  final List<String> haz;
  final String desc;
  final String src;
  int hops;
  final int ttl;

  EmergencyReport({
    String? id,
    required this.ts,
    required this.lat,
    required this.lng,
    this.acc = 10,
    required this.type,
    required this.urg,
    this.haz = const [],
    required this.desc,
    required this.src,
    this.hops = 0,
    this.ttl = 10,
  }) : id = id ?? PacketHash.computeReportId(src, ts, type, lat, lng, desc);

  /// Factory method for creating EmergencyReport from AI extraction
  /// This ensures proper schema alignment between AI service and mesh models
  factory EmergencyReport.fromAiExtraction({
    required dynamic extraction, // AiExtraction from ai_service.dart
    required dynamic location, // Position from geolocator
    required String deviceId,
    String? sourceMessageId,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Build description - include source message ID if available for deduplication
    String desc = extraction.description;
    if (sourceMessageId != null && !desc.contains('[src:')) {
      desc = '$desc [src:$sourceMessageId]';
    }

    return EmergencyReport(
      ts: ts,
      lat: location.latitude,
      lng: location.longitude,
      acc: location.accuracy,
      type: extraction.type,
      urg: extraction.urgency,
      haz: extraction.hazards,
      desc: desc,
      src: deviceId,
      hops: 0,
      ttl: 10,
    );
  }

  /// Validation helper - checks if report is valid for broadcast
  /// Enforces quality thresholds before sending to mesh network
  bool isValidForBroadcast() {
    return urg >= 3 && // Only urgent reports (threshold)
        desc.length > 10 && // Has meaningful description
        desc.length < 150 && // Fits in BLE MTU (185B total)
        type != 'other'; // Has specific category
  }

  /// Full JSON for SQLite storage and backend sync.
  Map<String, dynamic> toJson() => {
    'kind': kind,
    'id': id,
    'ts': ts,
    'loc': {'lat': lat, 'lng': lng, 'acc': acc},
    'type': type,
    'urg': urg,
    'haz': haz,
    'desc': desc,
    'src': src,
    'hops': hops,
    'ttl': ttl,
  };

  /// Compact JSON for BLE wire transfer (< 185B).
  /// Uses 1-char keys. Drops acc and haz to save space.
  Map<String, dynamic> toWireJson() => {
    'k': 'r',
    'i': id,
    't': ts,
    'y': type,
    'u': urg,
    'a': lat,
    'o': lng,
    'd': desc,
    's': src,
    'h': hops,
    'l': ttl,
  };

  factory EmergencyReport.fromJson(Map<String, dynamic> json) {
    final loc = json['loc'] as Map<String, dynamic>;
    return EmergencyReport(
      id: json['id'] as String,
      ts: json['ts'] as int,
      lat: (loc['lat'] as num).toDouble(),
      lng: (loc['lng'] as num).toDouble(),
      acc: (loc['acc'] as num?)?.toDouble() ?? 10,
      type: json['type'] as String,
      urg: json['urg'] as int,
      haz: (json['haz'] as List<dynamic>?)?.cast<String>() ?? [],
      desc: json['desc'] as String,
      src: json['src'] as String,
      hops: json['hops'] as int? ?? 0,
      ttl: json['ttl'] as int? ?? 10,
    );
  }

  /// Parse from compact BLE wire format.
  factory EmergencyReport.fromWireJson(Map<String, dynamic> j) {
    return EmergencyReport(
      id: j['i'] as String,
      ts: j['t'] as int,
      lat: (j['a'] as num).toDouble(),
      lng: (j['o'] as num).toDouble(),
      acc: 10, // not transmitted on wire
      type: j['y'] as String,
      urg: j['u'] as int,
      haz: const [], // not transmitted on wire
      desc: j['d'] as String,
      src: j['s'] as String,
      hops: j['h'] as int? ?? 0,
      ttl: j['l'] as int? ?? 10,
    );
  }

  Uint8List toBytes() =>
      Uint8List.fromList(utf8.encode(jsonEncode(toWireJson())));

  factory EmergencyReport.fromBytes(Uint8List bytes) =>
      EmergencyReport.fromWireJson(jsonDecode(utf8.decode(bytes)));

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(ts * 1000);
}
