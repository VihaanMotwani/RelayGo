import 'dart:convert';
import 'dart:typed_data';

import 'emergency_report.dart';
import 'mesh_message.dart';

/// Union type that deserializes either packet type based on the `kind` field.
class MeshPacket {
  final EmergencyReport? report;
  final MeshMessage? message;

  MeshPacket._({this.report, this.message});

  factory MeshPacket.fromReport(EmergencyReport report) =>
      MeshPacket._(report: report);

  factory MeshPacket.fromMessage(MeshMessage message) =>
      MeshPacket._(message: message);

  bool get isReport => report != null;
  bool get isMessage => message != null;

  String get id => report?.id ?? message!.id;
  String get kind => report != null ? 'report' : 'msg';
  int get hops => report?.hops ?? message!.hops;
  set hops(int value) {
    if (report != null) report!.hops = value;
    if (message != null) message!.hops = value;
  }
  int get ttl => report?.ttl ?? message!.ttl;

  Map<String, dynamic> toJson() => report?.toJson() ?? message!.toJson();

  factory MeshPacket.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String?;
    if (kind == 'msg') {
      return MeshPacket.fromMessage(MeshMessage.fromJson(json));
    }
    return MeshPacket.fromReport(EmergencyReport.fromJson(json));
  }

  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory MeshPacket.fromBytes(Uint8List bytes) =>
      MeshPacket.fromJson(jsonDecode(utf8.decode(bytes)));
}
