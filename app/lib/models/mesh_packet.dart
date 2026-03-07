import 'dart:convert';
import 'dart:typed_data';

import 'directive.dart';
import 'emergency_report.dart';
import 'mesh_message.dart';

/// Union type that deserializes either packet type based on the `kind` field.
class MeshPacket {
  final EmergencyReport? report;
  final MeshMessage? message;
  final Directive? directive;

  MeshPacket._({this.report, this.message, this.directive});

  factory MeshPacket.fromReport(EmergencyReport report) =>
      MeshPacket._(report: report);

  factory MeshPacket.fromMessage(MeshMessage message) =>
      MeshPacket._(message: message);

  factory MeshPacket.fromDirective(Directive d) => MeshPacket._(directive: d);

  bool get isReport => report != null;
  bool get isMessage => message != null;
  bool get isDirective => directive != null;

  String get id => report?.id ?? message?.id ?? directive!.id;
  String get kind {
    if (report != null) return 'report';
    if (message != null) return 'msg';
    return 'directive';
  }

  int get hops => report?.hops ?? message?.hops ?? directive!.hops;
  set hops(int value) {
    if (report != null) report!.hops = value;
    if (message != null) message!.hops = value;
    if (directive != null) directive!.hops = value;
  }

  int get ttl => report?.ttl ?? message?.ttl ?? directive!.ttl;

  /// Full JSON for SQLite storage.
  Map<String, dynamic> toJson() =>
      report?.toJson() ?? message?.toJson() ?? directive!.toJson();

  factory MeshPacket.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String?;
    if (kind == 'msg')
      return MeshPacket.fromMessage(MeshMessage.fromJson(json));
    if (kind == 'directive')
      return MeshPacket.fromDirective(Directive.fromJson(json));
    return MeshPacket.fromReport(EmergencyReport.fromJson(json));
  }

  /// Compact wire JSON for BLE transfer.
  Uint8List toBytes() {
    final Map<String, dynamic> wire;
    if (report != null) {
      wire = report!.toWireJson();
    } else if (message != null) {
      wire = message!.toWireJson();
    } else {
      wire = directive!.toWireJson();
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(wire)));
  }

  /// Parse from compact BLE wire bytes. Routes on `k` field.
  factory MeshPacket.fromBytes(Uint8List bytes) {
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final k = json['k'] as String?;
    if (k == 'm') return MeshPacket.fromMessage(MeshMessage.fromWireJson(json));
    if (k == 'd') return MeshPacket.fromDirective(Directive.fromWireJson(json));
    return MeshPacket.fromReport(EmergencyReport.fromWireJson(json));
  }
}
