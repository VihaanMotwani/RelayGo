import 'dart:convert';
import 'dart:typed_data';

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
    required this.id,
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
  });

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

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory EmergencyReport.fromBytes(Uint8List bytes) =>
      EmergencyReport.fromJson(jsonDecode(utf8.decode(bytes)));

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(ts * 1000);
}
