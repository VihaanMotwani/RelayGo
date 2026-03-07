import '../core/packet_hash.dart';

/// A directive sent from the dashboard operator to the mesh network.
/// Mirrors the backend `Directive` Pydantic model.
class Directive {
  final String kind = 'directive';
  final String id;
  final int ts;
  final String src;
  final String name;
  final String? to;
  final String? zone;
  final String body;
  final String priority; // 'high' | 'medium' | 'low'
  int hops; // mutable so BLE hop-count increment works
  final int ttl;

  Directive({
    String? id,
    required this.ts,
    required this.src,
    required this.name,
    this.to,
    this.zone,
    required this.body,
    this.priority = 'high',
    this.hops = 0,
    this.ttl = 15,
  }) : id = id ?? PacketHash.computeMessageId(src, ts, to, body);

  factory Directive.fromJson(Map<String, dynamic> j) {
    return Directive(
      id:
          j['id'] as String? ??
          PacketHash.computeMessageId(
            j['src'] as String? ?? '',
            j['ts'] as int? ?? 0,
            j['to'] as String?,
            j['body'] as String? ?? '',
          ),
      ts: j['ts'] as int? ?? 0,
      src: j['src'] as String? ?? '',
      name: j['name'] as String? ?? '',
      to: j['to'] as String?,
      zone: j['zone'] as String?,
      body: j['body'] as String? ?? '',
      priority: j['priority'] as String? ?? 'high',
      hops: j['hops'] as int? ?? 0,
      ttl: j['ttl'] as int? ?? 15,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'id': id,
    'ts': ts,
    'src': src,
    'name': name,
    'to': to,
    'zone': zone,
    'body': body,
    'priority': priority,
    'hops': hops,
    'ttl': ttl,
  };

  /// Compact wire JSON for BLE transfer (short 1-char keys, wire type `k='d'`).
  Map<String, dynamic> toWireJson() {
    final m = <String, dynamic>{
      'k': 'd',
      'i': id,
      't': ts,
      's': src,
      'n': name,
      'b': body,
      'p': priority,
      'h': hops,
      'l': ttl,
    };
    if (to != null) m['r'] = to;
    if (zone != null) m['z'] = zone;
    return m;
  }

  factory Directive.fromWireJson(Map<String, dynamic> j) {
    return Directive(
      id: j['i'] as String,
      ts: j['t'] as int,
      src: j['s'] as String? ?? '',
      name: j['n'] as String? ?? '',
      to: j['r'] as String?,
      zone: j['z'] as String?,
      body: j['b'] as String? ?? '',
      priority: j['p'] as String? ?? 'high',
      hops: j['h'] as int? ?? 0,
      ttl: j['l'] as int? ?? 15,
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(ts * 1000);
}
