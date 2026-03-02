import 'dart:convert';
import 'dart:typed_data';

class MeshMessage {
  final String kind = 'msg';
  final String id;
  final int ts;
  final String src;
  final String name;
  final String? to; // null = broadcast, device-id = DM
  final String body;
  int hops;
  final int ttl;

  MeshMessage({
    required this.id,
    required this.ts,
    required this.src,
    required this.name,
    this.to,
    required this.body,
    this.hops = 0,
    this.ttl = 10,
  });

  bool get isBroadcast => to == null;
  bool get isDirectMessage => to != null;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'id': id,
    'ts': ts,
    'src': src,
    'name': name,
    'to': to,
    'body': body,
    'hops': hops,
    'ttl': ttl,
  };

  factory MeshMessage.fromJson(Map<String, dynamic> json) {
    return MeshMessage(
      id: json['id'] as String,
      ts: json['ts'] as int,
      src: json['src'] as String,
      name: json['name'] as String? ?? 'Unknown',
      to: json['to'] as String?,
      body: json['body'] as String,
      hops: json['hops'] as int? ?? 0,
      ttl: json['ttl'] as int? ?? 10,
    );
  }

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory MeshMessage.fromBytes(Uint8List bytes) =>
      MeshMessage.fromJson(jsonDecode(utf8.decode(bytes)));

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(ts * 1000);
}
