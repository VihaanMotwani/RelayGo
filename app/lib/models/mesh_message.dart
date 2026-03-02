import 'dart:convert';
import 'dart:typed_data';

import '../core/packet_hash.dart';

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
    String? id,
    required this.ts,
    required this.src,
    required this.name,
    this.to,
    required this.body,
    this.hops = 0,
    this.ttl = 10,
  }) : id = id ?? PacketHash.computeMessageId(src, ts, to, body);

  bool get isBroadcast => to == null;
  bool get isDirectMessage => to != null;

  /// Full JSON for SQLite storage and backend sync.
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

  /// Compact JSON for BLE wire transfer (< 185B).
  /// Uses 1-char keys. Omits `to` when null (broadcast).
  Map<String, dynamic> toWireJson() {
    final m = <String, dynamic>{
      'k': 'm',
      'i': id,
      't': ts,
      's': src,
      'n': name,
      'b': body,
      'h': hops,
      'l': ttl,
    };
    if (to != null) m['r'] = to;
    return m;
  }

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

  /// Parse from compact BLE wire format.
  factory MeshMessage.fromWireJson(Map<String, dynamic> j) {
    return MeshMessage(
      id: j['i'] as String,
      ts: j['t'] as int,
      src: j['s'] as String,
      name: j['n'] as String? ?? 'Unknown',
      to: j['r'] as String?,
      body: j['b'] as String,
      hops: j['h'] as int? ?? 0,
      ttl: j['l'] as int? ?? 10,
    );
  }

  Uint8List toBytes() =>
      Uint8List.fromList(utf8.encode(jsonEncode(toWireJson())));

  factory MeshMessage.fromBytes(Uint8List bytes) =>
      MeshMessage.fromWireJson(jsonDecode(utf8.decode(bytes)));

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(ts * 1000);
}
